(**************************************************************************)
(*                                                                        *)
(*    Copyright (c) 2014 - 2018.                                          *)
(*    Dynamic Ledger Solutions, Inc. <contact@tezos.com>                  *)
(*                                                                        *)
(*    All rights reserved. No warranty, explicit or implicit, provided.   *)
(*                                                                        *)
(**************************************************************************)

open Alpha_context

let custom_root =
  (RPC_path.(open_root / "constants") : RPC_context.t RPC_path.context)

module S = struct

  open Data_encoding

  let preserved_cycles =
    RPC_service.post_service
      ~description: "How many cycle before the 'no-automatic-fork point'"
      ~query: RPC_query.empty
      ~input: empty
      ~output: (obj1 (req "preserved_cycles" int31))
      RPC_path.(custom_root / "preserved_cycles")

  let blocks_per_cycle =
    RPC_service.post_service
      ~description: "Cycle length"
      ~query: RPC_query.empty
      ~input: empty
      ~output: (obj1 (req "blocks_per_cycle" int32))
      RPC_path.(custom_root / "blocks_per_cycle")

  let blocks_per_voting_period =
    RPC_service.post_service
      ~description: "Length of the voting period"
      ~query: RPC_query.empty
      ~input: empty
      ~output: (obj1 (req "blocks_per_voting_period" int32))
      RPC_path.(custom_root / "blocks_per_voting_period")

  let blocks_per_commitment =
    RPC_service.post_service
      ~description: "How many blocks between random seed's nonce commitment"
      ~query: RPC_query.empty
      ~input: empty
      ~output: (obj1 (req "blocks_per_commitment" int32))
      RPC_path.(custom_root / "blocks_per_commitment")

  let blocks_per_roll_snapshot =
    RPC_service.post_service
      ~description: "How many blocks between roll snapshots"
      ~query: RPC_query.empty
      ~input: empty
      ~output: (obj1 (req "blocks_per_roll_snapshot" int32))
      RPC_path.(custom_root / "blocks_per_roll_snapshot")

  let time_between_blocks =
    RPC_service.post_service
      ~description: "Slot durations"
      ~query: RPC_query.empty
      ~input: empty
      ~output: (obj1 (req "time_between_slots" (list Period.encoding)))
      RPC_path.(custom_root / "time_between_slots")

  let first_free_baking_slot =
    RPC_service.post_service
      ~description: "First free baking slot"
      ~query: RPC_query.empty
      ~input: empty
      ~output: (obj1 (req "first_free_baking_slot" uint16))
      RPC_path.(custom_root / "first_free_baking_slot")

  let endorsers_per_block =
    RPC_service.post_service
      ~description: "Max signing slot"
      ~query: RPC_query.empty
      ~input: empty
      ~output: (obj1 (req "endorsers_per_block" uint16))
      RPC_path.(custom_root / "endorsers_per_block")

  let max_gas =
    RPC_service.post_service
      ~description: "Instructions per transaction"
      ~query: RPC_query.empty
      ~input: empty
      ~output: (obj1 (req "instructions_per_transaction" int31))
      RPC_path.(custom_root / "max_gas")

  let proof_of_work_threshold =
    RPC_service.post_service
      ~description: "Stamp threshold"
      ~query: RPC_query.empty
      ~input: empty
      ~output: (obj1 (req "proof_of_work_threshold" int64))
      RPC_path.(custom_root / "proof_of_work_threshold")

  let errors =
    RPC_service.post_service
      ~description: "Schema for all the RPC errors from this protocol version"
      ~query: RPC_query.empty
      ~input: empty
      ~output: json_schema
      RPC_path.(custom_root / "errors")

end


let () =
  let open Services_registration in
  register0 S.preserved_cycles begin fun ctxt () () ->
    return (Constants.preserved_cycles ctxt)
  end ;
  register0 S.blocks_per_cycle begin fun ctxt () () ->
    return (Constants.blocks_per_cycle ctxt)
  end ;
  register0 S.blocks_per_voting_period begin fun ctxt () () ->
    return (Constants.blocks_per_voting_period ctxt)
  end ;
  register0 S.blocks_per_commitment begin fun ctxt () () ->
    return (Constants.blocks_per_commitment ctxt)
  end ;
  register0 S.blocks_per_roll_snapshot begin fun ctxt () () ->
    return (Constants.blocks_per_roll_snapshot ctxt)
  end ;
  register0 S.time_between_blocks begin fun ctxt () () ->
    return (Constants.time_between_blocks ctxt)
  end ;
  register0 S.first_free_baking_slot begin fun ctxt () () ->
    return (Constants.first_free_baking_slot ctxt)
  end ;
  register0 S.endorsers_per_block begin fun ctxt () () ->
    return (Constants.endorsers_per_block ctxt)
  end ;
  register0 S.max_gas begin fun ctxt () () ->
    return (Constants.max_gas ctxt)
  end ;
  register0 S.proof_of_work_threshold begin fun ctxt () () ->
    return (Constants.proof_of_work_threshold ctxt)
  end ;
  register0_noctxt S.errors begin fun () () ->
    return (Data_encoding.Json.(schema error_encoding))
  end

let blocks_per_cycle ctxt block =
  RPC_context.make_call0 S.blocks_per_cycle ctxt block () ()
let preserved_cycles ctxt block =
  RPC_context.make_call0 S.preserved_cycles ctxt block () ()
let blocks_per_voting_period ctxt block =
  RPC_context.make_call0 S.blocks_per_voting_period ctxt block () ()
let blocks_per_commitment ctxt block =
  RPC_context.make_call0 S.blocks_per_commitment ctxt block () ()
let blocks_per_roll_snapshot ctxt block =
  RPC_context.make_call0 S.blocks_per_roll_snapshot ctxt block () ()
let time_between_blocks ctxt block =
  RPC_context.make_call0 S.time_between_blocks ctxt block () ()
let first_free_baking_slot ctxt block =
  RPC_context.make_call0 S.first_free_baking_slot ctxt block () ()
let endorsers_per_block ctxt block =
  RPC_context.make_call0 S.endorsers_per_block ctxt block () ()
let max_gas ctxt block =
  RPC_context.make_call0 S.max_gas ctxt block () ()
let proof_of_work_threshold ctxt block =
  RPC_context.make_call0 S.proof_of_work_threshold ctxt block () ()
let errors ctxt block =
  RPC_context.make_call0 S.errors ctxt block () ()
