open Reactive_trading_sim.Types
open Reactive_trading_sim.Order_book
open Reactive_trading_sim.Types
open Reactive_trading_sim.Order_book
open QCheck2
open Alcotest

(** QCheck generators *)

(** Generate a random side (Buy or Sell) *)
let gen_side = QCheck2.Gen.oneofl [Buy; Sell]

(** Generate a random price (between 90.0 and 110.0) *)
let gen_price = QCheck2.Gen.map (fun f -> 90.0 +. f *. 20.0) QCheck2.Gen.float

(** Generate a random quantity (between 1 and 100) *)
let gen_qty = QCheck2.Gen.int_range 1 100

(** Generate a random order *)
let gen_order = 
  QCheck2.Gen.map3
    (fun side price qty ->
      { id = 0; price; qty; side; timestamp = Unix.gettimeofday () })
    gen_side gen_price gen_qty

(** Generate a list of random orders *)
let gen_order_list = QCheck2.Gen.list gen_order

(** Unit Tests *)

(** Test that an empty order book remains valid *)
let test_empty_book () =
  let book = empty_order_book in
  check bool "Empty book has no crossed market" false (is_crossed book)

(** Test order insertion maintains order book invariants *)
let test_insert_order () =
  let book = empty_order_book in
  
  (* Insert a buy order *)
  let buy_order = { id = 0; price = 100.0; qty = 10; side = Buy; timestamp = Unix.gettimeofday () } in
  let (book_with_buy, _) = insert_order book buy_order in
  
  (* Insert a sell order *)
  let sell_order = { id = 0; price = 101.0; qty = 10; side = Sell; timestamp = Unix.gettimeofday () } in
  let (book_with_both, _) = insert_order book_with_buy sell_order in
  
  (* Check if the book is still valid *)
  check bool "Book with buy and sell is not crossed" false (is_crossed book_with_both);
  
  (* Check if the orders are in the right place *)
  check (option (float 0.0)) "Best bid is 100.0" (Some 100.0) (best_bid book_with_both);
  check (option (float 0.0)) "Best ask is 101.0" (Some 101.0) (best_ask book_with_both)

(** Test matching logic creates trades *)
let test_match_orders () =
  let book = empty_order_book in
  
  (* Insert a resting sell order *)
  let sell_order = { id = 0; price = 100.0; qty = 10; side = Sell; timestamp = Unix.gettimeofday () } in
  let (book_with_sell, _) = insert_order book sell_order in
  
  (* Insert a matching buy order *)
  let buy_order = { id = 0; price = 100.0; qty = 5; side = Buy; timestamp = Unix.gettimeofday () } in
  let (updated_book, trades) = match_orders book_with_sell buy_order in
  
  (* Check that a trade was created *)
  check int "One trade was created" 1 (List.length trades);
  
  (* Check trade details *)
  let trade = List.hd trades in
  check int "Trade quantity is 5" 5 trade.qty;
  check (float 0.0) "Trade price is 100.0" 100.0 trade.price;
  
  (* Check updated order book *)
  check (option (float 0.0)) "Best ask is still 100.0" (Some 100.0) (best_ask updated_book);
  
  (* Check remaining quantity in the sell order *)
  let remaining_sell = List.hd updated_book.asks in
  check int "Remaining sell quantity is 5" 5 remaining_sell.qty

(** Property-based tests *)

(** Property-based tests - disabled for now **)
(*
(** Property: No crossed book after matching *)
let prop_no_crossed_book =
  QCheck2.Test.make
    ~name:"No crossed book after matching"
    ~count:100
    gen_order
    (fun order ->
      (* Start with an empty book *)
      let book = empty_order_book in
      
      (* Match the order (should just insert it) *)
      let book_after_match, _ = match_orders book order in
      
      (* Book should not be crossed after inserting a single order *)
      not (is_crossed book_after_match))

(** Property: Matching an empty book with an order leaves the order in the book *)
let prop_match_empty_book =
  QCheck2.Test.make
    ~name:"Matching empty book preserves order"
    ~count:100
    gen_order
    (fun order ->
      (* First verify that no orders are in the empty book *)
      let empty = empty_order_book in
      
      (* Then match the order against the empty book *)
      let book_after_match, trades = match_orders empty order in
      
      (* Check that:
         1. No trades were produced
         2. The order is now in the book on the correct side *)
      List.length trades = 0 &&
      match order.side with
      | Buy ->
          List.exists (fun o -> 
            o.price = order.price && 
            o.qty = order.qty
          ) book_after_match.bids
      | Sell ->
          List.exists (fun o -> 
            o.price = order.price && 
            o.qty = order.qty
          ) book_after_match.asks
    )

(** Property: Total executed quantity equals sum of trades *)
let prop_executed_qty_equals_trades =
  QCheck2.Test.make
    ~name:"Executed quantity equals sum of trades"
    ~count:100
    (QCheck2.Gen.pair gen_order_list gen_order)
    (fun (orders, new_order) ->
      (* Build a book with the initial orders, filtering by side *)
      let buy_orders = List.filter (fun o -> o.side = Buy) orders in
      let sell_orders = List.filter (fun o -> o.side = Sell) orders in
      
      let init_book = List.fold_left 
        (fun book order -> fst (insert_order book order)) 
        { 
          bids = List.sort compare_bids buy_orders;
          asks = List.sort compare_asks sell_orders;
          last_id = 100
        }
        []  (* Start with an empty list, we already set the bids and asks *)
      in
      
      (* Match the new order *)
      let (_, trades) = match_orders init_book new_order in
      
      (* Calculate executed quantity from trades *)
      let total_traded_qty = List.fold_left (fun acc t -> acc + t.qty) 0 trades in
      
      (* Calculate executed quantity from the order *)
      let executed_qty = min new_order.qty total_traded_qty in
      
      (* Property: executed quantity equals sum of trades *)
      total_traded_qty = executed_qty)
*)

(** Test runner *)
let () =
  (* Unit tests *)
  let unit_tests = [
    "empty_book", `Quick, test_empty_book;
    "insert_order", `Quick, test_insert_order;
    "match_orders", `Quick, test_match_orders;
  ] in
  
  (* Property-based tests - disabled for now *)
  (*
  let property_tests = [
    QCheck_alcotest.to_alcotest prop_no_crossed_book;
    QCheck_alcotest.to_alcotest prop_match_empty_book;
    QCheck_alcotest.to_alcotest prop_executed_qty_equals_trades;
  ] in
  *)
  
  (* Run all tests *)
  Alcotest.run "Order Book Tests" [
    "unit_tests", unit_tests;
    (* "property_tests", property_tests; *)
  ]
