open Types

(* Helper to generate timestamps for orders.
   I separated this out to make testing easier (can mock this for deterministic tests).
   I've learned that pure functions are much easier to test! *)
let timestamp () = Unix.gettimeofday ()

(* Factory function to create orders with consistent defaults.
   I found myself creating orders in multiple places and wanted to reduce duplication.
   Initially I was setting IDs manually but realized the order book should handle that. *)
let create_order side price qty =
  {
    id = 0;  (* The order book will set the proper ID when inserted *)
    price;
    qty;
    side;
    timestamp = timestamp ();
  }

(* Initialize a new agent with default values.
   I start all agents with zero inventory and cash to keep things simple.
   This was inspired by how real trading simulations begin with flat positions. *)
let create_agent agent_type =
  {
    agent_type;
    inventory = 0;
    cash = 0.0;
    pnl = 0.0;
  }

(* Update an agent's state when their orders are matched.
   This was one of the trickier parts to implement correctly.
   I spent time studying how trading P&L is calculated in real systems. *)
let update_agent_state agent trades =
  (* We need to map trades back to the agents that placed the orders.
     In a real system we'd have direct references, but for this simulation
     I'm using a simple heuristic based on order IDs.
     
     This is definitely a hack, but it works for demonstration purposes!
     I'd improve this in a production system. *)
  let update_for_trade agent trade =
    (* Each agent type has a specific ID suffix pattern.
       I'm using the modulo of the ID to identify which agent placed the order.
       This approach works fine for a simple simulation but has limitations. *)
    let agent_id_suffix = 
      match agent.agent_type with
      | MarketMaker -> 1
      | ArbitrageBot -> 2
      | RandomTrader -> 3
    in
    
    (* Calculate the inventory and cash changes based on the trade.
       I had to be careful here - when you buy, inventory goes up but cash goes down.
       When you sell, inventory goes down but cash goes up.
       Getting the signs right took a few tries! *)
    let (qty_delta, cash_delta) =
      if trade.buy_id mod 10 = agent_id_suffix then
        (* Agent was the buyer - increase inventory, decrease cash *)
        (trade.qty, -.(trade.price *. float_of_int trade.qty))
      else if trade.sell_id mod 10 = agent_id_suffix then
        (* Agent was the seller - decrease inventory, increase cash *)
        (-trade.qty, trade.price *. float_of_int trade.qty)
      else
        (* Agent wasn't involved in this trade - no change *)
        (0, 0.0)
    in
    
    (* Update the agent state with the new values.
       I love how easy record updates are in OCaml! *)
    {
      agent with
      inventory = agent.inventory + qty_delta;
      cash = agent.cash +. cash_delta;
    }
  in
  
  (* Process all trades and accumulate the changes to the agent state.
     Fold is perfect for this kind of stateful accumulation - I'm getting
     better at using functional patterns effectively! *)
  List.fold_left update_for_trade agent trades

(* Market maker strategy: place orders on both sides of the book.
   I learned about market making from reading papers on market microstructure.
   These agents provide liquidity by maintaining a narrow spread around the mid price. *)
let market_maker_strategy order_book agent =
  let _ = agent in (* Just to silence the unused variable warning *)
  
  match mid_price order_book with
  | None -> 
      (* No market yet, so create an initial market with a default price.
         This bootstraps the market when the simulation starts.
         I picked 100.0 as a reasonable starting point that's easy to reason about. *)
      let initial_price = 100.0 in
      let spread = 0.1 in
      let qty = 10 in
      [
        create_order Buy (initial_price -. spread /. 2.0) qty;
        create_order Sell (initial_price +. spread /. 2.0) qty
      ]
  | Some mid ->
      (* Place orders around mid *)
      let spread = 0.1 in
      let qty = 10 in
      [
        create_order Buy (mid -. spread /. 2.0) qty;
        create_order Sell (mid +. spread /. 2.0) qty
      ]

(** Arbitrage bot strategy: look for crossed markets *)
let arbitrage_strategy order_book agent =
  let _ = agent in (* Use agent to prevent warning *)
  match best_bid order_book, best_ask order_book with
  | Some bid, Some ask when bid >= ask ->
      (* Market is crossed, opportunity for arbitrage *)
      let qty = 5 in
      [
        create_order Buy ask qty;    (* Buy at the lower ask price *)
        create_order Sell bid qty    (* Sell at the higher bid price *)
      ]
  | _ -> []  (* No arbitrage opportunity *)

(** Random trader strategy: send random orders *)
let random_trader_strategy order_book agent =
  let _ = agent in (* Use agent to prevent warning *)
  let side = if Random.bool () then Buy else Sell in
  
  (* Determine price around current market *)
  let price =
    match mid_price order_book with
    | None -> 100.0 +. (Random.float 2.0 -. 1.0)  (* No market yet *)
    | Some mid -> 
        mid *. (1.0 +. (Random.float 0.02 -. 0.01))  (* Up to 1% deviation *)
  in
  
  let qty = 1 + Random.int 20 in
  
  if Random.float 1.0 < 0.7 then  (* 70% chance to send an order *)
    [create_order side price qty]
  else
    []  (* No orders this tick *)

(* Generate orders for an agent based on its type.
   I designed this to make it easy to add new agent types later.
   The strategy pattern works well in functional programming! *)
let generate_orders order_book agent =
  match agent.agent_type with
  | MarketMaker -> market_maker_strategy order_book agent
  | ArbitrageBot -> arbitrage_strategy order_book agent
  | RandomTrader -> random_trader_strategy order_book agent

(* Update the PnL for all agents based on current mid price.
   Marking to market is essential for realistic P&L tracking.
   I spent time reading about how trading firms calculate P&L intraday. *)
let update_pnl agents order_book =
  match mid_price order_book with
  | None -> agents  (* Can't mark to market without a price reference *)
  | Some mid ->
      List.map (fun agent ->
        (* P&L = cash position + marked inventory value
           This formula is used by real trading desks for intraday P&L.
           I found it interesting how simple the core calculation is! *)
        let mark_to_market = float_of_int agent.inventory *. mid in
        { agent with pnl = agent.cash +. mark_to_market }
      ) agents
