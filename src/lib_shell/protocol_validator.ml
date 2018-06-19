(**************************************************************************)
(*                                                                        *)
(*    Copyright (c) 2014 - 2018.                                          *)
(*    Dynamic Ledger Solutions, Inc. <contact@tezos.com>                  *)
(*                                                                        *)
(*    All rights reserved. No warranty, explicit or implicit, provided.   *)
(*                                                                        *)
(**************************************************************************)

open Validation_errors

include Logging.Make(struct let name = "node.validator.block" end)

type 'a request =
  | Request_validation: {
      hash: Protocol_hash.t ;
      protocol: Protocol.t ;
    } -> Registered_protocol.t tzresult request

type message = Message: 'a request * 'a Lwt.u option -> message

type t = {
  db: Distributed_db.t ;
  mutable worker: unit Lwt.t ;
  messages: message Lwt_pipe.t ;
  canceler: Lwt_canceler.t ;
}

(** Block validation *)

let rec worker_loop bv =
  begin
    protect ~canceler:bv.canceler begin fun () ->
      Lwt_pipe.pop bv.messages >>= return
    end >>=? function Message (request, wakener) ->
    match request with
    | Request_validation { hash ; protocol } ->
        Updater.compile hash protocol >>= fun valid ->
        begin
          if valid then
            Distributed_db.commit_protocol bv.db hash protocol
          else
            (* no need to tag 'invalid' protocol on disk,
               the economic protocol prevents us from
               being spammed with protocol validation. *)
            return true
        end >>=? fun _ ->
        match wakener with
        | None ->
            return ()
        | Some wakener ->
            if valid then
              match Registered_protocol.get hash with
              | Some protocol ->
                  Lwt.wakeup_later wakener (Ok protocol)
              | None ->
                  Lwt.wakeup_later wakener
                    (Error
                       [Invalid_protocol { hash ;
                                           error = Dynlinking_failed }])
            else
              Lwt.wakeup_later wakener
                (Error
                   [Invalid_protocol { hash ;
                                       error = Compilation_failed }]) ;
            return ()
  end >>= function
  | Ok () ->
      worker_loop bv
  | Error [Canceled | Exn Lwt_pipe.Closed] ->
      lwt_log_notice "terminating" >>= fun () ->
      Lwt.return_unit
  | Error err ->
      lwt_log_error "@[Unexpected error (worker):@ %a@]"
        pp_print_error err >>= fun () ->
      Lwt_canceler.cancel bv.canceler >>= fun () ->
      Lwt.return_unit

let create db =
  let canceler = Lwt_canceler.create () in
  let messages = Lwt_pipe.create () in
  let bv = {
    canceler ; messages ; db ;
    worker = Lwt.return_unit } in
  Lwt_canceler.on_cancel bv.canceler begin fun () ->
    Lwt_pipe.close bv.messages ;
    Lwt.return_unit
  end ;
  bv.worker <-
    Lwt_utils.worker "block_validator"
      ~run:(fun () -> worker_loop bv)
      ~cancel:(fun () -> Lwt_canceler.cancel bv.canceler) ;
  bv

let shutdown { canceler ; worker } =
  Lwt_canceler.cancel canceler >>= fun () ->
  worker

let validate { messages } hash protocol =
  match Registered_protocol.get hash with
  | Some protocol ->
      lwt_debug "previously validated protocol %a (before pipe)"
        Protocol_hash.pp_short hash >>= fun () ->
      return protocol
  | None ->
      let res, wakener = Lwt.task () in
      lwt_debug "pushing validation request for protocol %a"
        Protocol_hash.pp_short hash >>= fun () ->
      Lwt_pipe.push messages
        (Message (Request_validation { hash ; protocol },
                  Some wakener)) >>= fun () ->
      res

let fetch_and_compile_protocol pv ?peer ?timeout hash =
  match Registered_protocol.get hash with
  | Some proto -> return proto
  | None ->
      begin
        Distributed_db.Protocol.read_opt pv.db hash >>= function
        | Some protocol -> return protocol
        | None ->
            let may_print_peer ppf = function
              | None -> ()
              | Some peer ->
                  Format.fprintf ppf " from peer %a"
                    P2p_peer.Id.pp peer in
            lwt_log_notice "Fetching protocol %a%a"
              Protocol_hash.pp_short hash
              may_print_peer peer >>= fun () ->
            Distributed_db.Protocol.fetch pv.db ?peer ?timeout hash ()
      end >>=? fun protocol ->
      validate pv hash protocol >>=? fun proto ->
      return proto

let fetch_and_compile_protocols pv ?peer ?timeout (block: State.Block.t) =
  State.Block.context block >>= fun context ->
  let protocol =
    Context.get_protocol context >>= fun protocol_hash ->
    fetch_and_compile_protocol pv ?peer ?timeout protocol_hash >>=? fun _ ->
    return ()
  and test_protocol =
    Context.get_test_chain context >>= function
    | Not_running -> return ()
    | Forking { protocol }
    | Running { protocol } ->
        fetch_and_compile_protocol pv ?peer ?timeout protocol  >>=? fun _ ->
        return () in
  protocol >>=? fun () ->
  test_protocol >>=? fun () ->
  return ()

let prefetch_and_compile_protocols pv ?peer ?timeout block =
  try ignore (fetch_and_compile_protocols pv ?peer ?timeout block) with _ -> ()
