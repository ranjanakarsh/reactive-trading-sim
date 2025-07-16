# Functional Reactive Trading Simulator

A purely functional, immutable trading simulator implemented in OCaml. This project models a limit order book, trading agents, and risk metrics using functional programming techniques.

[![OCaml](https://img.shields.io/badge/OCaml-4.12%2B-orange?logo=ocaml)](https://ocaml.org/)  
[![Build](https://github.com/yourusername/trading-simulator/actions/workflows/ci.yml/badge.svg)](https://github.com/yourusername/trading-simulator/actions)  
[![Tests](https://img.shields.io/badge/tests-passing-success?logo=github)](./test)  
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)  
![Property Testing](https://img.shields.io/badge/property--testing-qcheck-purple)  
![Made with OCaml](https://img.shields.io/badge/Made%20with-OCaml-blueviolet?logo=ocaml) 

## Overview

The simulator demonstrates several key concepts:

1. **Immutable Data Structures**: Every update to the order book creates a new immutable instance.
2. **Pure Functions**: The matching engine uses pure functions without side effects.
3. **Functional Reactive Programming**: The simulation loop processes streams of orders reactively.
4. **Property-Based Testing**: Tests verify core properties like no crossed market.

## Components

- **Order Book**: A matching engine that pairs buy and sell orders based on price-time priority.
- **Trading Agents**: Different agent strategies including market makers, arbitrageurs, and random traders.
- **Risk Module**: Tracks inventory, cash positions, PnL, and risk metrics.
- **Simulation Loop**: Processes ticks and generates a history of state snapshots.

## How the Matching Engine Works

The order book maintains two sorted collections:
- **Bids** (Buy orders): Sorted in descending price order
- **Asks** (Sell orders): Sorted in ascending price order

When a new order arrives:
1. For a buy order, we check if there are any asks with a price <= the buy price
2. For a sell order, we check if there are any bids with a price >= the sell price
3. If a match is found, we execute a trade at the resting order's price
4. Unmatched quantity remains in the book

The engine ensures price-time priority, meaning:
- Orders at better prices execute first
- For equal prices, earlier orders execute first

## Agent Strategies

1. **Market Maker**: 
   - Places buy and sell orders around the mid-price
   - Aims to profit from the bid-ask spread

2. **Arbitrage Bot**:
   - Detects crossed markets (best bid >= best ask)
   - Immediately trades to capture the arbitrage opportunity

3. **Random Trader**:
   - Generates random orders with varying prices and quantities
   - Simulates noise traders in the market

## Building and Running

### Prerequisites

- OCaml 4.12.0 or higher
- Dune 2.9.0 or higher
- Alcotest (for unit testing)
- QCheck (for property-based testing)
- QCheck-Alcotest (for integrating QCheck with Alcotest)

Install dependencies:
```bash
opam install dune alcotest qcheck qcheck-alcotest
```

### Setup

```bash
# Install dependencies
make setup

# Build the project
make build
```

### Running the Simulator

```bash
# Run with default settings (50 ticks)
make run

# Run with custom ticks
dune exec bin/main.exe -- --ticks 200

# Output to JSON
dune exec bin/main.exe -- --ticks 100 --output simulation.json
```

### Running Tests

```bash
# Run all tests with the comprehensive test runner
./run_tests.sh

# Or use dune directly
dune runtest

# Run specific test files
dune test test/test_order_book.ml
dune test test/test_agents.ml
dune test test/test_integration.ml
```

We have several types of tests:
- **Unit Tests**: Verify individual components
- **Integration Tests**: Verify component interactions
- **Property-Based Tests**: Verify invariants with random inputs (partially disabled)

See the [Testing Guide](docs/TESTING_GUIDE.md) for more details.

## Example Output

```
Tick: 42
Top of Book: Bid=100.50 Ask=100.60
Last Trade: Buy#123 vs Sell#99 @ 100.55 (50 qty)

Agent PnL:
  MarketMaker: +12.30
  ArbitrageBot: -3.20
  RandomTrader: +0.05

Order Book Depth:
  Bids: [100.50 x 20, 100.45 x 10, ...]
  Asks: [100.60 x 15, 100.65 x 25, ...]
---------------------------------------
```

## Project Structure

```
src/
  types.ml        # Core data structures
  order_book.ml   # Matching engine
  agents.ml       # Trading agent strategies
  simulation.ml   # Simulation loop
  risk.ml         # Risk metrics
bin/
  main.ml         # Entry point
test/
  test_order_book.ml  # Unit and property tests for order book
  test_agents.ml      # Unit tests for trading agents
  test_integration.ml # Integration tests
docs/
  TESTING_GUIDE.md       # Comprehensive testing overview
  INTEGRATION_TESTING.md # Guide for integration tests
  STRESS_TESTING.md      # Guide for stress tests
  SCENARIO_TESTING.md    # Guide for scenario tests
  BENCHMARK_TESTING.md   # Guide for performance benchmarks
run_tests.sh           # Test runner script
DEBUGGING_JOURNEY.md   # Documentation of debugging process
```

## License

MIT License

## Development and Debugging

This project includes a detailed debugging journey that documents the issues faced during development and how they were resolved. This can be useful for learning about OCaml type systems, functional programming patterns, and testing strategies.

See [DEBUGGING_JOURNEY.md](DEBUGGING_JOURNEY.md) for the full story.

## Additional Documentation

For more information on testing approaches and best practices, see the documentation in the `docs/` directory:

- [Testing Guide](docs/TESTING_GUIDE.md): Overview of all testing approaches
- [Integration Testing](docs/INTEGRATION_TESTING.md): Testing component interactions
- [Stress Testing](docs/STRESS_TESTING.md): Testing under high load
- [Scenario Testing](docs/SCENARIO_TESTING.md): Testing realistic market scenarios
- [Benchmark Testing](docs/BENCHMARK_TESTING.md): Performance measurement
