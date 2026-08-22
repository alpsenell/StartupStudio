.PHONY: gen test build icon clean

gen:
	xcodegen generate

test:
	cd Packages/TycoonEngine && swift test
	cd Packages/TycoonContent && swift test
	cd Packages/TycoonSave && swift test
	cd Packages/PixelKit && swift test

build: gen
	xcodebuild -project StartupStudio.xcodeproj -scheme StartupStudio -destination "platform=iOS Simulator,name=iPhone 17" -derivedDataPath build build

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
