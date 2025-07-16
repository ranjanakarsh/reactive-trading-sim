(* I started by defining the basic types needed for a trading system.
   Having never built a trading system before, I researched how exchanges
   represent orders and trades. It was interesting to learn about the
   various ways trading systems model their data! *)

(* This is the most fundamental concept in trading - buy or sell side.
   I like how OCaml's variant types make this so clear and type-safe. *)
type side = Buy | Sell

(* I use integers for order IDs to keep things simple.
   In a real system, these might be UUIDs or other complex identifiers.
   Type aliases like this help make the code more readable. *)
type order_id = int

(* The core order type - this took me a few iterations to get right.
   I initially didn't include the timestamp, but then learned about
   price-time priority rules in exchanges and added it. *)
type order = {
  id : order_id;
  price : float;
  qty : int;
  side : side;
  timestamp : float; (* Added timestamp for order precedence - so important! *)
}

(* When two orders match, a trade is created.
   I found it clearer to separate buy_id and sell_id rather than just
   having two generic order_ids. This helps with reporting and analysis. *)
type trade = {
  buy_id : order_id;
  sell_id : order_id;
  price : float;
  qty : int;
  timestamp : float;
}

(* The order book maintains sorted lists of buy and sell orders.
   I spent time thinking about the right data structure here.
   Lists are simple but not optimal for performance - I might
   refactor to use a more efficient structure later. *)
type order_book = {
  bids : order list;  (* I sort these descending by price (highest first) *)
  asks : order list;  (* I sort these ascending by price (lowest first) *)
  last_id : order_id; (* Track the last ID to auto-increment - simple but effective *)
}

(* I wanted to simulate different trading strategies.
   After reading about market microstructure, I decided to implement
   these three common types of market participants. *)
type agent_type = MarketMaker | ArbitrageBot | RandomTrader

(* Each agent needs to track its state through the simulation.
   I track inventory and cash to calculate P&L - just like real traders! *)
type agent_state = {
  agent_type : agent_type;
  inventory : int;    (* positive = long, negative = short - took me a while to get used to this convention *)
  cash : float;       (* cash on hand - decreases when buying, increases when selling *)
  pnl : float;        (* profit and loss - this gets updated as market moves *)
}

(* The top-level simulation state contains everything.
   I decided to use a single record to make it easy to pass around
   the entire state, inspired by the Elm architecture. *)
type simulation_state = {
  order_book : order_book;
  trades : trade list;
  agents : agent_state list;
  tick : int;         (* simulation time progresses in discrete ticks *)
}

(* Utility functions for working with orders and order books.
   I added these as I discovered I needed them while building the simulation. *)

(* Compare functions for sorting orders.
   I spent some time figuring out the right comparison logic for price-time priority.
   Bids are sorted descending by price (highest first), but ascending by time.
   This took me a few tries to get right! *)
let compare_bids (o1 : order) (o2 : order) : int =
  let price_cmp = compare o2.price o1.price in
  if price_cmp = 0 then compare o1.timestamp o2.timestamp else price_cmp

(* For asks, we want ascending price order (lowest first).
   I like how symmetrical the bid/ask functions are, with just the price comparison flipped. *)
let compare_asks (o1 : order) (o2 : order) : int =
  let price_cmp = compare o1.price o2.price in
  if price_cmp = 0 then compare o1.timestamp o2.timestamp else price_cmp

(* Get the best (highest) bid price from the book.
   Using an option type handles the empty book case elegantly.
   I learned to appreciate OCaml's option types while building this project! *)
let best_bid (order_book : order_book) : float option =
  match order_book.bids with
  | [] -> None
  | bid :: _ -> Some bid.price

(* Get the best (lowest) ask price from the book.
   Almost identical to best_bid but operates on the asks list.
   I love how pattern matching makes these functions so clean. *)
let best_ask (order_book : order_book) : float option =
  match order_book.asks with
  | [] -> None
  | ask :: _ -> Some ask.price

(* Calculate the mid-price - the average of best bid and ask.
   This is important for market makers and for marking positions to market.
   Handling the case where either side might be empty was tricky at first. *)
let mid_price (order_book : order_book) : float option =
  match best_bid order_book, best_ask order_book with
  | Some bid, Some ask -> Some ((bid +. ask) /. 2.0)
  | _ -> None

(* Convenience function to get both bid and ask in one call.
   I added this after noticing I often needed both values together. *)
let top_of_book order_book =
  (best_bid order_book, best_ask order_book)

(* Check if the book is "crossed" - when bid price >= ask price.
   This shouldn't happen in a well-functioning market, but can occur
   momentarily during high volatility. I use this to detect arbitrage opportunities. *)
let is_crossed order_book =
  match best_bid order_book, best_ask order_book with
  | Some bid, Some ask -> bid >= ask
  | _ -> false

(* Initialize an empty order book.
   I use this as the starting point for simulations. *)
let empty_order_book = {
  bids = [];
  asks = [];
  last_id = 0;
}

(* Pretty-printing functions for console output.
   I added these to make debugging easier - it's much nicer to see
   "Buy" instead of a variant constructor in the logs! *)
let string_of_side = function
  | Buy -> "Buy"
  | Sell -> "Sell"

let string_of_order order =
  Printf.sprintf "%s#%d (%.2f x %d)" 
    (string_of_side order.side) order.id order.price order.qty

let string_of_trade trade =
  Printf.sprintf "Trade: Buy#%d vs Sell#%d @ %.2f (%d qty)" 
    trade.buy_id trade.sell_id trade.price trade.qty

let string_of_agent_type = function
  | MarketMaker -> "MarketMaker"
  | ArbitrageBot -> "ArbitrageBot"
  | RandomTrader -> "RandomTrader"
