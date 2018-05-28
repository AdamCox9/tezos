(**************************************************************************)
(*                                                                        *)
(*    Copyright (c) 2014 - 2018.                                          *)
(*    Dynamic Ledger Solutions, Inc. <contact@tezos.com>                  *)
(*                                                                        *)
(*    All rights reserved. No warranty, explicit or implicit, provided.   *)
(*                                                                        *)
(**************************************************************************)

(** Low-level byte array querying and manipulation.

    Default layout for numeric operations is big-endian.
    Little-endian operations in the LE submodule. **)

include module type of Bigstring
include Compare.S with type t := t

include EndianBigstring.EndianBigstringSig
module LE : EndianBigstring.EndianBigstringSig

val make : int -> char -> t
val of_hex : Hex.t -> t
val to_hex : t -> Hex.t
val pp_hex : Format.formatter -> t -> unit

(** [cut ?copy size bytes] cut [bytes] the in a list of successive
    chunks of length [size] at most.

    If [copy] is false (default), the blocks of the list
    can be garbage-collected only when all the blocks are
    unreachable (because of the 'optimized' implementation of
    [sub] used internally. *)
val cut: ?copy:bool -> int  -> t -> t list
