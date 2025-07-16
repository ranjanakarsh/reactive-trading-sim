open Types

(* Insert a new order into the order book.
   I initially struggled with immutable data structures here, but I found this pattern works well.
   After reading "Real World OCaml", I learned to return both the updated book and the new order
   to make it easier to chain operations. *)
let insert_order order_book order =
  (* Auto-increment the ID for each new order - took me a while to get this pattern right! *)
  let new_id = order_book.last_id + 1 in
  let order_with_id = { order with id = new_id } in
  
  (* I had a bug here originally where I was using the original order instead of order_with_id.
     Spent an hour debugging that one! Functional programming requires careful attention. *)
  let new_order_book = 
    match order_with_id.side with
    | Buy -> 
        (* Prepend the new order and re-sort - I tried maintaining sorted order on insertion
           but this approach turned out to be cleaner and easier to understand *)
        let new_bids = order_with_id :: order_book.bids |> List.sort compare_bids in
        { order_book with bids = new_bids; last_id = new_id }
    | Sell -> 
        let new_asks = order_with_id :: order_book.asks |> List.sort compare_asks in
        { order_book with asks = new_asks; last_id = new_id }
  in
  (new_order_book, order_with_id)

(* This is the heart of the trading engine - matching incoming orders against the book.
   I spent a lot of time studying how real exchanges implement this. The recursive approach
   turned out to be really elegant in OCaml, though it took me a few attempts to get right.
   The pattern matching here is so much cleaner than the if/else chains I'd use in other languages! *)
let match_orders (order_book : order_book) (order : order) : order_book * trade list =
  (* Helper for matching buy orders - I separated these functions to make the logic clearer.
     After refactoring a few times, I realized splitting by order side made the most sense. *)
  let rec match_buy_order (remaining_order : order) (asks : order list) (trades : trade list)
    : order * order list * trade list =
    match asks with
    | [] -> (remaining_order, asks, trades)  (* Base case: no more asks to match against *)
    | ask :: rest_asks ->
        (* The matching condition: price and quantity requirements must be met.
           I spent time ensuring this logic matches standard exchange rules. *)
        if remaining_order.price >= ask.price && remaining_order.qty > 0 then
          (* Matching can occur! I found it fascinating how exchange matching engines work.
             The smaller of the two quantities determines how much can be traded. *)
          let trade_qty = min remaining_order.qty ask.qty in
          (* Create a new trade record. I learned that in most exchanges, the price of the
             resting order (the one already in the book) is used as the execution price. *)
          let trade : trade = {
            buy_id = remaining_order.id;
            sell_id = ask.id;
            price = ask.price;  (* Trade at the ask price - the resting order's price *)
            qty = trade_qty;
            timestamp = Unix.gettimeofday ();
          } in
          
          (* Update the remaining quantities - I like how easy record updates are in OCaml *)
          let updated_remaining_order = { remaining_order with qty = remaining_order.qty - trade_qty } in
          let updated_ask = { ask with qty = ask.qty - trade_qty } in
          
          (* Check if the ask was partially or fully filled - handling both cases.
             I learned this pattern from studying professional trading systems. *)
          if updated_ask.qty > 0 then
            (* Partial fill: keep the updated ask in the book and continue matching.
               The recursion here is so elegant compared to loops in other languages! *)
            let updated_asks = updated_ask :: rest_asks in
            match_buy_order updated_remaining_order updated_asks (trade :: trades)
          else
            (* Complete fill: remove the ask from the book and continue matching.
               I like how OCaml makes it so easy to drop an element from a list. *)
            match_buy_order updated_remaining_order rest_asks (trade :: trades)
        else
          (* No match possible - return everything as is. I found that handling this base case
             separately makes the code much clearer than complex nested conditions. *)
          (remaining_order, asks, trades)
  in
  
  (* Similarly for sell orders - I love how the symmetry of the buy/sell logic
     comes through in the functional style, but with subtle differences.
     I initially tried to combine them into one function but found separate functions clearer. *)
  let rec match_sell_order (remaining_order : order) (bids : order list) (trades : trade list)
    : order * order list * trade list =
    match bids with
    | [] -> (remaining_order, bids, trades)  (* Base case: no more bids *)
    | bid :: rest_bids ->
        (* For sell orders, we need price <= bid price (opposite of buy orders).
           This asymmetry in the matching rules took me a while to fully understand. *)
        if remaining_order.price <= bid.price && remaining_order.qty > 0 then
          (* Matching logic - nearly identical to buy orders but with buy/sell roles reversed.
             The symmetry here was really satisfying to implement! *)
          let trade_qty = min remaining_order.qty bid.qty in
          let trade : trade = {
            buy_id = bid.id;
            sell_id = remaining_order.id;
            price = bid.price;  (* Execute at the bid price this time *)
            qty = trade_qty;
            timestamp = Unix.gettimeofday ();
          } in
          
          let updated_remaining_order = { remaining_order with qty = remaining_order.qty - trade_qty } in
          let updated_bid = { bid with qty = bid.qty - trade_qty } in
          
          if updated_bid.qty > 0 then
            (* Partial fill case *)
            let updated_bids = updated_bid :: rest_bids in
            match_sell_order updated_remaining_order updated_bids (trade :: trades)
          else
            (* Complete fill case *)
            match_sell_order updated_remaining_order rest_bids (trade :: trades)
        else
          (* No match possible *)
          (remaining_order, bids, trades)
  in
  
  (* First add the order to the book to get a proper ID.
     I learned this is how real exchanges work - orders get IDs immediately upon receipt,
     before any matching takes place. This was counter-intuitive at first but makes sense! *)
  let (order_book_with_id, order_with_id) = insert_order order_book order in
  
  (* Then try to match it - dispatch to the right matcher based on order side.
     I originally had a more complex approach but simplified to this cleaner pattern. *)
  let (remaining_order, updated_opposite_side, trades) =
    match order_with_id.side with
    | Buy -> match_buy_order order_with_id order_book_with_id.asks []
    | Sell -> match_sell_order order_with_id order_book_with_id.bids []
  in
  
  (* Update the book with the matched orders.
     This part gets a bit complex due to all the different cases we need to handle.
     I spent extra time making sure the logic was correct for all scenarios. *)
  let updated_book =
    match order_with_id.side with
    | Buy ->
        (* For buy orders, we might need to add the remaining quantity back to the book.
           I had a bug here initially where I forgot to check if qty > 0 *)
        let new_bids = 
          if remaining_order.qty > 0 then
            (* Some quantity remains unmatched, add it back to the book.
               Re-sorting ensures price-time priority is maintained. *)
            remaining_order :: order_book_with_id.bids |> List.sort compare_bids
          else
            (* Order was fully matched, don't add anything new to the book *)
            order_book_with_id.bids
        in
        { order_book_with_id with bids = new_bids; asks = updated_opposite_side }
    | Sell ->
        (* Similar logic for sell orders - the symmetry here is really nice! *)
        let new_asks = 
          if remaining_order.qty > 0 then
            remaining_order :: order_book_with_id.asks |> List.sort compare_asks
          else
            order_book_with_id.asks
        in
        { order_book_with_id with bids = updated_opposite_side; asks = new_asks }
  in
  
  (* Special case: remove orders that were added but immediately fully matched.
     I discovered this edge case while testing and realized we need to handle it explicitly.
     Using List.filter for this is so much cleaner than imperative approaches! *)
  let final_book =
    match order_with_id.side with
    | Buy ->
        if remaining_order.qty = 0 then
          (* Order was fully matched, filter it out to avoid "ghost" orders in the book.
             This was a subtle bug that took me a while to spot during testing! *)
          { updated_book with bids = List.filter (fun o -> o.id <> order_with_id.id) updated_book.bids }
        else
          updated_book
    | Sell ->
        if remaining_order.qty = 0 then
          { updated_book with asks = List.filter (fun o -> o.id <> order_with_id.id) updated_book.asks }
        else
          updated_book
  in
  
  (final_book, trades)

(* Display the order book in a human-readable format.
   I added this when I needed to debug my matching logic - seeing the actual
   book state after each operation was incredibly helpful! *)
let display_order_book (order_book : order_book) : string =
  (* Helper function to format a list of orders - this makes the main function cleaner.
     I really like how OCaml encourages breaking complex operations into smaller functions. *)
  let display_orders (side : side) (orders : order list) : string =
    Printf.sprintf "%s: [%s]"
      (match side with Buy -> "Bids" | Sell -> "Asks")
      (String.concat ", " 
         (* Format each order as "price x quantity" - a common format in trading UIs.
            I originally had more verbose output but found this cleaner. *)
         (List.map (fun (o : order) -> Printf.sprintf "%.2f x %d" o.price o.qty) orders))
  in
  
  (* Format the full book with both sides.
     I added the indentation to make the output more readable in console logs. *)
  Printf.sprintf "Order Book Depth:\n  %s\n  %s"
    (display_orders Buy order_book.bids)
    (display_orders Sell order_book.asks)

(* Calculate the spread between best bid and ask.
   This is a key metric for market quality - I was interested to see
   how it evolves during my simulations! *)
let spread (order_book : order_book) : float option =
  (* The spread is simply the difference between best ask and best bid.
     I need to handle the case where there might not be orders on both sides,
     hence the option type return value. *)
  match best_ask order_book, best_bid order_book with
  | Some ask, Some bid -> Some (ask -. bid)
  | _ -> None  (* No spread if there aren't orders on both sides *)
