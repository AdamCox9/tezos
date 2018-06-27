(**************************************************************************)
(*                                                                        *)
(*    Copyright (c) 2014 - 2018.                                          *)
(*    Dynamic Ledger Solutions, Inc. <contact@tezos.com>                  *)
(*                                                                        *)
(*    All rights reserved. No warranty, explicit or implicit, provided.   *)
(*                                                                        *)
(**************************************************************************)

let unique_switch =
  Clic.switch
    ~long:"unique"
    ~short:'u'
    ~doc:"Fail when there is more than one possible completion."
    ()

let commands () = Clic.[
    command
      ~desc: "Autocomplete a prefix of Base58Check-encoded hash.\n\
              This actually works only for blocks, operations, public \
              key and contract identifiers."
      (args1 unique_switch)
      (prefixes [ "complete" ] @@
       string
         ~name: "prefix"
         ~desc: "the prefix of the hash to complete" @@
       stop)
      (fun unique prefix (cctxt : #Client_context.full) ->
         Shell_services.Blocks.Helpers.complete
           cctxt ~block:cctxt#block prefix >>=? fun completions ->
         match completions with
         | [] -> Pervasives.exit 3
         | _ :: _ :: _ when unique -> Pervasives.exit 3
         | completions ->
             List.iter print_endline completions ;
             return_unit) ;
    command
      ~desc: "Wait for the node to be bootstrapped."
      no_options
      (prefixes [ "bootstrapped" ] @@
       stop)
      (fun () (cctxt : #Client_context.full) ->
         Monitor_services.bootstrapped cctxt >>=? fun (stream, _) ->
         Lwt_stream.iter_s
           (fun (hash, time) ->
              cctxt#message "Current head: %a (timestamp: %a, validation: %a)"
                Block_hash.pp_short hash
                Time.pp_hum time
                Time.pp_hum (Time.now ())) stream >>= fun () ->
         cctxt#answer "Bootstrapped." >>= fun () ->
         return_unit
      )
  ]
