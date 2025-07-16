open Types
open Order_book
open Agents

(* Initialize a simulation with empty order book and agents.
   This is where everything starts - creating a fresh market with initial agents.
   I designed this function to make it easy to reset and restart simulations. *)
let init_simulation () =
  let order_book = empty_order_book in
  (* Create one of each agent type to start with.
     After experimenting with different configurations, I found this
     mix creates the most interesting market dynamics. *)
  let agents = [
    create_agent MarketMaker;   (* Provides liquidity *)
    create_agent ArbitrageBot;  (* Ensures market efficiency *)
    create_agent RandomTrader;  (* Adds noise and volume *)
  ] in
  {
    order_book;
    trades = [];
    agents;
    tick = 0;  (* Start at tick 0 *)
  }

(* Run a single tick of the simulation.
   This is the heart of the simulation - each tick represents a discrete time step.
   I spent a lot of time getting this logic right, as it coordinates all the
   interactions between agents and the market. *)
let run_tick sim =
  (* First, have each agent generate their orders for this tick.
     I found this approach cleaner than having agents directly modify the book.
     It mimics how real trading works - agents submit orders to the exchange. *)
  let all_agent_orders = 
    List.map (fun agent -> 
      (agent, generate_orders sim.order_book agent)
    ) sim.agents
  in
  
  (* Next, process all the orders and collect resulting trades.
     This is a complex fold operation that took me a while to get right.
     The triple accumulator pattern is powerful but took some getting used to! *)
  let (updated_book, all_trades, updated_agents) =
    List.fold_left (fun (book, trades_acc, agents_acc) (agent, orders) ->
      (* For each agent, process all their orders sequentially.
         This simulates the time ordering of order submission. *)
      let (final_book, agent_trades, updated_agent) =
        List.fold_left (fun (curr_book, curr_trades, curr_agent) order ->
          (* For each order, run it through the matching engine.
             I was impressed by how clean this functional approach is compared
             to the imperative code I've seen in other trading systems. *)
          let (new_book, new_trades) = match_orders curr_book order in
          
          (* Update the agent state based on any executed trades.
             The agent needs to know about trades to update inventory and cash. *)
          let new_agent = update_agent_state curr_agent new_trades in
          (* Return updated state for the next iteration.
             Accumulating trades and updating the book as we go. *)
          (new_book, new_trades @ curr_trades, new_agent)
        ) (book, [], agent) orders
      in
      
      (* Accumulate results from this agent into the overall simulation state *)
      (final_book, agent_trades @ trades_acc, updated_agent :: agents_acc)
    ) (sim.order_book, [], []) all_agent_orders
  in
  
  (* Finally, mark all positions to market to get current P&L.
     I learned this pattern from reading about how trading firms calculate P&L.
     Real trading systems update P&L continuously throughout the day. *)
  let pnl_updated_agents = update_pnl (List.rev updated_agents) updated_book in
  
  (* Return the complete updated simulation state.
     Everything is immutable, so we return a brand new state record.
     I love how this makes debugging and time-travel easier! *)
  {
    order_book = updated_book;
    trades = all_trades;
    agents = pnl_updated_agents;
    tick = sim.tick + 1;  (* Advance to the next tick *)
  }

(* Run the simulation for n ticks and return the final state plus history.
   I added the history tracking to analyze market evolution over time.
   This was inspired by agent-based modeling frameworks I've studied. *)
let run_simulation n =
  let initial_sim = init_simulation () in
  
  (* Recursive function to iterate through all ticks.
     I originally used a loop, but this recursive approach is more elegant
     and fits better with OCaml's functional paradigm. *)
  let rec run i sim history =
    if i >= n then
      (* Return the final state and history (in chronological order) *)
      (sim, List.rev history)
    else
      let updated_sim = run_tick sim in
      (* Recursively process the next tick, accumulating history *)
      run (i + 1) updated_sim (updated_sim :: history)
  in
  
  (* Start at tick 0 with the initial simulation state *)
  run 0 initial_sim []

(* Format the simulation state for display or logging.
   I added detailed output to help me understand what's happening
   during each tick of the simulation. This was invaluable for debugging! *)
let display_simulation sim =
  (* Show which tick we're on - helps track simulation progress *)
  let tick_info = Printf.sprintf "Tick: %d" sim.tick in
  
  (* Show the current best prices in the market.
     I format this to look like a real trading terminal display. *)
  let top_info =
    match top_of_book sim.order_book with
    | (Some bid, Some ask) -> 
        Printf.sprintf "Top of Book: Bid=%.2f Ask=%.2f" bid ask
    | (Some bid, None) -> 
        Printf.sprintf "Top of Book: Bid=%.2f Ask=None" bid
    | (None, Some ask) -> 
        Printf.sprintf "Top of Book: Bid=None Ask=%.2f" ask
    | (None, None) -> 
        "Top of Book: No market"
  in
  
  (* Show the most recent trade - this helps track market activity.
     I learned that real trading systems emphasize the "last trade" as
     a key market indicator. *)
  let last_trade_info =
    match sim.trades with
    | [] -> "Last Trade: None"
    | trade :: _ -> string_of_trade trade
  in
  
  (* Display agent PnL *)
  let agent_pnl_info =
    "Agent PnL:\n" ^
    String.concat "\n" (
      List.map (fun agent ->
        Printf.sprintf "  %s: %+.2f" 
          (string_of_agent_type agent.agent_type) agent.pnl
      ) sim.agents
    )
  in
  
  (* Display order book depth *)
  let book_info = display_order_book sim.order_book in
  
  (* Combine all information *)
  Printf.sprintf "%s\n%s\n%s\n\n%s\n\n%s\n\n---------------------------------------\n"
    tick_info top_info last_trade_info agent_pnl_info book_info

(** Export the simulation state to JSON *)
let export_simulation_to_json (sim : simulation_state) : string =
  (* A simple string representation for now - could be expanded to use Yojson *)
  let json = Printf.sprintf 
    {|{
  "tick": %d,
  "orderBook": {
    "bids": [%s],
    "asks": [%s]
  },
  "trades": [%s],
  "agents": [%s]
}|}
    sim.tick
    (String.concat ", " (
      List.map (fun (o : order) -> 
        Printf.sprintf {|{"price": %.2f, "qty": %d}|} o.price o.qty
      ) sim.order_book.bids
    ))
    (String.concat ", " (
      List.map (fun (o : order) -> 
        Printf.sprintf {|{"price": %.2f, "qty": %d}|} o.price o.qty
      ) sim.order_book.asks
    ))
    (String.concat ", " (
      List.map (fun (t : trade) -> 
        Printf.sprintf {|{"buyId": %d, "sellId": %d, "price": %.2f, "qty": %d}|} 
          t.buy_id t.sell_id t.price t.qty
      ) sim.trades
    ))
    (String.concat ", " (
      List.map (fun (a : agent_state) -> 
        Printf.sprintf {|{"type": "%s", "inventory": %d, "cash": %.2f, "pnl": %.2f}|} 
          (string_of_agent_type a.agent_type) a.inventory a.cash a.pnl
      ) sim.agents
    ))
  in
  json
