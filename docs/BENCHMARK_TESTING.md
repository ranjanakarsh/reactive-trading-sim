# My Benchmark Testing Notes

As I developed my reactive trading simulation, I discovered that measuring performance is critical for a trading system. After reading through some OCaml performance optimization guides, I learned how to use benchmarking to identify bottlenecks in my code.

## Setting Up Benchmark Tests

I decided to use the `core_bench` library for my benchmarks after researching different options. It has great visualization tools and gives detailed statistics:

```bash
# Install core_bench
opam install core_bench
```

## Creating My Order Book Benchmarks

I created benchmarks for the most performance-critical components of my trading system. The order book operations need to be fast since they're executed thousands of times per second in a real trading environment.

```ocaml
(* bench/bench_order_book.ml *)

open Core
open Core_bench
open Reactive_trading_sim.Types
open Reactive_trading_sim.Order_book

(* This function helps me generate a dataset for consistent benchmark runs.
   I've learned that having varying datasets can lead to inconsistent benchmark results. *)
let generate_random_orders count =
  let orders = ref [] in
  for i = 1 to count do
    (* I alternate buy/sell orders to create a realistic market *)
    let side = if i mod 2 = 0 then Buy else Sell in
    (* Prices clustered around 100 with some randomness *)
    let price = 100.0 +. (Random.float 10.0) -. 5.0 in
    (* Random quantities between 1-100 - based on typical market sizes I've observed *)
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

(* This benchmark measures order insertion performance.
   I had a hunch that insertion might be slow due to sorting. *)
let bench_insert_order () =
  let orders = generate_random_orders 1000 in
  
  Bench.Test.create ~name:"Insert 1000 orders" (fun () ->
    ignore (List.fold_left 
      (fun book order -> fst (insert_order book order))
      empty_order_book
      orders)
  )

(* The matching logic is the heart of the trading engine.
   I need to ensure it's fast enough for high-frequency scenarios. *)
let bench_match_orders () =
  (* Create a realistic order book with price ladder *)
  let buy_orders = 
    List.init 100 (fun i -> 
      { id = i; price = 99.0 -. (float_of_int i *. 0.01); 
        qty = 10; side = Buy; timestamp = Unix.gettimeofday () })
  in
  
  let sell_orders = 
    List.init 100 (fun i -> 
      { id = 100 + i; price = 101.0 +. (float_of_int i *. 0.01); 
        qty = 10; side = Sell; timestamp = Unix.gettimeofday () })
  in
  
  let book = {
    bids = List.sort compare_bids buy_orders;
    asks = List.sort compare_asks sell_orders;
    last_id = 200;
  } in
  
  (* Testing with an aggressive order that will match multiple levels
     This simulates a common market scenario I want to optimize for *)
  let matching_order = {
    id = 0;
    price = 101.0;
    qty = 50;
    side = Buy;
    timestamp = Unix.gettimeofday ();
  } in
  
  Bench.Test.create ~name:"Match order against book" (fun () ->
    ignore (match_orders book matching_order)
  )

(* I also needed to test common query operations that are called frequently
   during the simulation. Each microsecond counts in a busy market! *)
let bench_book_operations () =
  (* Setting up a medium-sized book that resembles a typical market state
     I looked at real market depth to calibrate these test values *)
  let buy_orders = 
    List.init 50 (fun i -> 
      { id = i; price = 99.0 -. (float_of_int i *. 0.01); 
        qty = 10; side = Buy; timestamp = Unix.gettimeofday () })
  in
  
  let sell_orders = 
    List.init 50 (fun i -> 
      { id = 50 + i; price = 101.0 +. (float_of_int i *. 0.01); 
        qty = 10; side = Sell; timestamp = Unix.gettimeofday () })
  in
  
  let book = {
    bids = List.sort compare_bids buy_orders;
    asks = List.sort compare_asks sell_orders;
    last_id = 100;
  } in
  
  (* Group multiple related benchmarks - I learned this technique from 
     reading the Core_bench documentation and examples *)
  Bench.Test.create_group ~name:"Order book operations" [
    Bench.Test.create ~name:"best_bid" (fun () ->
      ignore (best_bid book)
    );
    
    Bench.Test.create ~name:"best_ask" (fun () ->
      ignore (best_ask book)
    );
    
    (* Mid price is used constantly by my trading agents,
       so its performance is particularly important *)
    Bench.Test.create ~name:"mid_price" (fun () ->
      ignore (mid_price book)
    );
    
    (* Checking for crossed markets helps detect arbitrage opportunities *)
    Bench.Test.create ~name:"is_crossed" (fun () ->
      ignore (is_crossed book)
    );
  ]

(* Main function to run all benchmarks.
   I was amazed by how easy Core_bench makes it to get useful metrics! *)
let () =
  Command_unix.run (Bench.make_command [
    bench_insert_order ();
    bench_match_orders ();
    bench_book_operations ();
  ])
```

## Setting Up My Benchmark Structure

I created a dedicated directory structure for my benchmarks:

```bash
# Create a benchmark directory
mkdir -p bench
```

Then I added a dune file to build my benchmarks:

```dune
(executable
 (name bench_order_book)
 (modules bench_order_book)
 (libraries reactive_trading_sim core core_bench))
```

## Running My Benchmarks

I can run the benchmarks with a simple dune command:

```bash
dune exec bench/bench_order_book.exe
```

When I run this, I get detailed performance metrics that help me identify potential bottlenecks in my code. The first time I ran these benchmarks, I was surprised by some of the results!

## Understanding My Benchmark Results

Here's what I look for in the benchmark outputs:

- **Throughput**: I need to achieve at least 10,000 operations per second for my order insertion code since my simulation needs to handle high-frequency trading scenarios.

- **Latency**: I'm aiming for sub-microsecond latency for simple operations like `best_bid` and `best_ask`, which are called frequently.

- **Allocated**: I monitor memory usage carefully - excessive allocations can lead to GC pauses which are unacceptable in a trading system.

## Optimizations I've Made Based on Benchmarks

After running these benchmarks, I discovered several opportunities for optimization:

1. The order matching algorithm was taking longer than expected due to unnecessary list traversals.

2. The `mid_price` function was being called redundantly in several code paths.

3. List sorting during order insertion was a significant bottleneck - I'm considering alternative data structures.

I'll continue to refine these benchmarks as I develop more features for my trading simulation. Maintaining good performance is critical for realistic market behavior.

## Next Steps for My Benchmarking

I plan to extend my benchmarks to include:

- Full simulation tick performance under different market conditions
- Agent strategy computation benchmarks
- Memory usage profiles during long simulation runs
- Comparative benchmarks between different data structure implementations

Benchmarking has become an essential part of my development workflow, helping me make informed decisions about code optimizations.
