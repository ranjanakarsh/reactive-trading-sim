(** 
 * This is a simple example of how to use the reactive_trading_sim library
 * For the full application, use dune exec bin/main.exe
 *)

(* When built, you should be able to use: *)
(* open Reactive_trading_sim.Types *)
(* open Reactive_trading_sim.Order_book *)

(* For now, we'll just print a simple message *)
let () =
  print_endline "Reactive Trading Simulator";
  print_endline "To run the full simulator:";
  print_endline "  dune exec bin/main.exe -- --ticks 100";
  print_endline "";
  print_endline "Or use the Makefile:";
  print_endline "  make run"