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

val mem:
  #Client_context.wallet ->
  Block_hash.t -> bool tzresult Lwt.t
val find:
  #Client_context.wallet ->
  Block_hash.t -> Nonce.t option tzresult Lwt.t
val add:
  #Client_context.wallet ->
  Block_hash.t -> Nonce.t -> unit tzresult Lwt.t
val del:
  #Client_context.wallet ->
  Block_hash.t -> unit tzresult Lwt.t
val dels:
  #Client_context.wallet ->
  Block_hash.t list -> unit tzresult Lwt.t
