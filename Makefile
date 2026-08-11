SCHEME := rork-code-block
DERIVED_DATA ?= .build/xcode
SIMULATOR_ID ?=

.PHONY: build test benchmark documentation format lint require-simulator check

build:
	xcodebuild -scheme $(SCHEME) -destination 'generic/platform=iOS Simulator' -derivedDataPath $(DERIVED_DATA) CODE_SIGNING_ALLOWED=NO build -quiet

require-simulator:
	@test -n "$(SIMULATOR_ID)" || (echo "Set SIMULATOR_ID to an available iOS simulator UDID." && exit 1)

test: require-simulator
	xcodebuild -scheme $(SCHEME) -destination 'platform=iOS Simulator,id=$(SIMULATOR_ID)' -derivedDataPath $(DERIVED_DATA) CODE_SIGNING_ALLOWED=NO test -quiet

benchmark: require-simulator
	xcodebuild -scheme $(SCHEME) -configuration Release -destination 'platform=iOS Simulator,id=$(SIMULATOR_ID)' -derivedDataPath $(DERIVED_DATA) CODE_SIGNING_ALLOWED=NO ENABLE_TESTABILITY=YES test -only-testing:RorkCodeBlockTests/StreamingPerformanceTests/testIncrementalStreamingPerformance

documentation:
	xcodebuild -scheme $(SCHEME) -destination 'generic/platform=iOS Simulator' -derivedDataPath $(DERIVED_DATA) CODE_SIGNING_ALLOWED=NO docbuild -quiet

format:
	swift format format --recursive --in-place Package.swift Sources Tests

lint:
	swift format lint --recursive --strict Package.swift Sources Tests

check: lint build test documentation
