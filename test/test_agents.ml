open Reactive_trading_sim.Types
open Reactive_trading_sim.Agents
open Alcotest

(** Test that market maker generates symmetric orders around mid price *)
let test_market_maker_strategy () =
  (* Create an order book with a specific spread *)
  let bid_order = { id = 1; price = 100.0; qty = 10; side = Buy; timestamp = Unix.gettimeofday () } in
  let ask_order = { id = 2; price = 101.0; qty = 10; side = Sell; timestamp = Unix.gettimeofday () } in
  let book = {
    bids = [bid_order]; 
    asks = [ask_order]; 
    last_id = 2 
  } in

  (* Create a market maker *)
  let agent = create_agent MarketMaker in
  
  (* Get orders *)
  let orders = market_maker_strategy book agent in
  
  (* Check that we get two orders (buy and sell) *)
  check int "Market maker generates two orders" 2 (List.length orders);
  
  (* Check that the orders are on opposite sides *)
  let sides = List.map (fun o -> o.side) orders in
  check bool "Market maker generates buy and sell orders" 
    true (List.mem Buy sides && List.mem Sell sides);
  
  (* Check that the orders are around the mid price *)
  let mid = (100.0 +. 101.0) /. 2.0 in
  let prices = List.map (fun (o : order) -> o.price) orders in
  let buy_price = List.find (fun p -> p < mid) prices in
  let sell_price = List.find (fun p -> p > mid) prices in
  
  check bool "Buy price is below mid" true (buy_price < mid);
  check bool "Sell price is above mid" true (sell_price > mid)

(** Test that arbitrage bot detects and exploits crossed markets *)
let test_arbitrage_strategy () =
  (* Create a normal (non-crossed) order book *)
  let normal_book = {
    bids = [{ id = 1; price = 100.0; qty = 10; side = Buy; timestamp = Unix.gettimeofday () }];
    asks = [{ id = 2; price = 101.0; qty = 10; side = Sell; timestamp = Unix.gettimeofday () }];
    last_id = 2;
  } in
  
  (* Create a crossed order book *)
  let crossed_book = {
    bids = [{ id = 1; price = 102.0; qty = 10; side = Buy; timestamp = Unix.gettimeofday () }];
    asks = [{ id = 2; price = 101.0; qty = 10; side = Sell; timestamp = Unix.gettimeofday () }];
    last_id = 2;
  } in
  
  (* Create an arbitrage bot *)
  let agent = create_agent ArbitrageBot in
  
  (* Test on normal book - should not generate orders *)
  let normal_orders = arbitrage_strategy normal_book agent in
  check int "No arbitrage on normal book" 0 (List.length normal_orders);
  
  (* Test on crossed book - should generate orders *)
  let crossed_orders = arbitrage_strategy crossed_book agent in
  check bool "Arbitrage on crossed book" true (List.length crossed_orders > 0)

(** Test that random trader generates valid orders *)
let test_random_trader_strategy () =
  (* Create an order book *)
  let book = {
    bids = [{ id = 1; price = 100.0; qty = 10; side = Buy; timestamp = Unix.gettimeofday () }];
    asks = [{ id = 2; price = 101.0; qty = 10; side = Sell; timestamp = Unix.gettimeofday () }];
    last_id = 2;
  } in
  
  (* Create a random trader *)
  let agent = create_agent RandomTrader in
  
  (* Generate orders *)
  let orders = random_trader_strategy book agent in
  
  (* Check that at least one order is generated *)
  check bool "Random trader generates at least one order" true (List.length orders > 0);
  
  (* Check that the order has valid fields *)
  let order = List.hd orders in
  check bool "Random trader order has valid quantity" true (order.qty > 0);
  check bool "Random trader order has valid side" true (order.side = Buy || order.side = Sell)

(** Test runner *)
let () =
  (* Run tests *)
  Alcotest.run "Agent Tests" [
    "strategies", [
      "market_maker_strategy", `Quick, test_market_maker_strategy;
      "arbitrage_strategy", `Quick, test_arbitrage_strategy;
      "random_trader_strategy", `Quick, test_random_trader_strategy;
    ];
  ]
