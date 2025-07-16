.PHONY: build clean run test

# Default target
all: build

# Build the project
build:
	dune build @install

# Build and run the simulator
run:
	dune exec bin/main.exe -- --ticks 100

# Build and run the tests
test:
	dune runtest

# Clean build artifacts
clean:
	dune clean

# Install dependencies
setup:
	opam install --deps-only .
	
# Install the project
install:
	dune install
