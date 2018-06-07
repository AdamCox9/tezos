(**************************************************************************)
(*                                                                        *)
(*    Copyright (c) 2014 - 2018.                                          *)
(*    Dynamic Ledger Solutions, Inc. <contact@tezos.com>                  *)
(*                                                                        *)
(*    All rights reserved. No warranty, explicit or implicit, provided.   *)
(*                                                                        *)
(**************************************************************************)

type t =

  | Get_current_branch of Chain_id.t
  | Current_branch of Chain_id.t * Block_locator.t
  | Deactivate of Chain_id.t

  | Get_current_head of Chain_id.t
  | Current_head of Chain_id.t * Block_header.t * Mempool.t

  | Get_block_headers of Block_hash.t list
  | Block_header of Block_header.t

  | Get_operations of Operation_hash.t list
  | Operation of Operation.t

  | Get_protocols of Protocol_hash.t list
  | Protocol of Protocol.t

  | Get_operation_hashes_for_blocks of (Block_hash.t * int) list
  | Operation_hashes_for_block of
      Block_hash.t * int *
      Operation_hash.t list * Operation_list_list_hash.path

  | Get_operations_for_blocks of (Block_hash.t * int) list
  | Operations_for_block of
      Block_hash.t * int *
      Operation.t list * Operation_list_list_hash.path

let encoding =
  let open Data_encoding in
  let case ?max_length ~tag ~title encoding unwrap wrap =
    P2p.Encoding { tag ; title ; encoding ; wrap ; unwrap ; max_length } in
  [
    case ~tag:0x10
      ~title:"Get_current_branch"
      (obj1
         (req "get_current_branch" Chain_id.encoding))
      (function
        | Get_current_branch chain_id -> Some chain_id
        | _ -> None)
      (fun chain_id -> Get_current_branch chain_id) ;

    case ~tag:0x11
      ~title:"Current_branch"
      (obj2
         (req "chain_id" Chain_id.encoding)
         (req "current_branch" Block_locator.encoding))
      (function
        | Current_branch (chain_id, locator) -> Some (chain_id, locator)
        | _ -> None)
      (fun (chain_id, locator) -> Current_branch (chain_id, locator)) ;

    case ~tag:0x12
      ~title:"Deactivate"
      (obj1
         (req "deactivate" Chain_id.encoding))
      (function
        | Deactivate chain_id -> Some chain_id
        | _ -> None)
      (fun chain_id -> Deactivate chain_id) ;

    case ~tag:0x13
      ~title:"Get_current_head"
      (obj1
         (req "get_current_head" Chain_id.encoding))
      (function
        | Get_current_head chain_id -> Some chain_id
        | _ -> None)
      (fun chain_id -> Get_current_head chain_id) ;

    case ~tag:0x14
      ~title:"Current_head"
      (obj3
         (req "chain_id" Chain_id.encoding)
         (req "current_block_header" (dynamic_size Block_header.encoding))
         (req "current_mempool" Mempool.encoding))
      (function
        | Current_head (chain_id, bh, mempool) -> Some (chain_id, bh, mempool)
        | _ -> None)
      (fun (chain_id, bh, mempool) -> Current_head (chain_id, bh, mempool)) ;

    case ~tag:0x20
      ~title:"Get_block_headers"
      (obj1 (req "get_block_headers" (list Block_hash.encoding)))
      (function
        | Get_block_headers bhs -> Some bhs
        | _ -> None)
      (fun bhs -> Get_block_headers bhs) ;

    case ~tag:0x21
      ~title:"Block_header"
      (obj1 (req "block_header" Block_header.encoding))
      (function
        | Block_header bh -> Some bh
        | _ -> None)
      (fun bh -> Block_header bh) ;

    case ~tag:0x30
      ~title:"Get_operations"
      (obj1 (req "get_operations" (list Operation_hash.encoding)))
      (function
        | Get_operations bhs -> Some bhs
        | _ -> None)
      (fun bhs -> Get_operations bhs) ;

    case ~tag:0x31
      ~title:"Operation"
      (obj1 (req "operation" Operation.encoding))
      (function Operation o -> Some o | _ -> None)
      (fun o -> Operation o);

    case ~tag:0x40
      ~title:"Get_protocols"
      (obj1
         (req "get_protocols" (list  Protocol_hash.encoding)))
      (function
        | Get_protocols protos -> Some protos
        | _ -> None)
      (fun protos -> Get_protocols protos);

    case ~tag:0x41
      ~title:"Protocol"
      (obj1 (req "protocol" Protocol.encoding))
      (function Protocol proto -> Some proto  | _ -> None)
      (fun proto -> Protocol proto);

    case ~tag:0x50
      ~title:"Get_operation_hashes_for_blocks"
      (obj1 (req "get_operation_hashes_for_blocks"
               (list (tup2 Block_hash.encoding int8))))
      (function
        | Get_operation_hashes_for_blocks keys -> Some keys
        | _ -> None)
      (fun keys -> Get_operation_hashes_for_blocks keys);

    case ~tag:0x51
      ~title:"Operation_hashes_for_blocks"
      (obj3
         (req "operation_hashes_for_block"
            (obj2
               (req "hash" Block_hash.encoding)
               (req "validation_pass" int8)))
         (req "operation_hashes" (list Operation_hash.encoding))
         (req "operation_hashes_path" Operation_list_list_hash.path_encoding))
      (function Operation_hashes_for_block (block, ofs, ops, path) ->
         Some ((block, ofs), ops, path) | _ -> None)
      (fun ((block, ofs), ops, path) ->
         Operation_hashes_for_block (block, ofs, ops, path)) ;

    case ~tag:0x60
      ~title:"Get_operations_for_blocks"
      (obj1 (req "get_operations_for_blocks"
               (list (obj2
                        (req "hash" Block_hash.encoding)
                        (req "validation_pass" int8)))))
      (function
        | Get_operations_for_blocks keys -> Some keys
        | _ -> None)
      (fun keys -> Get_operations_for_blocks keys);

    case ~tag:0x61
      ~title:"Operations_for_blocks"
      (obj3
         (req "operations_for_block"
            (obj2
               (req "hash" Block_hash.encoding)
               (req "validation_pass" int8)))
         (req "operations" (list (dynamic_size Operation.encoding)))
         (req "operations_path" Operation_list_list_hash.path_encoding))
      (function Operations_for_block (block, ofs, ops, path) ->
         Some ((block, ofs), ops, path) | _ -> None)
      (fun ((block, ofs), ops, path) ->
         Operations_for_block (block, ofs, ops, path)) ;

  ]

let versions =
  let open P2p_version in
  [ { name = "TEZOS_2018-05-28T15:19:50Z" ;
      major = 0 ;
      minor = 0 ;
    }
  ]

let cfg : _ P2p.message_config = { encoding ; versions }

let raw_encoding = P2p.Raw.encoding encoding

let pp_json ppf msg =
  Data_encoding.Json.pp ppf
    (Data_encoding.Json.construct raw_encoding (Message msg))
