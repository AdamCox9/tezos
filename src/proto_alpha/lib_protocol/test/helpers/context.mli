(**************************************************************************)
(*                                                                        *)
(*    Copyright (c) 2014 - 2016.                                          *)
(*    Dynamic Ledger Solutions, Inc. <contact@tezos.com>                  *)
(*                                                                        *)
(*    All rights reserved. No warranty, explicit or implicit, provided.   *)
(*                                                                        *)
(**************************************************************************)

open Proto_alpha
open Alpha_context

type t =
  | B of Block.t
  | I of Incremental.t

val branch: t -> Block_hash.t

val get_level: t -> Raw_level.t tzresult Lwt.t

val get_endorsers: t -> Alpha_services.Delegate.Endorsing_rights.t list tzresult Lwt.t

val get_endorser: t -> int -> public_key_hash tzresult Lwt.t

val get_bakers: t -> public_key_hash list tzresult Lwt.t

(** Returns all the constants of the protocol *)
val get_constants: t -> Constants.t tzresult Lwt.t

module Contract : sig

  val pkh: Contract.t -> public_key_hash tzresult Lwt.t

  type balance_kind = Main | Deposit | Fees | Rewards

  (** Returns the balance of a contract, by default the main balance.
      If the contract is implicit the frozen balances are available too:
      deposit, fees ot rewards. *)
  val balance: ?kind:balance_kind -> t -> Contract.t -> Tez.t tzresult Lwt.t

  val counter: t -> Contract.t -> int32 tzresult Lwt.t
  val manager: t -> Contract.t -> Account.t tzresult Lwt.t
  val is_manager_key_revealed: t -> Contract.t -> bool tzresult Lwt.t

end

(** [init n] : returns an initial block with [n] initialized accounts
    and the associated implicit contracts *)
val init:
  ?slow: bool ->
  ?endorsers_per_block:int ->
  ?commitments:Commitment_repr.t list ->
  int -> (Block.t * Alpha_context.Contract.t list) tzresult Lwt.t
