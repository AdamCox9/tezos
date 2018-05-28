(**************************************************************************)
(*                                                                        *)
(*    Copyright (c) 2014 - 2018.                                          *)
(*    Dynamic Ledger Solutions, Inc. <contact@tezos.com>                  *)
(*                                                                        *)
(*    All rights reserved. No warranty, explicit or implicit, provided.   *)
(*                                                                        *)
(**************************************************************************)

open Client_keys
open Signer_messages

let sign ?watermark path pkh msg =
  let msg =
    match watermark with
    | None -> msg
    | Some watermark ->
        MBytes.concat "" [ Signature.bytes_of_watermark watermark ; msg ] in
  let req = { Sign.Request.pkh ; data = msg } in
  Lwt_utils_unix.Socket.connect path >>=? fun conn ->
  Lwt_utils_unix.Socket.send
    conn Request.encoding (Request.Sign req) >>=? fun () ->
  let encoding = result_encoding Sign.Response.encoding in
  Lwt_utils_unix.Socket.recv conn encoding >>=? fun res ->
  Lwt_unix.close conn >>= fun () ->
  Lwt.return res

let public_key path pkh =
  Lwt_utils_unix.Socket.connect path >>=? fun conn ->
  Lwt_utils_unix.Socket.send
    conn Request.encoding (Request.Public_key pkh) >>=? fun () ->
  let encoding = result_encoding Public_key.Response.encoding in
  Lwt_utils_unix.Socket.recv conn encoding >>=? fun res ->
  Lwt_unix.close conn >>= fun () ->
  Lwt.return res

module Unix = struct

  let scheme = "unix"

  let title = "..."

  let description = "..."

  let parse uri =
    match Uri.get_query_param uri "key" with
    | None -> invalid_arg "... FIXME ... B"
    | Some key ->
        Lwt.return (Signature.Public_key_hash.of_b58check key) >>=? fun key ->
        return (Lwt_utils_unix.Socket.Unix (Uri.path uri), key)

  let public_key uri =
    parse (uri : pk_uri :> Uri.t) >>=? fun (path, pkh) ->
    public_key path pkh

  let neuterize uri =
    return (Client_keys.make_pk_uri (uri : sk_uri :> Uri.t))

  let public_key_hash uri =
    public_key uri >>=? fun pk ->
    return (Signature.Public_key.hash pk)

  let sign ?watermark uri msg =
    parse (uri : sk_uri :> Uri.t) >>=? fun (path, pkh) ->
    sign ?watermark path pkh msg

end

module Tcp = struct

  let scheme = "tcp"

  let title = "..."

  let description = "..."

  (* let init _cctxt = return () *)

  let parse uri =
    match Uri.get_query_param uri "key" with
    | None -> invalid_arg "... FIXME ... C"
    | Some key ->
        Lwt.return (Signature.Public_key_hash.of_b58check key) >>=? fun key ->
        match Uri.host uri, Uri.port uri with
        | None, _ | _, None ->
            invalid_arg "... FIXME ... C2"
        | Some path, Some port ->
            return (Lwt_utils_unix.Socket.Tcp (path, port), key)

  let public_key uri =
    parse (uri : pk_uri :> Uri.t) >>=? fun (path, pkh) ->
    public_key path pkh

  let neuterize uri =
    return (Client_keys.make_pk_uri (uri : sk_uri :> Uri.t))

  let public_key_hash uri =
    public_key uri >>=? fun pk ->
    return (Signature.Public_key.hash pk)

  let sign ?watermark uri msg =
    parse (uri : sk_uri :> Uri.t) >>=? fun (path, pkh) ->
    sign ?watermark path pkh msg

end
