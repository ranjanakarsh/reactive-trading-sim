open Types

(** Calculate the exposure (absolute value of inventory) *)
let exposure agent =
  abs agent.inventory

(** Calculate the value at risk based on current inventory and price volatility *)
let value_at_risk agent mid_price volatility confidence_level =
  let position_value = float_of_int agent.inventory *. mid_price in
  let var = position_value *. volatility *. confidence_level in
  var

(** Calculate drawdown from peak PnL *)
let drawdown agent peak_pnl =
  peak_pnl -. agent.pnl

(** Update the peak PnL if the current PnL is higher *)
let update_peak_pnl agent peak_pnl =
  max peak_pnl agent.pnl

(** Get a risk report for an agent *)
let risk_report agent peak_pnl mid_price =
  let exposure_val = exposure agent in
  let drawdown_val = drawdown agent peak_pnl in
  
  (* Assuming a fixed volatility and confidence level for simplicity *)
  let volatility = 0.02 in  (* 2% daily volatility *)
  let confidence = 1.65 in  (* ~95% confidence level *)
  let var = value_at_risk agent mid_price volatility confidence in
  
  Printf.sprintf "Risk Report for %s:\n  Exposure: %d units\n  Drawdown: %.2f\n  VaR (95%%): %.2f"
    (string_of_agent_type agent.agent_type)
    exposure_val
    drawdown_val
    var

(** Generate a risk report for all agents *)
let generate_risk_reports agents peak_pnls order_book =
  match mid_price order_book with
  | None -> "Cannot generate risk reports: no mid price available"
  | Some mid ->
      let reports = 
        List.map2 
          (fun agent peak_pnl -> risk_report agent peak_pnl mid)
          agents
          peak_pnls
      in
      String.concat "\n\n" reports
