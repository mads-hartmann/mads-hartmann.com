### What is eio

Eio is an effects-based I/O library for Multicore OCaml. It provides concurrency primitives (fibers, switches, streams) and I/O operations (files, network, time) using direct-style code. It's the modern replacement for Lwt/Async—same capabilities, cleaner syntax, built on effects and domains.

### What are the core primitives in eio?

- **Fibers** — lightweight tasks within a domain (like goroutines)
- **Switches** — manage fiber lifetimes, ensure cleanup on errors
- **Promises** — one-shot values for communication between fibers
- **Streams** — bounded queues for producer/consumer patterns
- **Resources** — files, sockets, timers accessed via capability-passing

Capability-passing means you receive permissions as arguments rather than calling globals:

```ocamls
(* Unix style - grabs global *)
let read_file () =
  Unix.openfile "/etc/passwd" [O_RDONLY] 0

(* Eio style - receives capability *)
let read_file ~fs =
  Eio.Path.open_in (fs / "/etc/passwd")
```

Benefits: testability (mock filesystems), security (functions only access what they're given), explicit dependencies (signature shows required resources). Eio's entry point provides root capabilities, you pass them down.
