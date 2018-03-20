(**************************************************************************)
(*                                                                        *)
(*    Copyright (c) 2014 - 2018.                                          *)
(*    Dynamic Ledger Solutions, Inc. <contact@tezos.com>                  *)
(*                                                                        *)
(*    All rights reserved. No warranty, explicit or implicit, provided.   *)
(*                                                                        *)
(**************************************************************************)

(* Tezos Protocol Implementation - Low level Repr. of Operations *)

type raw = Operation.t = {
  shell: Operation.shell_header ;
  proto: MBytes.t ;
}

val raw_encoding: raw Data_encoding.t

type operation = {
  shell: Operation.shell_header ;
  contents: proto_operation ;
  signature: Ed25519.Signature.t option ;
}

and proto_operation =
  | Anonymous_operations of anonymous_operation list
  | Sourced_operations of sourced_operations

and anonymous_operation =
  | Seed_nonce_revelation of {
      level: Raw_level_repr.t ;
      nonce: Seed_repr.nonce ;
    }
  | Double_endorsement_evidence of {
      op1: operation ;
      op2: operation ;
    }
  | Double_baking_evidence of {
      bh1: Block_header_repr.t ;
      bh2: Block_header_repr.t ;
    }
  | Faucet of {
      id: Ed25519.Public_key_hash.t ;
      nonce: MBytes.t ;
    }

and sourced_operations =
  | Consensus_operation of consensus_operation
  | Amendment_operation of {
      source: Ed25519.Public_key_hash.t ;
      operation: amendment_operation ;
    }
  | Manager_operations of {
      source: Contract_repr.contract ;
      fee: Tez_repr.tez ;
      counter: counter ;
      operations: manager_operation list ;
    }
  | Dictator_operation of dictator_operation

and consensus_operation =
  | Endorsements of {
      block: Block_hash.t ;
      level: Raw_level_repr.t ;
      slots: int list ;
    }

and amendment_operation =
  | Proposals of {
      period: Voting_period_repr.t ;
      proposals: Protocol_hash.t list ;
    }
  | Ballot of {
      period: Voting_period_repr.t ;
      proposal: Protocol_hash.t ;
      ballot: Vote_repr.ballot ;
    }

and manager_operation =
  | Reveal of Ed25519.Public_key.t
  | Transaction of {
      amount: Tez_repr.tez ;
      parameters: Script_repr.expr option ;
      destination: Contract_repr.contract ;
    }
  | Origination of {
      manager: Ed25519.Public_key_hash.t ;
      delegate: Ed25519.Public_key_hash.t option ;
      script: Script_repr.t option ;
      spendable: bool ;
      delegatable: bool ;
      credit: Tez_repr.tez ;
    }
  | Delegation of Ed25519.Public_key_hash.t option

and dictator_operation =
  | Activate of Protocol_hash.t
  | Activate_testchain of Protocol_hash.t

and counter = Int32.t

type error += Cannot_parse_operation (* `Branch *)

val encoding: operation Data_encoding.t

val hash_raw: raw -> Operation_hash.t
val hash: operation -> Operation_hash.t

val parse: Operation.t -> operation tzresult

val acceptable_passes: operation -> int list

val parse_proto:
  MBytes.t ->
  (proto_operation * Ed25519.Signature.t option) tzresult Lwt.t

type error += Missing_signature (* `Permanent *)
type error += Invalid_signature (* `Permanent *)

val check_signature:
  Ed25519.Public_key.t -> operation -> unit tzresult Lwt.t

val forge: Operation.shell_header -> proto_operation -> MBytes.t

val proto_operation_encoding:
  proto_operation Data_encoding.t

val unsigned_operation_encoding:
  (Operation.shell_header * proto_operation) Data_encoding.t
