# Comprehensive Testing Guide

This document outlines all the different ways you can test the Reactive Trading Simulator project.

## Overview of Testing Approaches

| Testing Approach | Purpose | Tools |
|------------------|---------|-------|
| Unit Testing | Test individual components in isolation | Alcotest |
| Property-Based Testing | Test invariants across random inputs | QCheck2, QCheck-Alcotest |
| Integration Testing | Test component interactions | Alcotest |
| Stress Testing | Test performance under load | Custom + Alcotest |
| Scenario Testing | Test realistic market scenarios | Custom + Alcotest |
| Benchmark Testing | Measure and compare performance | Core_bench |

## Getting Started with Testing

### Prerequisites

Ensure you have all required dependencies:

```bash
opam install alcotest qcheck qcheck-alcotest core_bench
```

### Running All Tests

To run the complete test suite:

```bash
dune runtest
```

### Running Specific Tests

To run only specific test files:

```bash
dune test test/test_order_book.ml
dune test test/test_agents.ml
```

## Test Categories

### 1. Unit Tests

Unit tests verify that individual components work correctly in isolation. Our project has unit tests for:

- Order Book operations (`test_order_book.ml`)
- Agent strategies (`test_agents.ml`)

### 2. Property-Based Tests

Property-based tests verify invariants that should hold across many different inputs:

- No crossed book after matching operations
- Empty book properties
- Trade quantity validation

### 3. Integration Tests

Integration tests verify that components work together correctly:

- Agent interaction with order book
- Simulation step correctness
- End-to-end trading scenarios

See: [Integration Testing Guide](INTEGRATION_TESTING.md)

### 4. Stress Testing

Stress tests verify that the system performs well under high load:

- High volume order processing
- Deep order book matching
- Performance under extreme conditions

See: [Stress Testing Guide](STRESS_TESTING.md)

### 5. Scenario Testing

Scenario tests verify the system's behavior in realistic market conditions:

- Flash crash recovery
- Price momentum
- Market volatility

See: [Scenario Testing Guide](SCENARIO_TESTING.md)

### 6. Benchmark Testing

Benchmark tests measure the performance of critical operations:

- Order insertion throughput
- Order matching speed
- Book operation efficiency

See: [Benchmark Testing Guide](BENCHMARK_TESTING.md)

## Best Practices

1. **Start with unit tests**: Ensure core components work correctly before testing interactions
2. **Add property tests**: Define invariants that should always hold
3. **Create integration tests**: Verify component interactions
4. **Add scenario tests**: Test realistic market conditions
5. **Benchmark critical paths**: Identify and optimize performance bottlenecks

## Creating New Tests

When adding new functionality, follow this testing workflow:

1. Write unit tests for the new component
2. Define properties that should hold for the component
3. Update integration tests to include the new component
4. Add relevant scenario tests
5. Benchmark if performance-critical

## Troubleshooting Common Test Issues

### Type Errors

OCaml's type system can catch many errors, but can sometimes be confusing. Common issues:

- Confusion between `order` and `trade` types
- Missing type annotations
- Record field access type mismatches

### Test Failures

When tests fail, look for:

- Incorrect expectations
- Edge cases not handled
- Random seed issues in property tests (use the seed to reproduce)

## Continuous Integration

For continuous integration, you can run:

```bash
dune runtest
```

This will execute all tests and return a non-zero exit code if any tests fail.
