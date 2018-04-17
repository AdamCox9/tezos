(**************************************************************************)
(*                                                                        *)
(*    Copyright (c) 2014 - 2018.                                          *)
(*    Dynamic Ledger Solutions, Inc. <contact@tezos.com>                  *)
(*                                                                        *)
(*    All rights reserved. No warranty, explicit or implicit, provided.   *)
(*                                                                        *)
(**************************************************************************)

open Error_monad

(** {2 Hash Types} ************************************************************)

(** The signature of an abstract hash type, as produced by functor
    {!Make_Blake2B}. The {!t} type is abstracted for separating the
    various kinds of hashes in the system at typing time. Each type is
    equipped with functions to use it as is of as keys in the database
    or in memory sets and maps. *)

module type MINIMAL_HASH = sig

  type t

  val name: string
  val title: string

  val pp: Format.formatter -> t -> unit
  val pp_short: Format.formatter -> t -> unit

  include Compare.S with type t := t

  val hash_bytes: ?key:Cstruct.buffer -> Cstruct.buffer list -> t
  val hash_string: ?key:string -> string list -> t

  val zero: t

end

module type RAW_DATA = sig

  type t

  val size: int (* in bytes *)
  val to_hex: t -> Hex.t
  val of_hex: Hex.t -> t tzresult
  val of_hex_opt: Hex.t -> t option
  val of_hex_exn: Hex.t -> t

  val to_string: t -> string
  val of_string: string -> t tzresult
  val of_string_opt: string -> t option
  val of_string_exn: string -> t

  val to_bytes: t -> MBytes.t

  val of_bytes: MBytes.t -> t tzresult
  val of_bytes_opt: MBytes.t -> t option
  val of_bytes_exn: MBytes.t -> t

end

module type B58_DATA = sig

  type t

  val to_b58check: t -> string
  val to_short_b58check: t -> string

  val of_b58check: string -> t tzresult
  val of_b58check_exn: string -> t
  val of_b58check_opt: string -> t option

  type Base58.data += Data of t
  val b58check_encoding: t Base58.encoding

end

module type ENCODER = sig

  type t

  val encoding: t Data_encoding.t

  val rpc_arg: t RPC_arg.t

  val param:
    ?name:string ->
    ?desc:string ->
    ('a, 'arg) Clic.params ->
    (t -> 'a, 'arg) Clic.params

end

module type INDEXES = sig

  type t

  val to_path: t -> string list -> string list
  val of_path: string list -> t option
  val of_path_exn: string list -> t

  val prefix_path: string -> string list
  val path_length: int

  module Set : sig
    include Set.S with type elt = t
    val random_elt: t -> elt
    val encoding: t Data_encoding.t
  end

  module Map : sig
    include Map.S with type key = t
    val encoding: 'a Data_encoding.t -> 'a t Data_encoding.t
  end

  module Table : sig
    include Hashtbl.S with type key = t
    val encoding: 'a Data_encoding.t -> 'a t Data_encoding.t
  end

end

module type HASH = sig
  include MINIMAL_HASH
  include RAW_DATA with type t := t
  include B58_DATA with type t := t
  include ENCODER with type t := t
  include INDEXES with type t := t
end

module type MERKLE_TREE = sig

  type elt
  val elt_bytes: elt -> MBytes.t

  include HASH

  val compute: elt list -> t
  val empty: t

  type path =
    | Left of path * t
    | Right of t * path
    | Op

  val path_encoding: path Data_encoding.t

  val compute_path: elt list -> int -> path
  val check_path: path -> elt -> t * int

end

module type SIGNATURE = sig

  module Public_key_hash : sig

    type t

    val pp: Format.formatter -> t -> unit
    val pp_short: Format.formatter -> t -> unit
    include Compare.S with type t := t
    include RAW_DATA with type t := t
    include B58_DATA with type t := t
    include ENCODER with type t := t
    include INDEXES with type t := t

  end

  module Public_key : sig

    type t

    val pp: Format.formatter -> t -> unit
    include Compare.S with type t := t
    include B58_DATA with type t := t
    include ENCODER with type t := t

    val hash: t -> Public_key_hash.t

  end

  module Secret_key : sig

    type t

    val pp: Format.formatter -> t -> unit
    include Compare.S with type t := t
    include B58_DATA with type t := t
    include ENCODER with type t := t

    val to_public_key: t -> Public_key.t

  end

  type t

  val pp: Format.formatter -> t -> unit
  include Compare.S with type t := t
  include B58_DATA with type t := t
  include ENCODER with type t := t

  val zero: t

  (** Check a signature *)
  val check: Public_key.t -> t -> MBytes.t -> bool

  (** Append a signature *)
  val append: Secret_key.t -> MBytes.t -> MBytes.t
  val concat: MBytes.t -> t -> MBytes.t

  val sign: Secret_key.t -> MBytes.t -> t

  val generate_key: unit -> (Public_key_hash.t * Public_key.t * Secret_key.t)

end
