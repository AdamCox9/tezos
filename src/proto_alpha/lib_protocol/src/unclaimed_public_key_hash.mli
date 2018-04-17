(**************************************************************************)
(*                                                                        *)
(*    Copyright (c) 2014 - 2018.                                          *)
(*    Dynamic Ledger Solutions, Inc. <contact@tezos.com>                  *)
(*                                                                        *)
(*    All rights reserved. No warranty, explicit or implicit, provided.   *)
(*                                                                        *)
(**************************************************************************)

type t

val encoding : t Data_encoding.t

val of_ed25519_pkh : Ed25519.Public_key_hash.t -> t

val to_b58check : t -> string
val of_b58check_exn : string -> t

module Index : sig
  type nonrec t = t
  val path_length : int
  val to_path : t -> string list -> string list
  val of_path : string list -> t option
end
