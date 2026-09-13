SHELL := /bin/zsh

CONFIGURATION ?= debug
SIGNING_IDENTITY ?= -
SDKROOT ?= /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk

APP_NAME := McNetworkMenu
APP_BUNDLE := $(CURDIR)/.build/apps/$(CONFIGURATION)/$(APP_NAME).app
INSTALL_DIR ?= $(HOME)/Applications
INSTALL_BUNDLE := $(INSTALL_DIR)/$(APP_NAME).app
APP_CONTENTS := $(APP_BUNDLE)/Contents
APP_EXECUTABLE := $(APP_CONTENTS)/MacOS/$(APP_NAME)
SWIFT_CACHE := $(CURDIR)/.build/cache
SWIFT_CONFIG := $(CURDIR)/.build/config
SWIFT_SECURITY := $(CURDIR)/.build/security
SWIFT_SCRATCH := $(CURDIR)/.build/spm
CLANG_CACHE := $(CURDIR)/.build/clang-cache
SWIFT_MODULE_CACHE := $(CURDIR)/.build/swiftpm-module-cache
DEVELOPER_FRAMEWORKS := /Library/Developer/CommandLineTools/Library/Developer/Frameworks
SWIFT := env SDKROOT=$(SDKROOT) CLANG_MODULE_CACHE_PATH=$(CLANG_CACHE) SWIFTPM_MODULECACHE_OVERRIDE=$(SWIFT_MODULE_CACHE) swift
SWIFT_FLAGS := --disable-sandbox --scratch-path $(SWIFT_SCRATCH) --cache-path $(SWIFT_CACHE) --config-path $(SWIFT_CONFIG) --security-path $(SWIFT_SECURITY) --manifest-cache local
SWIFT_TEST_FLAGS := $(SWIFT_FLAGS) -Xswiftc -F -Xswiftc $(DEVELOPER_FRAMEWORKS) -Xlinker -F$(DEVELOPER_FRAMEWORKS) -Xlinker -rpath -Xlinker $(DEVELOPER_FRAMEWORKS)
SWIFT_BIN_DIR = $(shell $(SWIFT) build $(SWIFT_FLAGS) --configuration $(CONFIGURATION) --show-bin-path)
SWIFT_EXECUTABLE := $(SWIFT_BIN_DIR)/$(APP_NAME)

.PHONY: build test clean run release bundle verify check install

build:
	$(MAKE) bundle CONFIGURATION=debug

test:
	$(SWIFT) test $(SWIFT_TEST_FLAGS)

clean:
	/bin/rm -rf "$(CURDIR)/.build"

run: build
	open "$(CURDIR)/.build/apps/debug/$(APP_NAME).app"

release:
	$(MAKE) bundle CONFIGURATION=release

install: release
	/bin/mkdir -p "$(INSTALL_DIR)"
	/bin/rm -rf "$(INSTALL_BUNDLE)"
	/usr/bin/ditto "$(CURDIR)/.build/apps/release/$(APP_NAME).app" "$(INSTALL_BUNDLE)"

bundle:
	$(SWIFT) build $(SWIFT_FLAGS) --configuration $(CONFIGURATION)
	/bin/rm -rf "$(APP_BUNDLE)"
	/bin/mkdir -p "$(APP_CONTENTS)/MacOS"
	/usr/bin/install -m 755 "$(SWIFT_EXECUTABLE)" "$(APP_EXECUTABLE)"
	/usr/bin/install -m 644 "$(CURDIR)/Support/Info.plist" "$(APP_CONTENTS)/Info.plist"
	/usr/bin/codesign --force --sign "$(SIGNING_IDENTITY)" "$(APP_BUNDLE)"
	$(MAKE) verify CONFIGURATION=$(CONFIGURATION)

verify:
	/usr/bin/plutil -lint "$(APP_CONTENTS)/Info.plist"
	test -x "$(APP_EXECUTABLE)"
	/usr/bin/codesign --verify --deep --strict "$(APP_BUNDLE)"

check: test release
