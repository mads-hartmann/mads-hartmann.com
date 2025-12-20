(* 1. Declare an effect *)
(* Effect.t is extensible (declared with `type t = ..`), += adds a new constructor.
   This lets different modules define their own effects without a central definition. *)
type _ Effect.t += Yield : unit Effect.t

(* Type is unit -> unit. Plain function—no monads, no special return type.
   The effect happens "invisibly" at runtime. OCaml's type system doesn't track
   which effects a function might perform. *)
let my_task () =
  print_endline "before";
  Effect.perform Yield;
  print_endline "after"

(* Handle the effect *)
let () = Effect.Deep.try_with my_task ()
  { effc = fun (type a) (eff : a Effect.t) ->
      match eff with
      | Yield -> Some (fun k ->
          print_endline "yielded!";
          Effect.Deep.continue k ())
      | _ -> None }