open Reactive_trading_sim.Types
open Reactive_trading_sim.Simulation

(** Entry point for the simulator *)
let () =
  (* Parse command line arguments *)
  let ticks = ref 50 in
  let output_file = ref None in
  
  let specs = [
    ("--ticks", Arg.Set_int ticks, "Number of simulation ticks to run");
    ("--output", Arg.String (fun s -> output_file := Some s), "Output JSON file for simulation data");
  ] in
  
  let usage = "Usage: ./main.exe [--ticks NUM] [--output FILE]" in
  
  Arg.parse specs (fun _ -> ()) usage;
  
  (* Run the simulation *)
  Printf.printf "Running trading simulation for %d ticks...\n\n" !ticks;
  
  let (final_sim, _) = run_simulation !ticks in
  
  (* Print final state *)
  Printf.printf "%s\n" (display_simulation final_sim);
  
  (* Print summary *)
  Printf.printf "Simulation complete!\n";
  Printf.printf "Total ticks: %d\n" !ticks;
  Printf.printf "Total trades: %d\n" (List.length final_sim.trades);
  
  (* Export to JSON if requested *)
  match !output_file with
  | Some file ->
      let json = export_simulation_to_json final_sim in
      let oc = open_out file in
      output_string oc json;
      close_out oc;
      Printf.printf "Exported simulation data to %s\n" file
  | None -> ()
