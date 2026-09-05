.PHONY: gen test apptest build strings icon clean

gen:
	xcodegen generate

test:
	cd Packages/TycoonEngine && swift test
	cd Packages/TycoonContent && swift test
	cd Packages/TycoonSave && swift test
	cd Packages/PixelKit && swift test

# The App layer's own unit tests (see the StartupStudioTests target).
#
# The snapshot tests write their chrome PNGs into the app's own temporary
# directory: they run inside the simulator, and TEST_RUNNER_ settings do
# not reach an app-hosted unit test bundle. Collect them with
#   open "$$(xcrun simctl get_app_container booted com.alpsenel.startupstudio data)/tmp/startupstudio-previews"
apptest: gen
	xcodebuild -project StartupStudio.xcodeproj -scheme StartupStudio -destination "platform=iOS Simulator,name=iPhone 17" -derivedDataPath build test

build: gen
	xcodebuild -project StartupStudio.xcodeproj -scheme StartupStudio -destination "platform=iOS Simulator,name=iPhone 17" -derivedDataPath build build

# Iteration 7 (R9): refill App/Resources/Localizable.xcstrings from source.
#
# `xcodebuild` COMPILES the catalog (into en.lproj/Localizable.strings in the
# bundle) but it does NOT write newly extracted keys back into the .xcstrings
# file — only Xcode's IDE does that on a build. What the command-line build
# does leave behind is one .stringsdata per Swift file, emitted because
# SWIFT_EMIT_LOC_STRINGS is YES, and `xcstringstool sync` is the same tool the
# IDE uses to merge those into the catalog. So: build, then sync.
#
# Two gotchas, both cost an afternoon to find:
#   * the .xcstrings file's basename must match the .stringsdata table name
#     ("Localizable"), or sync silently merges nothing and exits 0;
#   * sync marks anything absent from the .stringsdata as stale, so the
#     catalog's header note is an `"extractionState": "manual"` entry, which
#     is the one kind sync leaves alone.
#
# Run it after adding or changing any Text/String(localized:) literal, and
# commit the result. StringsAuditTests fails if the catalog falls under 300
# keys, which is what a forgotten sync looks like.
#
# It reads whatever the last build left in ./build, so it does not pick a
# simulator of its own — run `make build` (or your lane's own xcodebuild
# line) first.
strings:
	@set -eu; \
	OBJ="build/Build/Intermediates.noindex/StartupStudio.build/Debug-iphonesimulator/StartupStudio.build/Objects-normal"; \
	test -d "$$OBJ" || { echo "no build products in ./build — run 'make build' first"; exit 1; }; \
	ARCH="$$(ls "$$OBJ")"; \
	echo "syncing App/Resources/Localizable.xcstrings from $$OBJ/$$ARCH"; \
	xcrun xcstringstool sync App/Resources/Localizable.xcstrings \
		--stringsdata "$$OBJ/$$ARCH"/*.stringsdata; \
	python3 -c "import json,sys; d=json.load(open('App/Resources/Localizable.xcstrings')); print(len(d['strings']), 'keys in the catalog')"

# Regenerates the App Store icon from PixelKit sprites into
# App/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png.
icon:
	swift run --package-path Packages/IconGen IconGen

clean:
	rm -rf build
	rm -rf StartupStudio.xcodeproj
	cd Packages/TycoonEngine && swift package clean 2>/dev/null || true
	cd Packages/TycoonContent && swift package clean 2>/dev/null || true
	cd Packages/TycoonSave && swift package clean 2>/dev/null || true
	cd Packages/PixelKit && swift package clean 2>/dev/null || true
	cd Packages/IconGen && swift package clean 2>/dev/null || true
