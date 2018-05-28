(**************************************************************************)
(*                                                                        *)
(*    Copyright (c) 2014 - 2018.                                          *)
(*    Dynamic Ledger Solutions, Inc. <contact@tezos.com>                  *)
(*                                                                        *)
(*    All rights reserved. No warranty, explicit or implicit, provided.   *)
(*                                                                        *)
(**************************************************************************)

open Alpha_context

module S = struct

  open Data_encoding

  let custom_root = RPC_path.(open_root / "helpers")

  let minimal_timestamp =
    RPC_service.post_service
      ~description: "Minimal timestamp for the next block."
      ~query: RPC_query.empty
      ~input: (obj1 (opt "priority" int31))
      ~output: (obj1 (req "timestamp" Timestamp.encoding))
      RPC_path.(custom_root / "minimal_timestamp")

  let run_code_input_encoding =
    (obj5
       (req "script" Script.expr_encoding)
       (req "storage" Script.expr_encoding)
       (req "input" Script.expr_encoding)
       (req "amount" Tez.encoding)
       (req "contract" Contract.encoding))

  let run_code =
    RPC_service.post_service
      ~description: "Run a piece of code in the current context"
      ~query: RPC_query.empty
      ~input: run_code_input_encoding
      ~output: (obj3
                  (req "storage" Script.expr_encoding)
                  (req "operations" (list Operation.internal_operation_encoding))
                  (opt "big_map_diff" (list (tup2 string (option Script.expr_encoding)))))
      RPC_path.(custom_root / "run_code")

  let apply_operation =
    RPC_service.post_service
      ~description: "Applies an operation in the current context"
      ~query: RPC_query.empty
      ~input: (obj4
                 (req "pred_block" Block_hash.encoding)
                 (req "operation_hash" Operation_hash.encoding)
                 (req "forged_operation" bytes)
                 (opt "signature" Signature.encoding))
      ~output: Apply_operation_result.encoding
      RPC_path.(custom_root / "apply_operation")

  let trace_code =
    RPC_service.post_service
      ~description: "Run a piece of code in the current context, \
                     keeping a trace"
      ~query: RPC_query.empty
      ~input: run_code_input_encoding
      ~output: (obj4
                  (req "storage" Script.expr_encoding)
                  (req "operations" (list Operation.internal_operation_encoding))
                  (req "trace"
                     (list @@ obj3
                        (req "location" Script.location_encoding)
                        (req "gas" Gas.encoding)
                        (req "stack" (list (Script.expr_encoding)))))
                  (opt "big_map_diff" (list (tup2 string (option Script.expr_encoding)))))
      RPC_path.(custom_root / "trace_code")

  let typecheck_code =
    RPC_service.post_service
      ~description: "Typecheck a piece of code in the current context"
      ~query: RPC_query.empty
      ~input: (obj2
                 (req "program" Script.expr_encoding)
                 (opt "gas" z))
      ~output: (obj2
                  (req "type_map" Script_tc_errors_registration.type_map_enc)
                  (req "gas" Gas.encoding))
      RPC_path.(custom_root / "typecheck_code")

  let typecheck_data =
    RPC_service.post_service
      ~description: "Check that some data expression is well formed \
                     and of a given type in the current context"
      ~query: RPC_query.empty
      ~input: (obj3
                 (req "data" Script.expr_encoding)
                 (req "type" Script.expr_encoding)
                 (opt "gas" z))
      ~output: (obj1 (req "gas" Gas.encoding))
      RPC_path.(custom_root / "typecheck_data")

  let hash_data =
    RPC_service.post_service
      ~description: "Computes the hash of some data expression \
                     using the same algorithm as script instruction H"

      ~input: (obj3
                 (req "data" Script.expr_encoding)
                 (req "type" Script.expr_encoding)
                 (opt "gas" z))
      ~output: (obj2
                  (req "hash" string)
                  (req "gas" Gas.encoding))
      ~query: RPC_query.empty
      RPC_path.(custom_root / "hash_data")

  let level =
    RPC_service.post_service
      ~description: "..."
      ~query: RPC_query.empty
      ~input: (obj1 (opt "offset" int32))
      ~output: Level.encoding
      RPC_path.(custom_root / "level" /: Raw_level.arg)

  let levels =
    RPC_service.post_service
      ~description: "Levels of a cycle"
      ~query: RPC_query.empty
      ~input: empty
      ~output: (describe ~title: "levels of a cycle"
                  (obj2
                     (req "first" Raw_level.encoding)
                     (req "last" Raw_level.encoding)))
      RPC_path.(custom_root / "levels" /: Cycle.arg)

end

module I = struct

  let apply_operation ctxt () (pred_block, hash, forged_operation, signature) =
    (* ctxt accept_failing_script baker_contract pred_block block_prio operation *)
    match Data_encoding.Binary.of_bytes
            Operation.unsigned_operation_encoding
            forged_operation with
    | None -> Error_monad.fail Operation.Cannot_parse_operation
    | Some (shell, contents) ->
        let operation = { shell ; contents ; signature } in
        Apply.apply_operation ctxt Readable pred_block hash operation
        >>=? fun (_, result) -> return result

end

let () =
  let open Services_registration in
  register0 S.minimal_timestamp begin fun ctxt () slot ->
    let timestamp = Alpha_context.Timestamp.current ctxt in
    let slot = match slot with None -> 0 | Some p -> p in
    Baking.minimal_time ctxt slot timestamp
  end ;
  register0 S.apply_operation I.apply_operation ;
  register0 S.run_code begin fun ctxt ()
    (code, storage, parameter, amount, contract) ->
    Lwt.return (Gas.set_limit ctxt (Constants.hard_gas_limit_per_operation ctxt)) >>=? fun ctxt ->
    let ctxt = Contract.init_origination_nonce ctxt Operation_hash.zero in
    let storage = Script.lazy_expr storage in
    let code = Script.lazy_expr code in
    Script_interpreter.execute
      ctxt Readable
      ~source:contract (* transaction initiator *)
      ~payer:contract (* storage fees payer *)
      ~self:(contract, { storage ; code }) (* script owner *)
      ~amount ~parameter
    >>=? fun { Script_interpreter.storage ; operations ; big_map_diff ; _ } ->
    return (storage, operations, big_map_diff)
  end ;
  register0 S.trace_code begin fun ctxt ()
    (code, storage, parameter, amount, contract) ->
    Lwt.return (Gas.set_limit ctxt (Constants.hard_gas_limit_per_operation ctxt)) >>=? fun ctxt ->
    let ctxt = Contract.init_origination_nonce ctxt Operation_hash.zero in
    let storage = Script.lazy_expr storage in
    let code = Script.lazy_expr code in
    Script_interpreter.trace
      ctxt Readable
      ~source:contract (* transaction initiator *)
      ~payer:contract (* storage fees payer *)
      ~self:(contract, { storage ; code }) (* script owner *)
      ~amount ~parameter
    >>=? fun ({ Script_interpreter.storage ; operations ; big_map_diff ; _ }, trace) ->
    return (storage, operations, trace, big_map_diff)
  end ;
  register0 S.typecheck_code begin fun ctxt () (expr, maybe_gas) ->
    begin match maybe_gas with
      | None -> return (Gas.set_unlimited ctxt)
      | Some gas -> Lwt.return (Gas.set_limit ctxt gas) end >>=? fun ctxt ->
    Script_ir_translator.typecheck_code ctxt expr >>=? fun (res, ctxt) ->
    return (res, Gas.level ctxt)
  end ;
  register0 S.typecheck_data begin fun ctxt () (data, ty, maybe_gas) ->
    begin match maybe_gas with
      | None -> return (Gas.set_unlimited ctxt)
      | Some gas -> Lwt.return (Gas.set_limit ctxt gas) end >>=? fun ctxt ->
    Script_ir_translator.typecheck_data ctxt (data, ty) >>=? fun ctxt ->
    return (Gas.level ctxt)
  end ;
  register0 S.hash_data begin fun ctxt () (expr, typ, maybe_gas) ->
    let open Script_ir_translator in
    begin match maybe_gas with
      | None -> return (Gas.set_unlimited ctxt)
      | Some gas -> Lwt.return (Gas.set_limit ctxt gas) end >>=? fun ctxt ->
    Lwt.return (parse_ty ~allow_big_map:false ~allow_operation:false (Micheline.root typ)) >>=? fun (Ex_ty typ, _) ->
    parse_data ctxt typ (Micheline.root expr) >>=? fun (data, ctxt) ->
    Script_ir_translator.hash_data ctxt typ data >>=? fun (hash, ctxt) ->
    return (hash, Gas.level ctxt)
  end ;
  register1 S.level begin fun ctxt raw () offset ->
    return (Level.from_raw ctxt ?offset raw)
  end ;
  register1 S.levels begin fun ctxt cycle () () ->
    let levels = Level.levels_in_cycle ctxt cycle in
    let first = List.hd (List.rev levels) in
    let last = List.hd levels in
    return (first.level, last.level)
  end

let minimal_time ctxt ?priority block =
  RPC_context.make_call0 S.minimal_timestamp ctxt block () priority

let run_code ctxt block code (storage, input, amount, contract) =
  RPC_context.make_call0 S.run_code ctxt
    block () (code, storage, input, amount, contract)

let apply_operation ctxt block pred_block hash forged_operation signature =
  RPC_context.make_call0 S.apply_operation ctxt
    block () (pred_block, hash, forged_operation, signature)

let trace_code ctxt block code (storage, input, amount, contract) =
  RPC_context.make_call0 S.trace_code ctxt
    block () (code, storage, input, amount, contract)

let typecheck_code ctxt block =
  RPC_context.make_call0 S.typecheck_code ctxt block ()

let typecheck_data ctxt block =
  RPC_context.make_call0 S.typecheck_data ctxt block ()

let hash_data ctxt block =
  RPC_context.make_call0 S.hash_data ctxt block ()

let level ctxt block ?offset lvl =
  RPC_context.make_call1 S.level ctxt block lvl () offset

let levels ctxt block cycle =
  RPC_context.make_call1 S.levels ctxt block cycle () ()

module Forge = struct

  module S = struct

    open Data_encoding

    let custom_root = RPC_path.(open_root / "helpers" / "forge")

    let operations =
      RPC_service.post_service
        ~description:"Forge an operation"
        ~query: RPC_query.empty
        ~input: Operation.unsigned_operation_encoding
        ~output:
          (obj1
             (req "operation" @@
              describe ~title: "hex encoded operation" bytes))
        RPC_path.(custom_root / "operations" )

    let empty_proof_of_work_nonce =
      MBytes.of_string
        (String.make Constants_repr.proof_of_work_nonce_size  '\000')

    let protocol_data =
      RPC_service.post_service
        ~description: "Forge the protocol-specific part of a block header"
        ~query: RPC_query.empty
        ~input:
          (obj3
             (req "priority" uint16)
             (opt "nonce_hash" Nonce_hash.encoding)
             (dft "proof_of_work_nonce"
                (Fixed.bytes
                   Alpha_context.Constants.proof_of_work_nonce_size)
                empty_proof_of_work_nonce))
        ~output: (obj1 (req "protocol_data" bytes))
        RPC_path.(custom_root / "protocol_data")

  end

  let () =
    let open Services_registration in
    register0_noctxt S.operations begin fun () (shell, proto) ->
      return (Operation.forge shell proto)
    end ;
    register0_noctxt S.protocol_data begin fun ()
      (priority, seed_nonce_hash, proof_of_work_nonce) ->
      return (Block_header.forge_unsigned_protocol_data
                { priority ; seed_nonce_hash ; proof_of_work_nonce })
    end

  module Manager = struct

    let operations ctxt
        block ~branch ~source ?sourcePubKey ~counter ~fee
        ~gas_limit ~storage_limit operations =
      Contract_services.manager_key ctxt block source >>= function
      | Error _ as e -> Lwt.return e
      | Ok (_, revealed) ->
          let operations =
            match revealed with
            | Some _ -> operations
            | None ->
                match sourcePubKey with
                | None -> operations
                | Some pk -> Reveal pk :: operations in
          let ops =
            Manager_operations { source ;
                                 counter ; operations ; fee ;
                                 gas_limit ; storage_limit } in
          (RPC_context.make_call0 S.operations ctxt block
             () ({ branch }, Sourced_operation ops))

    let reveal ctxt
        block ~branch ~source ~sourcePubKey ~counter ~fee ()=
      operations ctxt block ~branch ~source ~sourcePubKey ~counter ~fee
        ~gas_limit:Z.zero ~storage_limit:0L []

    let transaction ctxt
        block ~branch ~source ?sourcePubKey ~counter
        ~amount ~destination ?parameters
        ~gas_limit ~storage_limit ~fee ()=
      let parameters = Option.map ~f:Script.lazy_expr parameters in
      operations ctxt block ~branch ~source ?sourcePubKey ~counter
        ~fee ~gas_limit ~storage_limit
        Alpha_context.[Transaction { amount ; parameters ; destination }]

    let origination ctxt
        block ~branch
        ~source ?sourcePubKey ~counter
        ~managerPubKey ~balance
        ?(spendable = true)
        ?(delegatable = true)
        ?delegatePubKey ?script
        ~gas_limit ~storage_limit ~fee () =
      operations ctxt block ~branch ~source ?sourcePubKey ~counter
        ~fee ~gas_limit ~storage_limit
        Alpha_context.[
          Origination { manager = managerPubKey ;
                        delegate = delegatePubKey ;
                        script ;
                        spendable ;
                        delegatable ;
                        credit = balance ;
                        preorigination = None }
        ]

    let delegation ctxt
        block ~branch ~source ?sourcePubKey ~counter ~fee delegate =
      operations ctxt block ~branch ~source ?sourcePubKey ~counter ~fee
        ~gas_limit:Z.zero ~storage_limit:0L
        Alpha_context.[Delegation delegate]

  end

  module Consensus = struct

    let operations ctxt
        block ~branch operation =
      let ops = Consensus_operation operation in
      (RPC_context.make_call0 S.operations ctxt block
         () ({ branch }, Sourced_operation ops))

    let endorsement ctxt
        b ~branch ~block ~level ~slots () =
      operations ctxt b ~branch
        Alpha_context.(Endorsements { block ; level ; slots })


  end

  module Amendment = struct

    let operation ctxt
        block ~branch ~source operation =
      let ops = Amendment_operation { source ; operation } in
      (RPC_context.make_call0 S.operations ctxt block
         () ({ branch }, Sourced_operation ops))

    let proposals ctxt
        b ~branch ~source ~period ~proposals () =
      operation ctxt b ~branch ~source
        Alpha_context.(Proposals { period ; proposals })

    let ballot ctxt
        b ~branch ~source ~period ~proposal ~ballot () =
      operation ctxt b ~branch ~source
        Alpha_context.(Ballot { period ; proposal ; ballot })

  end

  module Dictator = struct

    let operation ctxt
        block ~branch operation =
      let op = Dictator_operation operation in
      (RPC_context.make_call0 S.operations ctxt block
         () ({ branch }, Sourced_operation op))

    let activate ctxt
        b ~branch hash =
      operation ctxt b ~branch (Activate hash)

    let activate_testchain ctxt
        b ~branch hash =
      operation ctxt b ~branch (Activate_testchain hash)

  end

  module Anonymous = struct

    let operations ctxt block ~branch operations =
      (RPC_context.make_call0 S.operations ctxt block
         () ({ branch }, Anonymous_operations operations))

    let seed_nonce_revelation ctxt
        block ~branch ~level ~nonce () =
      operations ctxt block ~branch [Seed_nonce_revelation { level ; nonce }]

  end

  let empty_proof_of_work_nonce =
    MBytes.of_string
      (String.make Constants_repr.proof_of_work_nonce_size  '\000')

  let protocol_data ctxt
      block
      ~priority ?seed_nonce_hash
      ?(proof_of_work_nonce = empty_proof_of_work_nonce)
      () =
    RPC_context.make_call0 S.protocol_data
      ctxt block () (priority, seed_nonce_hash, proof_of_work_nonce)

end

module Parse = struct

  module S = struct

    open Data_encoding

    let custom_root = RPC_path.(open_root / "helpers" / "parse")

    let operations =
      RPC_service.post_service
        ~description:"Parse operations"
        ~query: RPC_query.empty
        ~input:
          (obj2
             (req "operations" (list (dynamic_size Operation.raw_encoding)))
             (opt "check_signature" bool))
        ~output: (list (dynamic_size Operation.encoding))
        RPC_path.(custom_root / "operations" )

    let block =
      RPC_service.post_service
        ~description:"Parse a block"
        ~query: RPC_query.empty
        ~input: Block_header.raw_encoding
        ~output: Block_header.protocol_data_encoding
        RPC_path.(custom_root / "block" )

  end

  module I = struct

    let check_signature ctxt signature shell contents =
      match contents with
      | Anonymous_operations _ -> return ()
      | Sourced_operation (Manager_operations op) ->
          let public_key =
            List.fold_left (fun acc op ->
                match op with
                | Reveal pk -> Some pk
                | _ -> acc) None op.operations in
          begin
            match public_key with
            | Some key -> return key
            | None ->
                Contract.get_manager ctxt op.source >>=? fun manager ->
                Roll.delegate_pubkey ctxt manager
          end >>=? fun public_key ->
          Operation.check_signature public_key
            { signature ; shell ; contents }
      | Sourced_operation (Consensus_operation (Endorsements { level ; slots ; _ })) ->
          let level = Level.from_raw ctxt level in
          Baking.check_endorsements_rights ctxt level slots >>=? fun public_key ->
          Operation.check_signature public_key
            { signature ; shell ; contents }
      | Sourced_operation (Amendment_operation { source ; _ }) ->
          Roll.delegate_pubkey ctxt source >>=? fun source ->
          Operation.check_signature source
            { signature ; shell ; contents }
      | Sourced_operation (Dictator_operation _) ->
          let key = Constants.dictator_pubkey ctxt in
          Operation.check_signature key
            { signature ; shell ; contents }

  end

  let () =
    let open Services_registration in
    register0 S.operations begin fun ctxt () (operations, check) ->
      map_s begin fun raw ->
        Lwt.return (Operation.parse raw) >>=? fun op ->
        begin match check with
          | Some true -> I.check_signature ctxt op.signature op.shell op.contents
          | Some false | None -> return ()
        end >>|? fun () -> op
      end operations
    end ;
    register0_noctxt S.block begin fun () raw_block ->
      Lwt.return (Block_header.parse raw_block) >>=? fun { protocol_data ; _ } ->
      return protocol_data
    end

  let operations ctxt block ?check operations =
    RPC_context.make_call0
      S.operations ctxt block () (operations, check)
  let block ctxt block shell protocol_data =
    RPC_context.make_call0
      S.block ctxt block () ({ shell ; protocol_data } : Block_header.raw)

end
