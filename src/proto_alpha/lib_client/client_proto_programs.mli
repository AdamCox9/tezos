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
  #Proto_alpha.rpc_context ->
  ?chain:Shell_services.chain ->
  Shell_services.block ->
  ?amount:Tez.t ->
  program:Michelson_v1_parser.parsed ->
  storage:Michelson_v1_parser.parsed ->
  input:Michelson_v1_parser.parsed ->
  unit ->
  (Script.expr *
   packed_internal_operation list *
   Contract.big_map_diff option) tzresult Lwt.t

val trace :
  #Proto_alpha.rpc_context ->
  ?chain:Shell_services.chain ->
  Shell_services.block ->
  ?amount:Tez.t ->
  program:Michelson_v1_parser.parsed ->
  storage:Michelson_v1_parser.parsed ->
  input:Michelson_v1_parser.parsed ->
  unit ->
  (Script.expr *
   packed_internal_operation list *
   Script_interpreter.execution_trace *
   Contract.big_map_diff option) tzresult Lwt.t

val print_run_result :
  #Client_context.printer ->
  show_source:bool ->
  parsed:Michelson_v1_parser.parsed ->
  (Script_repr.expr *
   packed_internal_operation list *
   Contract.big_map_diff option) tzresult -> unit tzresult Lwt.t

val print_trace_result :
  #Client_context.printer ->
  show_source:bool ->
  parsed:Michelson_v1_parser.parsed ->
  (Script_repr.expr *
   packed_internal_operation list *
   Script_interpreter.execution_trace *
   Contract.big_map_diff option)
    tzresult -> unit tzresult Lwt.t

val typecheck_data :
  #Proto_alpha.rpc_context ->
  ?chain:Shell_services.chain ->
  Shell_services.block ->
  ?gas:Z.t ->
  data:Michelson_v1_parser.parsed ->
  ty:Michelson_v1_parser.parsed ->
  unit ->
  Gas.t tzresult Lwt.t

val typecheck_program :
  #Proto_alpha.rpc_context ->
  ?chain:Shell_services.chain ->
  Shell_services.block ->
  ?gas:Z.t ->
  Michelson_v1_parser.parsed ->
  (Script_tc_errors.type_map * Gas.t) tzresult Lwt.t

val print_typecheck_result :
  emacs:bool ->
  show_types:bool ->
  print_source_on_error:bool ->
  Michelson_v1_parser.parsed ->
  (Script_tc_errors.type_map * Gas.t) tzresult ->
  #Client_context.printer ->
  unit tzresult Lwt.t
