(lang dune 2.9)
(name reactive_trading_sim)
(generate_opam_files true)

(package
 (name reactive_trading_sim)
 (synopsis "A functional reactive trading simulator")
 (description "A limit order book and trading agent simulator written in OCaml")
 (depends
  (ocaml (>= 4.12.0))
  (dune (>= 2.9.0))
  (qcheck (>= 0.18))
  (qcheck-core (>= 0.18))
  (qcheck-alcotest (>= 0.18))
  (alcotest (>= 1.4.0))
  (yojson (>= 1.7.0))
  (unix (>= 4.12.0))))
