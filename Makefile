SCHEME := rork-code-block
DERIVED_DATA ?= .build/xcode
BENCHMARK_SCHEME := rork-code-block-production-benchmarks-Package
BENCHMARK_DERIVED_DATA ?= $(abspath .build/benchmarks-xcode)
BENCHMARK_PACKAGE := Benchmarks/Production
SIMULATOR_ID ?=

.PHONY: build build-device build-catalyst build-visionos build-platforms test benchmark documentation format lint require-simulator check

build:
	xcodebuild -scheme $(SCHEME) -destination 'generic/platform=iOS Simulator' -derivedDataPath $(DERIVED_DATA) CODE_SIGNING_ALLOWED=NO build -quiet

build-device:
	xcodebuild -scheme $(SCHEME) -destination 'generic/platform=iOS' -derivedDataPath $(DERIVED_DATA) CODE_SIGNING_ALLOWED=NO build -quiet

build-catalyst:
	xcodebuild -scheme $(SCHEME) -destination 'generic/platform=macOS,variant=Mac Catalyst' -derivedDataPath $(DERIVED_DATA) CODE_SIGNING_ALLOWED=NO build -quiet

build-visionos:
	xcodebuild -scheme $(SCHEME) -destination 'generic/platform=visionOS Simulator' -derivedDataPath $(DERIVED_DATA) CODE_SIGNING_ALLOWED=NO build -quiet

build-platforms: build-device build-catalyst build-visionos

require-simulator:
	@test -n "$(SIMULATOR_ID)" || (echo "Set SIMULATOR_ID to an available iOS simulator UDID." && exit 1)

test: require-simulator
	xcodebuild -scheme $(SCHEME) -destination 'platform=iOS Simulator,id=$(SIMULATOR_ID)' -derivedDataPath $(DERIVED_DATA) CODE_SIGNING_ALLOWED=NO test -only-testing:RorkCodeBlockTests -quiet

benchmark: require-simulator
	cd $(BENCHMARK_PACKAGE) && xcodebuild -scheme $(BENCHMARK_SCHEME) -configuration Release -destination 'platform=iOS Simulator,id=$(SIMULATOR_ID)' -derivedDataPath $(BENCHMARK_DERIVED_DATA) CODE_SIGNING_ALLOWED=NO ENABLE_TESTABILITY=NO test -only-testing:RorkCodeBlockProductionBenchmarks/StreamingPerformanceTests

documentation:
	xcodebuild -scheme $(SCHEME) -destination 'generic/platform=iOS Simulator' -derivedDataPath $(DERIVED_DATA) CODE_SIGNING_ALLOWED=NO docbuild -quiet

format:
	swift format format --recursive --in-place Package.swift Sources Tests $(BENCHMARK_PACKAGE)/Package.swift $(BENCHMARK_PACKAGE)/Tests

lint:
	swift format lint --recursive --strict Package.swift Sources Tests $(BENCHMARK_PACKAGE)/Package.swift $(BENCHMARK_PACKAGE)/Tests

check: lint build test documentation
