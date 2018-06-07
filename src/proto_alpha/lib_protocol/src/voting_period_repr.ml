(**************************************************************************)
(*                                                                        *)
(*    Copyright (c) 2014 - 2018.                                          *)
(*    Dynamic Ledger Solutions, Inc. <contact@tezos.com>                  *)
(*                                                                        *)
(*    All rights reserved. No warranty, explicit or implicit, provided.   *)
(*                                                                        *)
(**************************************************************************)

type t = int32
type voting_period = t
include (Compare.Int32 : Compare.S with type t := t)
let encoding = Data_encoding.int32
let pp ppf level = Format.fprintf ppf "%ld" level
let rpc_arg =
  let construct voting_period = Int32.to_string voting_period in
  let destruct str =
    match Int32.of_string str with
    | exception _ -> Error "Cannot parse voting period"
    | voting_period -> Ok voting_period in
  RPC_arg.make
    ~descr:"A voting period"
    ~name: "voting_period"
    ~construct
    ~destruct
    ()

let root = 0l
let succ = Int32.succ

let to_int32 l = l
let of_int32_exn l =
  if Compare.Int32.(l >= 0l)
  then l
  else invalid_arg "Voting_period_repr.of_int32"

type kind =
  | Proposal
  | Testing_vote
  | Testing
  | Promotion_vote

let kind_encoding =
  let open Data_encoding in
  union ~tag_size:`Uint8 [
    case (Tag 0)
      ~title:"Proposal"
      (constant "proposal")
      (function Proposal -> Some () | _ -> None)
      (fun () -> Proposal) ;
    case (Tag 1)
      ~title:"Testing_vote"
      (constant "testing_vote")
      (function Testing_vote -> Some () | _ -> None)
      (fun () -> Testing_vote) ;
    case (Tag 2)
      ~title:"Testing"
      (constant "testing")
      (function Testing -> Some () | _ -> None)
      (fun () -> Testing) ;
    case (Tag 3)
      ~title:"Promotion_vote"
      (constant "promotion_vote")
      (function Promotion_vote -> Some () | _ -> None)
      (fun () -> Promotion_vote) ;
  ]
