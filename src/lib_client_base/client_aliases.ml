(**************************************************************************)
(*                                                                        *)
(*    Copyright (c) 2014 - 2018.                                          *)
(*    Dynamic Ledger Solutions, Inc. <contact@tezos.com>                  *)
(*                                                                        *)
(*    All rights reserved. No warranty, explicit or implicit, provided.   *)
(*                                                                        *)
(**************************************************************************)

(* Tezos Command line interface - Local Storage for Configuration *)

open Lwt.Infix
open Cli_entries

module type Entity = sig
  type t
  val encoding : t Data_encoding.t
  val of_source : string -> t tzresult Lwt.t
  val to_source : t -> string tzresult Lwt.t
  val name : string
end

module type Alias = sig
  type t
  type fresh_param
  val load :
    #Client_context.wallet ->
    (string * t) list tzresult Lwt.t
  val set :
    #Client_context.wallet ->
    (string * t) list ->
    unit tzresult Lwt.t
  val find :
    #Client_context.wallet ->
    string -> t tzresult Lwt.t
  val find_opt :
    #Client_context.wallet ->
    string -> t option tzresult Lwt.t
  val rev_find :
    #Client_context.wallet ->
    t -> string option tzresult Lwt.t
  val name :
    #Client_context.wallet ->
    t -> string tzresult Lwt.t
  val mem :
    #Client_context.wallet ->
    string -> bool tzresult Lwt.t
  val add :
    force:bool ->
    #Client_context.wallet ->
    string -> t -> unit tzresult Lwt.t
  val del :
    #Client_context.wallet ->
    string -> unit tzresult Lwt.t
  val update :
    #Client_context.wallet ->
    string -> t -> unit tzresult Lwt.t
  val of_source : string -> t tzresult Lwt.t
  val to_source : t -> string tzresult Lwt.t
  val alias_param :
    ?name:string ->
    ?desc:string ->
    ('a, (#Client_context.wallet as 'b)) Cli_entries.params ->
    (string * t -> 'a, 'b) Cli_entries.params
  val fresh_alias_param :
    ?name:string ->
    ?desc:string ->
    ('a, (< .. > as 'obj)) Cli_entries.params ->
    (fresh_param -> 'a, 'obj) Cli_entries.params
  val force_switch :
    unit -> (bool, #Client_context.full) arg
  val of_fresh :
    #Client_context.wallet ->
    bool ->
    fresh_param ->
    string tzresult Lwt.t
  val source_param :
    ?name:string ->
    ?desc:string ->
    ('a, (#Client_context.wallet as 'obj)) Cli_entries.params ->
    (t -> 'a, 'obj) Cli_entries.params
  val source_arg :
    ?long:string ->
    ?placeholder:string ->
    ?doc:string ->
    unit -> (t option, (#Client_context.wallet as 'obj)) Cli_entries.arg
  val autocomplete:
    #Client_context.wallet -> string list tzresult Lwt.t
end

module Alias = functor (Entity : Entity) -> struct

  open Client_context

  let wallet_encoding : (string * Entity.t) list Data_encoding.encoding =
    let open Data_encoding in
    list (obj2
            (req "name" string)
            (req "value" Entity.encoding))

  let load (wallet : #wallet) =
    wallet#load Entity.name ~default:[] wallet_encoding

  let set (wallet : #wallet) entries =
    wallet#write Entity.name entries wallet_encoding

  let autocomplete wallet =
    load wallet >>= function
    | Error _ -> return []
    | Ok list -> return (List.map fst list)

  let find_opt (wallet : #wallet) name =
    load wallet >>=? fun list ->
    try return (Some (List.assoc name list))
    with Not_found -> return None

  let find (wallet : #wallet) name =
    load wallet >>=? fun list ->
    try return (List.assoc name list)
    with Not_found ->
      failwith "no %s alias named %s" Entity.name name

  let rev_find (wallet : #wallet) v =
    load wallet >>=? fun list ->
    try return (Some (List.find (fun (_, v') -> v = v') list |> fst))
    with Not_found -> return None

  let mem (wallet : #wallet) name =
    load wallet >>=? fun list ->
    try
      ignore (List.assoc name list) ;
      return true
    with
    | Not_found -> return false

  let add ~force (wallet : #wallet) name value =
    let keep = ref false in
    load wallet >>=? fun list ->
    begin
      if force then
        return ()
      else
        iter_s (fun (n, v) ->
            if n = name && v = value then begin
              keep := true ;
              return ()
            end else if n = name && v <> value then begin
              failwith
                "another %s is already aliased as %s, \
                 use -force to update"
                Entity.name n
            end else if n <> name && v = value then begin
              failwith
                "this %s is already aliased as %s, \
                 use -force to insert duplicate"
                Entity.name n
            end else begin
              return ()
            end)
          list
    end >>=? fun () ->
    let list = List.filter (fun (n, _) -> n <> name) list in
    let list = (name, value) :: list in
    if !keep then
      return ()
    else
      wallet#write Entity.name list wallet_encoding

  let del (wallet : #wallet) name =
    load wallet >>=? fun list ->
    let list = List.filter (fun (n, _) -> n <> name) list in
    wallet#write Entity.name list wallet_encoding

  let update (wallet : #wallet) name value =
    load wallet >>=? fun list ->
    let list =
      List.map
        (fun (n, v) -> (n, if n = name then value else v))
        list in
    wallet#write Entity.name list wallet_encoding

  let save wallet list =
    wallet#write Entity.name wallet_encoding list

  include Entity

  let alias_param
      ?(name = "name") ?(desc = "existing " ^ Entity.name ^ " alias") next =
    param ~name ~desc
      (parameter
         ~autocomplete
         (fun (cctxt : #Client_context.wallet) s ->
            find cctxt s >>=? fun v ->
            return (s, v)))
      next

  type fresh_param = Fresh of string

  let of_fresh (wallet : #wallet) force (Fresh s) =
    load wallet >>=? fun list ->
    begin if force then
        return ()
      else
        iter_s
          (fun (n, v) ->
             if n = s then
               Entity.to_source v >>=? fun value ->
               failwith
                 "@[<v 2>The %s alias %s already exists.@,\
                  The current value is %s.@,\
                  Use -force to update@]"
                 Entity.name n
                 value
             else
               return ())
          list
    end >>=? fun () ->
    return s

  let fresh_alias_param
      ?(name = "new") ?(desc = "new " ^ Entity.name ^ " alias") next =
    param ~name ~desc
      (parameter (fun (_ : < .. >) s -> return @@ Fresh s))
      next

  let parse_source_string cctxt s =
    let read path =
      Lwt.catch
        (fun () ->
           Lwt_io.(with_file ~mode:Input path read) >>= fun content ->
           return content)
        (fun exn ->
           failwith
             "cannot read file (%s)" (Printexc.to_string exn))
      >>=? fun content ->
      of_source content in
    begin
      match String.split ~limit:1 ':' s with
      | [ "alias" ; alias ]->
          find cctxt alias
      | [ "text" ; text ] ->
          of_source text
      | [ "file" ; path ] ->
          read path
      | _ ->
          find cctxt s >>= function
          | Ok v -> return v
          | Error a_errs ->
              read s >>= function
              | Ok v -> return v
              | Error r_errs ->
                  of_source s >>= function
                  | Ok v -> return v
                  | Error s_errs ->
                      let all_errs =
                        List.flatten [ a_errs ; r_errs ; s_errs ] in
                      Lwt.return (Error all_errs)
    end

  let source_param ?(name = "src") ?(desc = "source " ^ Entity.name) next =
    let desc =
      Format.asprintf
        "%s\n\
         Can be a %s name, a file or a raw %s literal. If the \
         parameter is not the name of an existing %s, the client will \
         look for a file containing a %s, and if it does not exist, \
         the argument will be read as a raw %s.\n\
         Use 'alias:name', 'file:path' or 'text:literal' to disable \
         autodetect."
        desc Entity.name Entity.name Entity.name Entity.name Entity.name in
    param ~name ~desc
      (parameter parse_source_string)
      next

  let source_arg
      ?(long = "source " ^ Entity.name)
      ?(placeholder = "src")
      ?(doc = "") () =
    let doc =
      Format.asprintf
        "%s\n\
         Can be a %s name, a file or a raw %s literal. If the \
         parameter is not the name of an existing %s, the client will \
         look for a file containing a %s, and if it does not exist, \
         the argument will be read as a raw %s.\n\
         Use 'alias:name', 'file:path' or 'text:literal' to disable \
         autodetect."
        doc Entity.name Entity.name Entity.name Entity.name Entity.name in
    arg
      ~long
      ~placeholder
      ~doc
      (parameter parse_source_string)

  let force_switch () =
    Cli_entries.switch
      ~long:"force" ~short:'f'
      ~doc:("overwrite existing " ^ Entity.name) ()

  let name (wallet : #wallet) d =
    rev_find wallet d >>=? function
    | None -> Entity.to_source d
    | Some name -> return name

end
