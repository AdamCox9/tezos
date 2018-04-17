(**************************************************************************)
(*                                                                        *)
(*    Copyright (c) 2014 - 2018.                                          *)
(*    Dynamic Ledger Solutions, Inc. <contact@tezos.com>                  *)
(*                                                                        *)
(*    All rights reserved. No warranty, explicit or implicit, provided.   *)
(*                                                                        *)
(**************************************************************************)

val run :
  (RPC_client.http_ctxt ->
   Client_config.cli_args ->
   Client_context.full Clic.command list tzresult Lwt.t) ->
  unit
