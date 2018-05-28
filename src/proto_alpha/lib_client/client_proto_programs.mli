(**************************************************************************)
(*                                                                        *)
(*    Copyright (c) 2014 - 2018.                                          *)
(*    Dynamic Ledger Solutions, Inc. <contact@tezos.com>                  *)
(*                                                                        *)
(*    All rights reserved. No warranty, explicit or implicit, provided.   *)
(*                                                                        *)
(**************************************************************************)

open Proto_alpha
open Alpha_context
open Tezos_micheline

module Program : Client_aliases.Alias
  with type t = Michelson_v1_parser.parsed Micheline_parser.parsing_result

val run :
  ?contract:Contract.t ->
  ?amount:Tez.t ->
  program:Michelson_v1_parser.parsed ->
  storage:Michelson_v1_parser.parsed ->
  input:Michelson_v1_parser.parsed ->
  Block_services.block ->
  #Proto_alpha.rpc_context ->
  (Script.expr *
   internal_operation list *
   Contract.big_map_diff option) tzresult Lwt.t

val trace :
  ?contract:Contract.t ->
  ?amount:Tez.t ->
  program:Michelson_v1_parser.parsed ->
  storage:Michelson_v1_parser.parsed ->
  input:Michelson_v1_parser.parsed ->
  Block_services.block ->
  #Proto_alpha.rpc_context ->
  (Script.expr *
   internal_operation list *
   Script_interpreter.execution_trace *
   Contract.big_map_diff option) tzresult Lwt.t

val print_run_result :
  #Client_context.printer ->
  show_source:bool ->
  parsed:Michelson_v1_parser.parsed ->
  (Script_repr.expr *
   internal_operation list *
   Contract.big_map_diff option) tzresult -> unit tzresult Lwt.t

val print_trace_result :
  #Client_context.printer ->
  show_source:bool ->
  parsed:Michelson_v1_parser.parsed ->
  (Script_repr.expr *
   internal_operation list *
   Script_interpreter.execution_trace *
   Contract.big_map_diff option)
    tzresult -> unit tzresult Lwt.t

val hash_and_sign :
  ?gas:Z.t ->
  Michelson_v1_parser.parsed ->
  Michelson_v1_parser.parsed ->
  Client_keys.sk_uri ->
  Block_services.block ->
  #Proto_alpha.full ->
  (string * string * Gas.t) tzresult Lwt.t

val typecheck_data :
  ?gas:Z.t ->
  data:Michelson_v1_parser.parsed ->
  ty:Michelson_v1_parser.parsed ->
  'a ->
  'a #Proto_alpha.Alpha_environment.RPC_context.simple ->
  Gas.t tzresult Lwt.t

val typecheck_program :
  ?gas:Z.t ->
  Michelson_v1_parser.parsed ->
  Block_services.block ->
  #Proto_alpha.rpc_context ->
  (Script_tc_errors.type_map * Gas.t) tzresult Lwt.t

val print_typecheck_result :
  emacs:bool ->
  show_types:bool ->
  print_source_on_error:bool ->
  Michelson_v1_parser.parsed ->
  (Script_tc_errors.type_map * Gas.t) tzresult ->
  #Client_context.printer ->
  unit tzresult Lwt.t
