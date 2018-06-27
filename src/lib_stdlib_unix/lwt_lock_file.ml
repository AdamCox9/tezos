(**************************************************************************)
(*                                                                        *)
(*    Copyright (c) 2014 - 2018.                                          *)
(*    Dynamic Ledger Solutions, Inc. <contact@tezos.com>                  *)
(*                                                                        *)
(*    All rights reserved. No warranty, explicit or implicit, provided.   *)
(*                                                                        *)
(**************************************************************************)

open Error_monad

let create_inner
    lock_command
    ?(close_on_exec=true)
    ?(unlink_on_exit=false) fn =
  protect begin fun () ->
    Lwt_unix.openfile fn Unix.[O_CREAT ; O_WRONLY; O_TRUNC] 0o644 >>= fun fd ->
    if close_on_exec then Lwt_unix.set_close_on_exec fd ;
    Lwt_unix.lockf fd lock_command 0 >>= fun () ->
    if unlink_on_exit then
      Lwt_main.at_exit (fun () -> Lwt_unix.unlink fn) ;
    let pid_str = string_of_int @@ Unix.getpid () in
    Lwt_unix.write_string fd pid_str 0 (String.length pid_str) >>= fun _ ->
    return_unit
  end

let create = create_inner Unix.F_TLOCK

let blocking_create
    ?timeout
    ?(close_on_exec=true)
    ?(unlink_on_exit=false) fn =
  let create () =
    create_inner Unix.F_LOCK ~close_on_exec ~unlink_on_exit fn in
  match timeout with
  | None -> create ()
  | Some duration -> with_timeout (Lwt_unix.sleep duration) (fun _ -> create ())

let is_locked fn =
  if not @@ Sys.file_exists fn then return_false else
    protect begin fun () ->
      Lwt_unix.openfile fn [Unix.O_RDONLY] 0o644 >>= fun fd ->
      Lwt.finalize (fun () ->
          Lwt.try_bind
            (fun () -> Lwt_unix.(lockf fd F_TEST 0))
            (fun () -> return_false)
            (fun _ -> return_true))
        (fun () -> Lwt_unix.close fd)
    end

let get_pid fn =
  let open Lwt_io in
  protect begin fun () ->
    with_file ~mode:Input fn begin fun ic ->
      read ic >>= fun content ->
      return (int_of_string content)
    end
  end
