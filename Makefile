APP_NAME   := QuickLook MD
DERIVED    := $(HOME)/Library/Developer/Xcode/DerivedData/QuickLookMD-cli
BUILT_APP  := $(DERIVED)/Build/Products/Release/$(APP_NAME).app
INSTALL_TO := /Applications/$(APP_NAME).app
LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

.PHONY: project build test install uninstall reload release clean

project:
	xcodegen generate

build: project
	xcodebuild -project QuickLookMD.xcodeproj -scheme QuickLookMD -configuration Release \
		-derivedDataPath "$(DERIVED)" -allowProvisioningUpdates -quiet build

test:
	cd Packages/MarkdownRendering && swift test --scratch-path "$(DERIVED)/spm"

install: build
	rm -rf "$(INSTALL_TO)"
	ditto "$(BUILT_APP)" "$(INSTALL_TO)"
	open -g "$(INSTALL_TO)" && sleep 1 && osascript -e 'quit app "$(APP_NAME)"' || true
	pluginkit -a "$(INSTALL_TO)/Contents/PlugIns/QuickLookMDPreview.appex"
	# Remove the build copy: Launch Services re-registers any app it finds on disk, which shows up
	# as a duplicate in Login Items & Extensions.
	pluginkit -r "$(BUILT_APP)/Contents/PlugIns/QuickLookMDPreview.appex" 2>/dev/null || true
	$(LSREGISTER) -u "$(BUILT_APP)"
	rm -rf "$(BUILT_APP)"
	$(MAKE) reload

uninstall:
	pluginkit -r "$(INSTALL_TO)/Contents/PlugIns/QuickLookMDPreview.appex" || true
	rm -rf "$(INSTALL_TO)"
	$(MAKE) reload

reload:
	qlmanage -r >/dev/null
	qlmanage -r cache >/dev/null
	killall -q QuickLookUIService quicklookd 2>/dev/null || true

release:
	scripts/build-release.sh $(VERSION)

clean:
	rm -rf "$(DERIVED)" dist
