# Makefile for Foundry-based Solidity project

# Default target: initialize project
default: install build test coverage coverage-html fmt

# Install required dependencies
install:
	forge install transmissions11/solmate@v6
	forge install OpenZeppelin/openzeppelin-contracts@v5.3.0 --no-commit

# Build contracts
build:
	forge build

# Run tests
test:
	forge test -vv

# Generate coverage report (lcov format)
coverage:
	forge coverage --report lcov

# Generate HTML coverage report using genhtml
coverage-html: coverage
	genhtml lcov.info --output-directory coverage-html
	@echo "Coverage report available at coverage-html/index.html"

# Clean build and cache files
clean:
	forge clean
	rm -rf coverage-html lcov.info

# Format Solidity code (if desired)
fmt:
	forge fmt
