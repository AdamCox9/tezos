(**************************************************************************)
(*                                                                        *)
(*    Copyright (c) 2014 - 2018.                                          *)
(*    Dynamic Ledger Solutions, Inc. <contact@tezos.com>                  *)
(*                                                                        *)
(*    All rights reserved. No warranty, explicit or implicit, provided.   *)
(*                                                                        *)
(**************************************************************************)

(** Tezos - Manipulation and creation of hashes *)

(** {2 Predefined Hashes } ****************************************************)

include S.MINIMAL_HASH
include S.RAW_DATA with type t := t

(** {2 Building Hashes} *******************************************************)

(** The parameters for creating a new Hash type using
    {!Make_Blake2B}. Both {!name} and {!title} are only informative,
    used in error messages and serializers. *)

module type Name = sig
  val name : string
  val title : string
  val size : int option
end

module type PrefixedName = sig
  include Name
  val b58check_prefix : string
end

(** Builds a new Hash type using Blake2B. *)
module Make_minimal (Name : Name) : S.MINIMAL_HASH
module Make
    (Register : sig
       val register_encoding:
         prefix: string ->
         length: int ->
         to_raw: ('a -> string) ->
         of_raw: (string -> 'a option) ->
         wrap: ('a -> Base58.data) ->
         'a Base58.encoding
     end)
    (Name : PrefixedName) : S.HASH

(**/**)

module Make_merkle_tree
    (R : sig
       val register_encoding:
         prefix: string ->
         length:int ->
         to_raw: ('a -> string) ->
         of_raw: (string -> 'a option) ->
         wrap: ('a -> Base58.data) ->
         'a Base58.encoding
     end)
    (K : PrefixedName)
    (Contents: sig
       type t
       val to_bytes: t -> MBytes.t
     end) : S.MERKLE_TREE with type elt = Contents.t

module Generic_Merkle_tree (H : sig
    type t
    type elt
    val empty : t
    val leaf : elt -> t
    val node : t -> t -> t
  end) : sig
  val compute : H.elt list -> H.t
  type path =
    | Left of path * H.t
    | Right of H.t * path
    | Op
  val compute_path: H.elt list -> int -> path
  val check_path: path -> H.elt -> H.t * int
end
