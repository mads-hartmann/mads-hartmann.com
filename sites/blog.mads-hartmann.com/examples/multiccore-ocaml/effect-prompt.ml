(* Prompt effect example: Read and Write operations *)

(* 1. Declare the effects *)
type _ Effect.t +=
  Read : string Effect.t
 | Write : string -> unit Effect.t

(* 2. A task that uses the Prompt effects *)
let my_task () =
  Effect.perform (Write "What is your name? ");
  let name = Effect.perform Read in
  Effect.perform (Write ("Hello, " ^ name ^ "!\n"))

(* 3. Effect handler for stdin/stdout *)
let handler : unit Effect.Deep.effect_handler = {
  effc = fun (type a) (eff : a Effect.t) : ((a, _) Effect.Deep.continuation -> _) option ->
    match eff with
    | Read -> Some (fun k ->
        let line = input_line stdin in
        Effect.Deep.continue k line)
    | Write msg -> Some (fun k ->
        print_string msg;
        flush stdout;
        Effect.Deep.continue k ())
    | _ -> None
}

(* 4. Test handler: uses a list of inputs and collects outputs *)
let test_handler (inputs : string list) : unit Effect.Deep.effect_handler * (unit -> string list) =
  let inputs = ref inputs in
  let outputs = ref [] in
  let handler : unit Effect.Deep.effect_handler = {
    effc = fun (type a) (eff : a Effect.t) : ((a, _) Effect.Deep.continuation -> _) option ->
      match eff with
      | Read -> Some (fun k ->
          match !inputs with
          | [] -> failwith "No more test inputs"
          | x :: xs ->
              inputs := xs;
              Effect.Deep.continue k x)
      | Write msg -> Some (fun k ->
          outputs := msg :: !outputs;
          Effect.Deep.continue k ())
      | _ -> None
  } in
  (handler, fun () -> List.rev !outputs)

(* 5. Run with real I/O *)
let () = Effect.Deep.try_with my_task () handler

(* 6. Run with test handler and verify output *)
let () =
  let test_h, get_outputs = test_handler ["Alice"] in
  Effect.Deep.try_with my_task () test_h;
  let outputs = get_outputs () in
  assert (outputs = ["What is your name? "; "Hello, Alice!\n"]);
  print_endline "Test passed!"
