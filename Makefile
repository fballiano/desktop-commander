# Deskyard — build helpers.
#
#   make generate   regenerate DesktopCommander.xcodeproj from project.yml (needs xcodegen)
#   make build      build the Release app into ./build
#   make debug      build the Debug app into ./build
#   make test       run the unit tests
#   make run        build, then launch the app
#   make install    copy the app into /Applications
#   make dmg        build the Release app and pack it into ./dist/*.dmg
#   make package    pack the Release app that is already built into ./dist/*.dmg
#   make clean      remove ./build and ./dist
#
# Set VERSION to stamp a version into the build, for example:
#
#   make dmg VERSION=1.0.0 BUILD_NUMBER=7
#
# Set XCODE_FLAGS to add settings to the Release build. The release workflow
# signs with a Developer ID this way; a local build stays signed ad hoc.

SHELL          := /bin/bash
PROJECT        := DesktopCommander.xcodeproj
SCHEME         := DesktopCommander
APP            := Deskyard.app
# The app had this name up to 1.3.1. It has the same bundle identifier, so
# install and uninstall remove it too: two copies break the permission.
OLD_APP        := desktop-commander.app
BUILD_DIR      := $(CURDIR)/build
DIST_DIR       := $(CURDIR)/dist
APP_RELEASE    := $(BUILD_DIR)/Build/Products/Release/$(APP)
APP_DEBUG      := $(BUILD_DIR)/Build/Products/Debug/$(APP)
XCODEBUILD     := xcodebuild -project $(PROJECT) -scheme $(SCHEME) -derivedDataPath $(BUILD_DIR)
QUIET          := -quiet
PLIST_BUDDY    := /usr/libexec/PlistBuddy

# VERSION and BUILD_NUMBER are empty by default, so a plain build keeps the
# values from project.yml. The release workflow passes the values of the tag.
VERSION        ?=
BUILD_NUMBER   ?=
ifneq ($(VERSION),)
VERSION_FLAGS  += MARKETING_VERSION=$(VERSION)
endif
ifneq ($(BUILD_NUMBER),)
VERSION_FLAGS  += CURRENT_PROJECT_VERSION=$(BUILD_NUMBER)
endif
XCODE_FLAGS    ?=

.PHONY: all generate build debug test run install uninstall dmg package clean

all: build

generate:
	xcodegen generate

build:
	$(XCODEBUILD) -configuration Release $(VERSION_FLAGS) $(XCODE_FLAGS) $(QUIET) build
	@echo "Built $(APP_RELEASE)"

debug:
	$(XCODEBUILD) -configuration Debug $(QUIET) build
	@echo "Built $(APP_DEBUG)"

# Serial testing: the tests load into the real app, so a parallel run would
# launch one copy of the app per test worker. The results are printed, so this
# target does not use -quiet.
#
# The test host is the Debug app, and it stays running after the tests. That
# matters here more than in an ordinary project: the Debug app and the installed
# app share a bundle identifier, so `open` on the installed one only activates
# the Debug copy that is already there. The Accessibility permission belongs to
# one binary, so the user then grants it to the wrong copy.
#
# The last line therefore stops the copies under ./build only. It leaves
# /Applications alone, so a test run never takes away the permission the user
# granted to the installed app.
test:
	@set -o pipefail; $(XCODEBUILD) -configuration Debug \
		-destination 'platform=macOS,arch=arm64' \
		-parallel-testing-enabled NO test \
		| grep -vE 'linkd.autoShortcut|Process Instance Registry|synchronousRemoteObjectProxy'
	@pkill -f '$(BUILD_DIR)/Build/Products/.*/$(APP)/Contents/MacOS/' || true

run: build
	@pkill -f '/$(APP)/Contents/MacOS/' || true
	@sleep 1
	@open -n $(APP_RELEASE)

install: build
	@pkill -f '/$(APP)/Contents/MacOS/' || true
	@pkill -f '/$(OLD_APP)/Contents/MacOS/' || true
	@rm -rf /Applications/$(APP) /Applications/$(OLD_APP)
	@cp -R $(APP_RELEASE) /Applications/$(APP)
	@echo "Installed /Applications/$(APP)"

uninstall:
	@pkill -f '/$(APP)/Contents/MacOS/' || true
	@pkill -f '/$(OLD_APP)/Contents/MacOS/' || true
	@rm -rf /Applications/$(APP) /Applications/$(OLD_APP)
	@echo "Removed /Applications/$(APP)"

dmg: build package

# A disk image with the app and a link to /Applications. The version comes from
# the built app, so the name of the file always matches the bundle. This packs
# the app as it is: the release workflow notarizes the app before it packs it,
# and a second build could sign it again and drop the ticket.
package:
	@set -euo pipefail; \
	version=$$($(PLIST_BUDDY) -c "Print CFBundleShortVersionString" "$(APP_RELEASE)/Contents/Info.plist"); \
	staging="$(DIST_DIR)/dmg"; \
	image="$(DIST_DIR)/Deskyard-$$version.dmg"; \
	rm -rf "$$staging" "$$image"; \
	mkdir -p "$$staging"; \
	cp -R "$(APP_RELEASE)" "$$staging/"; \
	ln -s /Applications "$$staging/Applications"; \
	hdiutil create -volname "Deskyard $$version" -srcfolder "$$staging" \
		-ov -format UDZO -quiet "$$image"; \
	rm -rf "$$staging"; \
	echo "Built $$image"

clean:
	@rm -rf $(BUILD_DIR) $(DIST_DIR)
