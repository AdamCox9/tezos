(**************************************************************************)
(*                                                                        *)
(*    Copyright (c) 2014 - 2018.                                          *)
(*    Dynamic Ledger Solutions, Inc. <contact@tezos.com>                  *)
(*                                                                        *)
(*    All rights reserved. No warranty, explicit or implicit, provided.   *)
(*                                                                        *)
(**************************************************************************)

type location = Micheline.canonical_location

type annot = Micheline.annot

type expr = Michelson_v1_primitives.prim Micheline.canonical

type error += Lazy_script_decode (* `Permanent *)

type lazy_expr = expr Data_encoding.lazy_t

type node = (location, Michelson_v1_primitives.prim) Micheline.node

val location_encoding : location Data_encoding.t

val expr_encoding : expr Data_encoding.t

val lazy_expr_encoding : lazy_expr Data_encoding.t

val lazy_expr : expr -> lazy_expr

type t = { code : lazy_expr ; storage : lazy_expr }

val encoding : t Data_encoding.encoding

val deserialized_cost : expr -> Gas_limit_repr.cost

val serialized_cost : MBytes.t -> Gas_limit_repr.cost
val traversal_cost : node -> Gas_limit_repr.cost
val node_cost : node -> Gas_limit_repr.cost

val int_node_cost : Z.t -> Gas_limit_repr.cost
val int_node_cost_of_numbits : int -> Gas_limit_repr.cost
val string_node_cost : string -> Gas_limit_repr.cost
val string_node_cost_of_length : int -> Gas_limit_repr.cost
val bytes_node_cost : MBytes.t -> Gas_limit_repr.cost
val bytes_node_cost_of_length : int -> Gas_limit_repr.cost
val prim_node_cost_nonrec : expr list -> annot -> Gas_limit_repr.cost
val prim_node_cost_nonrec_of_length : int -> annot -> Gas_limit_repr.cost
val seq_node_cost_nonrec : expr list -> Gas_limit_repr.cost
val seq_node_cost_nonrec_of_length : int -> Gas_limit_repr.cost

val force_decode : lazy_expr -> (expr * Gas_limit_repr.cost) tzresult

val force_bytes : lazy_expr -> (MBytes.t * Gas_limit_repr.cost) tzresult

val minimal_deserialize_cost : lazy_expr -> Gas_limit_repr.cost
