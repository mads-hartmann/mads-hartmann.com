# Multicore Ocaml

I'm coming back to writing OCaml after having not written it for about 10 years. Since then, OCaml has added multicore support. I'm trying to learn what that's all about.

This is a series of question/answers that I've bene working through trying to understand it.

## Why wasn't OCaml multi-core ready before

OCaml's garbage collector wasn't thread-safe. It used a global runtime lock, so only one thread could execute OCaml code at a time, even on multi-core systems.

## How were multiple cores utilized before

You used multiprocessing instead. Separate OS processes communicated via pipes, sockets, or shared memory.

Libraries like Lwt and Async provided *concurrency* (not parallelism) on a single core. They're useful for I/O-bound workloads: while waiting for network/disk, other tasks can run. You avoid the overhead of thousands of OS threads, and the runtime lock isn't a bottleneck since you're mostly waiting on I/O anyway.

For CPU-bound parallelism, multiple processes was the only option

### How does Lwt and Async achieve this?

TODO

### What's the main differences between Lwt and Async?

TODO

## What new primitives, if any, were introduced to OCaml to support multicore support

Two main additions:

1. **Domains** — units of parallelism (OS threads with their own heap and runtime state). `Domain.spawn` creates one.

2. **Effects** — a mechanism for cooperative concurrency within a domain. Lets you suspend/resume computations without callbacks. Used to build schedulers, async I/O, etc.

## Domains

### What are domains and how do they differ from threads?

Domains are OCaml's unit of parallelism. Each domain has its own minor heap and runs on its own OS thread. Unlike traditional threads that share a heap and require synchronization for every allocation, domains can allocate independently without contention. You typically create one domain per CPU core, not thousands like lightweight threads.

### What is the relationship between domains and OS threads?

One-to-one. Each domain is backed by exactly one OS thread for its lifetime. The domain owns that thread - you can't detach or reassign it. This keeps the model simple and predictable: domain count ≈ core count.

### How does OCaml's multicore model differ from other languages' approaches (e.g., Go, Node)?

- **Go**: M:N threading—many goroutines multiplexed onto fewer OS threads by a runtime scheduler. Lightweight, thousands of goroutines are normal.
- **Node**: Single-threaded event loop with worker threads for CPU-bound tasks. Concurrency via async/await.
- **OCaml**: 1:1 domains (few, heavy) + effects for lightweight concurrency within each domain. Parallelism from domains, concurrency from effects. Closer to "bring your own scheduler" than Go's built-in one.

### How do I use Domains?

TODO

## Effects

### What are effects and why should I use them?

Effects let you suspend a computation, do something else, then resume it - without callbacks or monads. Useful for async I/O, generators, exceptions, and building custom schedulers. You define an effect, perform it, and a handler decides what happens. Think of them as resumable exceptions.

### How do I write code using effects?

```ocaml
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
```

Output: `before`, `yielded!`, `after`. The handler intercepts `Yield`, does something, then resumes with `continue`.

If no handler catches an effect, OCaml raises `Effect.Unhandled` at runtime—the program crashes. Since effects aren't tracked in types, the compiler can't warn you. This is a deliberate trade-off: simpler types, but no static guarantees. Some languages (Koka, Eff) track effects in types, but OCaml opted for pragmatism.

### What does effects relate to Lwt and Async?

Effects can replace them. Lwt/Async use monads (`>>=`, `let*`) to chain async operations - your code must be written in a specific style. Effects let you write direct-style code (normal function calls) that can still suspend and resume. Libraries like `eio` use effects under the hood to provide Lwt-like functionality without the monadic syntax.

### How are OCaml's effect compared to Monad Transformers and Tagless Final?

TODO