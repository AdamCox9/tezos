(**************************************************************************)
(*                                                                        *)
(*    Copyright (c) 2014 - 2018.                                          *)
(*    Dynamic Ledger Solutions, Inc. <contact@tezos.com>                  *)
(*                                                                        *)
(*    All rights reserved. No warranty, explicit or implicit, provided.   *)
(*                                                                        *)
(**************************************************************************)

module type T = sig
  val hash: Protocol_hash.t
  include Tezos_protocol_environment_shell.PROTOCOL
  val complete_b58prefix : Context.t -> string -> string list Lwt.t
end

type t = (module T)

let build_v1 hash =
  let (module F) = Tezos_protocol_registerer.Registerer.get_exn hash in
  let module Name = struct
    let name = Protocol_hash.to_b58check hash
  end in
  let module Env = Tezos_protocol_environment_shell.MakeV1(Name)() in
  (module struct
    let hash = hash
    module P = F(Env)
    include Env.Lift(P)
    let complete_b58prefix = Env.Context.complete
  end : T)

module VersionTable = Protocol_hash.Table

let versions : (module T) VersionTable.t =
  VersionTable.create 20

let mem hash =
  VersionTable.mem versions hash ||
  Tezos_protocol_registerer.Registerer.mem hash

let get_exn hash =
  try VersionTable.find versions hash
  with Not_found ->
    let proto = build_v1 hash in
    VersionTable.add versions hash proto ;
    proto

let get hash =
  try Some (get_exn hash)
  with Not_found -> None

module Register
    (Env : Tezos_protocol_environment_shell.V1)
    (Proto : Env.Updater.PROTOCOL)
    (Source : sig
       val hash: Protocol_hash.t option
       val sources: Protocol.t
     end) = struct

  let () =
    let hash =
      match Source.hash with
      | None -> Protocol.hash Source.sources
      | Some hash -> hash in
    let module Name = struct
      let name = Protocol_hash.to_b58check hash
    end in
    (* TODO add a memory table for "embedded" sources... *)
    VersionTable.add
      versions hash
      (module struct
        let hash = hash
        include Env.Lift(Proto)
        let complete_b58prefix = Env.Context.complete
      end : T)

end
