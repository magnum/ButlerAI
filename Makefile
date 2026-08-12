PROJECT := Higgins.xcodeproj
SCHEME := Higgins
DERIVED_DATA := ./DerivedData
ARCHIVE_PATH := ./build/Higgins.xcarchive

XCODEBUILD_BASE := OS_ACTIVITY_MODE=disable xcodebuild -scheme $(SCHEME) -project $(PROJECT) -destination 'platform=macOS' -derivedDataPath $(DERIVED_DATA) CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=
XCODEBUILD_FILTER := rg -v "CoreSimulatorService connection became invalid|Logging connecton invalid|Error opening log file|SimServiceContext|simdiskimaged"

.PHONY: help test test-build build archive clean

help:
	@echo "Targets:"
	@echo "  make test     # Run unit tests"
	@echo "  make test-build  # Build unit tests only (no execution)"
	@echo "  make build    # Build app"
	@echo "  make archive  # Archive app"
	@echo "  make clean    # Remove DerivedData and build artifacts"

test:
	@$(XCODEBUILD_BASE) -only-testing:HigginsTests test 2>&1 | tee /tmp/higgins_make_test.log | $(XCODEBUILD_FILTER) | xcsift -w
	@rg -o "Executed [0-9]+ tests" /tmp/higgins_make_test.log >/dev/null || (echo "ERROR: test count not found in /tmp/higgins_make_test.log" && exit 1)
	@tests_run=$$(rg -o "Executed [0-9]+ tests" /tmp/higgins_make_test.log | tail -n 1 | rg -o "[0-9]+" | tail -n 1); \
		if [ -z "$$tests_run" ]; then echo "ERROR: test count not found in /tmp/higgins_make_test.log"; exit 1; fi; \
		echo "tests_run: $$tests_run"

test-build:
	@$(XCODEBUILD_BASE) build-for-testing 2>&1 | tee /tmp/higgins_make_test_build.log | $(XCODEBUILD_FILTER) | xcsift -w

build:
	@$(XCODEBUILD_BASE) build 2>&1 | tee /tmp/higgins_make_build.log | $(XCODEBUILD_FILTER) | xcsift -w

archive:
	@$(XCODEBUILD_BASE) archive -archivePath $(ARCHIVE_PATH) 2>&1 | xcsift -w

clean:
	@rm -rf $(DERIVED_DATA) ./build
