(**************************************************************************)
(*                                                                        *)
(*    Copyright (c) 2014 - 2018.                                          *)
(*    Dynamic Ledger Solutions, Inc. <contact@tezos.com>                  *)
(*                                                                        *)
(*    All rights reserved. No warranty, explicit or implicit, provided.   *)
(*                                                                        *)
(**************************************************************************)

type t

type config = {
  genesis: State.Chain.genesis ;
  store_root: string ;
  context_root: string ;
  patch_context: (Context.t -> Context.t Lwt.t) option ;
  p2p: (P2p.config * P2p.limits) option ;
  test_chain_max_tll: int option ;
}

and peer_validator_limits = {
  new_head_request_timeout: float ;
  block_header_timeout: float ;
  block_operations_timeout: float ;
  protocol_timeout: float ;
  worker_limits: Worker_types.limits
}
and prevalidator_limits = {
  max_refused_operations: int ;
  operation_timeout: float ;
  worker_limits : Worker_types.limits ;
}
and block_validator_limits = {
  protocol_timeout: float ;
  worker_limits : Worker_types.limits ;
}
and chain_validator_limits = {
  bootstrap_threshold: int ;
  worker_limits : Worker_types.limits ;
}

val create:
  config ->
  peer_validator_limits ->
  block_validator_limits ->
  prevalidator_limits ->
  chain_validator_limits ->
  t tzresult Lwt.t

module RPC : sig

  type block = Block_services.block
  type block_info = Block_services.block_info

  val inject_block:
    t -> ?force:bool -> ?chain_id:Chain_id.t ->
    MBytes.t -> Operation.t list list ->
    (Block_hash.t * unit tzresult Lwt.t) tzresult Lwt.t
  (** [inject_block node ?force bytes] tries to insert [bytes]
      (supposedly the serialization of a block header) inside
      [node]. If [?force] is true, the block will be inserted even on
      non strictly increasing fitness. *)

  val inject_operation:
    t -> ?chain_id:Chain_id.t -> MBytes.t ->
    (Operation_hash.t * unit tzresult Lwt.t) Lwt.t
  val inject_protocol:
    t -> ?force:bool -> Protocol.t ->
    (Protocol_hash.t * unit tzresult Lwt.t) Lwt.t

  val raw_block_info:
    t -> Block_hash.t -> block_info Lwt.t
  val block_header_watcher:
    t -> (Block_hash.t * Block_header.t) Lwt_stream.t * Lwt_watcher.stopper
  val block_watcher:
    t -> (block_info Lwt_stream.t * Lwt_watcher.stopper)
  val heads: t -> block_info Block_hash.Map.t Lwt.t

  val predecessors:
    t -> int -> Block_hash.t -> Block_hash.t list Lwt.t

  val list:
    t -> int -> Block_hash.t list -> block_info list list Lwt.t

  val list_invalid:
    t -> (Block_hash.t * int32 * error list) list Lwt.t

  val unmark_invalid:
    t -> Block_hash.t -> unit tzresult Lwt.t

  val block_info:
    t -> block -> block_info Lwt.t

  val operation_hashes:
    t -> block -> Operation_hash.t list list Lwt.t
  val operations:
    t -> block -> Operation.t list list Lwt.t
  val operation_watcher:
    t -> (Operation_hash.t * Operation.t) Lwt_stream.t * Lwt_watcher.stopper

  val pending_operations:
    t -> 
    (error Preapply_result.t * Operation.t Operation_hash.Map.t) Lwt.t

  val protocols:
    t -> Protocol_hash.t list Lwt.t
  val protocol_content:
    t -> Protocol_hash.t -> Protocol.t tzresult Lwt.t
  val protocol_watcher:
    t -> (Protocol_hash.t * Protocol.t) Lwt_stream.t * Lwt_watcher.stopper

  val context_dir:
    t -> block -> 'a RPC_directory.t option Lwt.t

  (** Returns the content of the context at the given [path] descending
      recursively into directories as far as [depth] allows.
      Returns [None] if a path in not in the context or if [depth] is
      negative. *)
  val context_raw_get:
    t -> block -> path:string list -> depth:int ->
    Block_services.raw_context_result option Lwt.t

  val preapply:
    t -> block ->
    timestamp:Time.t -> protocol_data:MBytes.t ->
    sort_operations:bool -> Operation.t list list ->
    (Block_header.shell_header * error Preapply_result.t list) tzresult Lwt.t

  val complete:
    t -> ?block:block -> string -> string list Lwt.t

  val bootstrapped:
    t -> (Block_hash.t * Time.t) RPC_answer.stream


  val build_p2p_rpc_directory: t -> unit RPC_directory.t

end

val shutdown: t -> unit Lwt.t
