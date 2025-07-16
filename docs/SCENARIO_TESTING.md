# Simulation Scenarios

Testing specific market scenarios can help validate your trading simulator under realistic conditions.

## Implementing Scenario Tests

```ocaml
(* test/test_scenarios.ml *)

open Reactive_trading_sim.Types
open Reactive_trading_sim.Order_book
open Reactive_trading_sim.Agents
open Reactive_trading_sim.Simulation
open Alcotest

(** Test a flash crash scenario *)
let test_flash_crash_scenario () =
  (* Set up a normal market *)
  let normal_bids = List.init 10 (fun i ->
    { id = i; price = 100.0 -. (float_of_int i *. 0.1); qty = 10; 
      side = Buy; timestamp = Unix.gettimeofday () }
  ) in
  
  let normal_asks = List.init 10 (fun i ->
    { id = 10 + i; price = 100.0 +. (float_of_int i *. 0.1); qty = 10; 
      side = Sell; timestamp = Unix.gettimeofday () }
  ) in
  
  let initial_book = {
    bids = normal_bids;
    asks = normal_asks;
    last_id = 20;
  } in
  
  (* Create a simulation with the normal market *)
  let initial_state = {
    order_book = initial_book;
    trades = [];
    agents = [create_agent MarketMaker; create_agent RandomTrader];
    tick = 0;
  } in
  
  (* Save the initial mid price *)
  let initial_mid = match mid_price initial_book with
    | Some m -> m
    | None -> 100.0  (* Default if no mid *)
  in
  
  (* Now simulate a flash crash with a bunch of aggressive sell orders *)
  let crash_orders = List.init 20 (fun i ->
    { id = 0; price = 95.0 -. (float_of_int i *. 1.0); qty = 50; 
      side = Sell; timestamp = Unix.gettimeofday () }
  ) in
  
  (* Insert all crash orders *)
  let crash_state = List.fold_left (fun state order ->
    let (updated_book, _) = insert_order state.order_book order in
    { state with order_book = updated_book }
  ) initial_state crash_orders in
  
  (* Check the mid price has crashed *)
  let crashed_mid = match mid_price crash_state.order_book with
    | Some m -> m
    | None -> 0.0  (* Should not happen but needed for type safety *)
  in
  
  (* Verify the crash happened *)
  check bool "Price crashed significantly" true 
    (crashed_mid < initial_mid *. 0.9);
  
  (* Now run simulation steps and see if market maker helps recovery *)
  let recovery_state = ref crash_state in
  for _ = 1 to 20 do
    recovery_state := simulation_step !recovery_state
  done;
  
  (* Check if price has somewhat recovered *)
  let recovered_mid = match mid_price !recovery_state.order_book with
    | Some m -> m
    | None -> 0.0
  in
  
  check bool "Price has partially recovered" true 
    (recovered_mid > crashed_mid *. 1.05)

(** Test a momentum scenario where prices trend up *)
let test_momentum_scenario () =
  (* Start with a balanced market *)
  let initial_book = empty_order_book in
  
  (* Create initial state *)
  let initial_state = {
    order_book = initial_book;
    trades = [];
    agents = [create_agent MarketMaker; create_agent ArbitrageBot];
    tick = 0;
  } in
  
  (* Add a series of increasingly higher bids to simulate buying pressure *)
  let buy_pressure = List.init 10 (fun i ->
    { id = 0; price = 100.0 +. (float_of_int i *. 0.2); qty = 20; 
      side = Buy; timestamp = Unix.gettimeofday () }
  ) in
  
  (* Apply buying pressure *)
  let pressure_state = List.fold_left (fun state order ->
    let (new_book, _) = match_orders state.order_book order in
    { state with order_book = new_book }
  ) initial_state buy_pressure in
  
  (* Run simulation and see if trend continues *)
  let final_state = ref pressure_state in
  for _ = 1 to 10 do
    final_state := simulation_step !final_state
  done;
  
  (* Check if the best bid has continued to rise *)
  let final_best_bid = match best_bid !final_state.order_book with
    | Some b -> b
    | None -> 0.0  (* Should not happen but needed for type safety *)
  in
  
  let initial_best_bid = match best_bid pressure_state.order_book with
    | Some b -> b
    | None -> 0.0
  in
  
  check bool "Price momentum continued" true 
    (final_best_bid >= initial_best_bid)

(** Run all scenario tests *)
let () =
  Alcotest.run "Market Scenarios" [
    "scenarios", [
      test_case "Flash crash and recovery" `Quick test_flash_crash_scenario;
      test_case "Price momentum" `Quick test_momentum_scenario;
    ];
  ]
```

## Update dune file

```dune
(tests
 (names test_order_book test_agents test_integration test_stress test_scenarios)
 (modules test_order_book test_agents test_integration test_stress test_scenarios)
 (flags (:standard -w -33))
 (libraries reactive_trading_sim qcheck qcheck-core qcheck-alcotest alcotest))
```

## Run scenario tests

```bash
dune test test/test_scenarios.ml
```

These scenario tests help verify that your simulator can handle realistic market conditions like flash crashes and trending markets.
