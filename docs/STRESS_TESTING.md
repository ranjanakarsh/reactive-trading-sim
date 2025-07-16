# Stress Testing

Stress testing helps identify performance bottlenecks and edge cases by pushing your system to its limits.

## High Volume Order Testing

```ocaml
(* test/test_stress.ml *)

open Reactive_trading_sim.Types
open Reactive_trading_sim.Order_book
open Alcotest
open Printf

(** Generate a large number of random orders *)
let generate_random_orders count =
  let orders = ref [] in
  for i = 1 to count do
    let side = if i mod 2 = 0 then Buy else Sell in
    let price = 100.0 +. (Random.float 10.0) -. 5.0 in
    let qty = Random.int 100 + 1 in
    orders := { 
      id = 0; 
      price; 
      qty; 
      side; 
      timestamp = Unix.gettimeofday ()
    } :: !orders
  done;
  !orders

(** Test inserting a large number of orders *)
let test_high_volume_inserts () =
  let order_count = 10000 in
  let orders = generate_random_orders order_count in
  
  (* Measure time to insert all orders *)
  let start_time = Unix.gettimeofday () in
  
  let final_book = List.fold_left 
    (fun book order -> fst (insert_order book order))
    empty_order_book
    orders
  in
  
  let end_time = Unix.gettimeofday () in
  let duration = end_time -. start_time in
  
  (* Print performance metrics *)
  printf "Inserted %d orders in %.4f seconds (%.1f orders/sec)\n" 
    order_count duration (float_of_int order_count /. duration);
  
  (* Verify the order book contains the expected number of orders *)
  let total_orders = List.length final_book.bids + List.length final_book.asks in
  check int "All orders were inserted" order_count total_orders

(** Test matching with a deep order book *)
let test_high_volume_matching () =
  let buy_orders = generate_random_orders 5000 |> 
    List.filter (fun o -> o.side = Buy) |>
    List.sort compare_bids in
  
  let sell_orders = generate_random_orders 5000 |> 
    List.filter (fun o -> o.side = Sell) |>
    List.sort compare_asks in
  
  (* Create a deep order book *)
  let book = {
    bids = buy_orders;
    asks = sell_orders;
    last_id = 10000;
  } in
  
  (* Create a new aggressive order that should match multiple times *)
  let aggressive_order = {
    id = 0;
    price = 105.0; (* High price that should match multiple sells *)
    qty = 1000;
    side = Buy;
    timestamp = Unix.gettimeofday ();
  } in
  
  (* Measure matching time *)
  let start_time = Unix.gettimeofday () in
  let (_, trades) = match_orders book aggressive_order in
  let end_time = Unix.gettimeofday () in
  let duration = end_time -. start_time in
  
  printf "Matched order against %d trades in %.4f seconds\n" 
    (List.length trades) duration;
  
  (* Verify some trades were created *)
  check bool "Trades were created" true (List.length trades > 0)

(** Run all stress tests *)
let () =
  Alcotest.run "Stress Tests" [
    "high_volume", [
      test_case "Insert many orders" `Slow test_high_volume_inserts;
      test_case "Match against deep book" `Slow test_high_volume_matching;
    ];
  ]
```

## Update dune file

```dune
(tests
 (names test_order_book test_agents test_integration test_stress)
 (modules test_order_book test_agents test_integration test_stress)
 (flags (:standard -w -33))
 (libraries reactive_trading_sim qcheck qcheck-core qcheck-alcotest alcotest))
```

## Run stress tests

```bash
dune test test/test_stress.ml
```

These tests will help identify performance bottlenecks in your order book implementation.
