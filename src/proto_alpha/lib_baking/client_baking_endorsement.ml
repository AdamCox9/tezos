(**************************************************************************)
(*                                                                        *)
(*    Copyright (c) 2014 - 2018.                                          *)
(*    Dynamic Ledger Solutions, Inc. <contact@tezos.com>                  *)
(*                                                                        *)
(*    All rights reserved. No warranty, explicit or implicit, provided.   *)
(*                                                                        *)
(**************************************************************************)

open Proto_alpha
open Alpha_context

open Logging.Client.Endorsement

module State : sig

  val get_endorsement:
    #Client_context.wallet ->
    Raw_level.t ->
    int ->
    (Block_hash.t * Operation_hash.t) option tzresult Lwt.t

  val record_endorsement:
    #Client_context.wallet ->
    Raw_level.t ->
    Block_hash.t ->
    int -> Operation_hash.t -> unit tzresult Lwt.t

end = struct

  module LevelMap = Map.Make(Raw_level)

  type t = (int * Block_hash.t * Operation_hash.t) list LevelMap.t
  let encoding : t Data_encoding.t =
    let open Data_encoding in
    conv
      (fun x -> LevelMap.bindings x)
      (fun l ->
         List.fold_left
           (fun x (y, z) -> LevelMap.add y z x)
           LevelMap.empty l)
      (list (obj2
               (req "level" Raw_level.encoding)
               (req "endorsement"
                  (list (obj3
                           (req "slot" int31)
                           (req "block" Block_hash.encoding)
                           (req "operation" Operation_hash.encoding))))))

  let name =
    "endorsements"

  let load (wallet : #Client_context.wallet) =
    wallet#load name encoding ~default:LevelMap.empty

  let save (wallet : #Client_context.wallet) map =
    wallet#write name encoding map

  let lock = Lwt_mutex.create ()

  let get_endorsement (wallet : #Client_context.wallet) level slot =
    Lwt_mutex.with_lock lock
      (fun () ->
         load wallet >>=? fun map ->
         try
           let _, block, op =
             LevelMap.find level map
             |> List.find (fun (slot',_,_) -> slot = slot') in
           return (Some (block, op))
         with Not_found -> return None)

  let record_endorsement (wallet : #Client_context.wallet) level hash slot oph =
    Lwt_mutex.with_lock lock
      (fun () ->
         load wallet >>=? fun map ->
         let previous =
           try LevelMap.find level map
           with Not_found -> [] in
         wallet#write name
           (LevelMap.add level ((slot, hash, oph) :: previous) map)
           encoding)

end

let get_signing_slots cctxt ?max_priority block delegate level =
  Alpha_services.Delegate.Endorser.rights_for_delegate cctxt
    ?max_priority ~first_level:level ~last_level:level
    block delegate >>=? fun possibilities ->
  let slots =
    List.map (fun (_,slot) -> slot)
    @@ List.filter (fun (l, _) -> l = level) possibilities in
  return slots

let inject_endorsement (cctxt : #Proto_alpha.full)
    block level ?async
    src_sk slots =
  Block_services.info cctxt block >>=? fun bi ->
  Alpha_services.Forge.Consensus.endorsement cctxt
    block
    ~branch:bi.hash
    ~block:bi.hash
    ~level:level
    ~slots
    () >>=? fun bytes ->
  Client_keys.append cctxt src_sk bytes >>=? fun signed_bytes ->
  Shell_services.inject_operation
    cctxt ?async ~chain_id:bi.chain_id signed_bytes >>=? fun oph ->
  iter_s
    (fun slot ->
       State.record_endorsement cctxt level bi.hash slot oph)
    slots >>=? fun () ->
  return oph

let previously_endorsed_slot cctxt level slot =
  State.get_endorsement cctxt level slot >>=? function
  | None -> return false
  | Some _ -> return true

let check_endorsement cctxt level slot =
  State.get_endorsement cctxt level slot >>=? function
  | None -> return ()
  | Some (block, _) ->
      Error_monad.failwith
        "Already signed block %a at level %a, slot %d"
        Block_hash.pp_short block Raw_level.pp level slot


let forge_endorsement (cctxt : #Proto_alpha.full)
    block
    ~src_sk ?slots ?max_priority src_pk =
  let src_pkh = Signature.Public_key.hash src_pk in
  Alpha_services.Context.level cctxt block >>=? fun { level } ->
  begin
    match slots with
    | Some slots -> return slots
    | None ->
        get_signing_slots
          cctxt ?max_priority block src_pkh level >>=? function
        | [] -> cctxt#error "No slot found at level %a" Raw_level.pp level
        | slots -> return slots
  end >>=? fun slots ->
  iter_s (check_endorsement cctxt level) slots >>=? fun () ->
  inject_endorsement cctxt
    block level
    src_sk slots


(** Worker *)

type state = {
  delegates: public_key_hash list ;
  mutable best: Client_baking_blocks.block_info ;
  mutable to_endorse: endorsement list ;
  delay: int64;
}
and endorsement = {
  time: Time.t ;
  delegate: public_key_hash ;
  block: Client_baking_blocks.block_info ;
  slot: int;
}

let create_state delegates best delay =
  { delegates ;
    best ;
    to_endorse = [] ;
    delay ;
  }

let rec insert ({time} as e) = function
  | [] -> [e]
  | ({time = time'} :: _) as l when Time.compare time time' < 0 ->
      e :: l
  | e' :: l -> e' :: insert e l

let get_delegates cctxt state =
  match state.delegates with
  | [] ->
      Client_keys.get_keys cctxt >>=? fun keys ->
      return (List.map (fun (_,pkh,_,_) -> pkh) keys)
  | _ :: _ as delegates ->
      return delegates

let drop_old_endorsement ~before state =
  state.to_endorse <-
    List.filter
      (fun { block } -> Fitness.compare before block.fitness <= 0)
      state.to_endorse

let schedule_endorsements (cctxt : #Proto_alpha.full) state bis =
  let may_endorse (block: Client_baking_blocks.block_info) delegate time =
    Client_keys.Public_key_hash.name cctxt delegate >>=? fun name ->
    lwt_log_info "May endorse block %a for %s"
      Block_hash.pp_short block.hash name >>= fun () ->
    let b = `Hash (block.hash, 0) in
    let level = block.level.level in
    get_signing_slots cctxt b delegate level >>=? fun slots ->
    lwt_debug "Found slots for %a/%s (%d)"
      Block_hash.pp_short block.hash name (List.length slots) >>= fun () ->
    iter_p
      (fun slot ->
         if Fitness.compare state.best.fitness block.fitness < 0 then begin
           state.best <- block ;
           drop_old_endorsement ~before:block.fitness state ;
         end ;
         previously_endorsed_slot cctxt level slot >>=? function
         | true ->
             lwt_debug "slot %d: previously endorsed." slot >>= fun () ->
             return ()
         | false ->
             try
               let same_slot e =
                 e.block.level = block.level && e.slot = slot in
               let old = List.find same_slot state.to_endorse in
               if Fitness.compare old.block.fitness block.fitness < 0
               then begin
                 lwt_log_info
                   "Schedule endorsement for block %a \
                    (level %a, slot %d, time %a) (replace block %a)"
                   Block_hash.pp_short block.hash
                   Raw_level.pp level
                   slot
                   Time.pp_hum time
                   Block_hash.pp_short old.block.hash
                 >>= fun () ->
                 state.to_endorse <-
                   insert
                     { time ; delegate ; block ; slot }
                     (List.filter
                        (fun e -> not (same_slot e))
                        state.to_endorse) ;
                 return ()
               end else begin
                 lwt_debug
                   "slot %d: better pending endorsement"
                   slot >>= fun () ->
                 return ()
               end
             with Not_found ->
               lwt_log_info
                 "Schedule endorsement for block %a \
                  (level %a, slot %d, time %a)"
                 Block_hash.pp_short block.hash
                 Raw_level.pp level
                 slot
                 Time.pp_hum time >>= fun () ->
               state.to_endorse <-
                 insert { time ; delegate ; block ; slot } state.to_endorse ;
               return ())
      slots in
  let time = Time.(add (now ()) state.delay) in
  get_delegates cctxt state >>=? fun delegates ->
  iter_p
    (fun delegate ->
       iter_p
         (fun bi -> may_endorse bi delegate time)
         bis)
    delegates

let schedule_endorsements (cctxt : #Proto_alpha.full) state bis =
  schedule_endorsements cctxt state bis >>= function
  | Error exns ->
      lwt_log_error
        "@[<v 2>Error(s) while scheduling endorsements@,%a@]"
        pp_print_error exns
  | Ok () -> Lwt.return_unit

let pop_endorsements state =
  let now = Time.now () in
  let rec pop acc = function
    | [] -> List.rev acc, []
    | {time} :: _ as slots when Time.compare now time <= 0 ->
        List.rev acc, slots
    | slot :: slots -> pop (slot :: acc) slots in
  let to_endorse, future_endorsement = pop [] state.to_endorse in
  state.to_endorse <- future_endorsement ;
  to_endorse

let endorse cctxt state =
  let to_endorse = pop_endorsements state in
  iter_p
    (fun { delegate ; block ; slot } ->
       let hash = block.hash in
       let b = `Hash (hash, 0) in
       let level = block.level.level in
       previously_endorsed_slot cctxt level slot >>=? function
       | true -> return ()
       | false ->
           Client_keys.get_key cctxt delegate >>=? fun (name, _pk, sk) ->
           lwt_debug "Endorsing %a for %s (slot %d)!"
             Block_hash.pp_short hash name slot >>= fun () ->
           inject_endorsement cctxt
             b level
             sk [slot] >>=? fun oph ->
           cctxt#message
             "Injected endorsement for block '%a' \
              (level %a, slot %d, contract %s) '%a'"
             Block_hash.pp_short hash
             Raw_level.pp level
             slot name
             Operation_hash.pp_short oph >>= fun () ->
           return ())
    to_endorse

let compute_timeout state =
  match state.to_endorse with
  | [] -> Lwt_utils.never_ending
  | {time} :: _ ->
      let delay = (Time.diff time (Time.now ())) in
      if delay <= 0L then
        Lwt.return_unit
      else
        Lwt_unix.sleep (Int64.to_float delay)

let create (cctxt : #Proto_alpha.full) ~delay contracts block_stream =
  lwt_log_info "Starting endorsement daemon" >>= fun () ->
  Lwt_stream.get block_stream >>= function
  | None | Some (Ok []) | Some (Error _) ->
      cctxt#error "Can't fetch the current block head."
  | Some (Ok (bi :: _ as initial_heads)) ->
      let last_get_block = ref None in
      let get_block () =
        match !last_get_block with
        | None ->
            let t = Lwt_stream.get block_stream in
            last_get_block := Some t ;
            t
        | Some t -> t in
      let state = create_state contracts bi (Int64.of_int delay) in
      let rec worker_loop () =
        let timeout = compute_timeout state in
        Lwt.choose [ (timeout >|= fun () -> `Timeout) ;
                     (get_block () >|= fun b -> `Hash b) ] >>= function
        | `Hash (None | Some (Error _)) ->
            Lwt.return_unit
        | `Hash (Some (Ok bis)) ->
            Lwt.cancel timeout ;
            last_get_block := None ;
            schedule_endorsements cctxt state bis >>= fun () ->
            worker_loop ()
        | `Timeout ->
            begin
              endorse cctxt state >>= function
              | Ok () -> Lwt.return_unit
              | Error errs ->
                  lwt_log_error "Error while endorsing:@\n%a"
                    pp_print_error
                    errs >>= fun () ->
                  Lwt.return_unit
            end >>= fun () ->
            worker_loop () in
      schedule_endorsements cctxt state initial_heads >>= fun () ->
      worker_loop ()
