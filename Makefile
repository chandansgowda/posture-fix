APP_NAME := PostureFix
CONFIG   := release
BIN_DIR   = $(shell swift build -c $(CONFIG) --show-bin-path)
APP_BUNDLE = $(BIN_DIR)/$(APP_NAME).app

.PHONY: build run install uninstall clean

build:
	./build.sh $(CONFIG)

run: build
	open "$(APP_BUNDLE)"

install: build
	@echo "› Installing to /Applications/$(APP_NAME).app"
	rm -rf "/Applications/$(APP_NAME).app"
	cp -R "$(APP_BUNDLE)" "/Applications/$(APP_NAME).app"
	@echo "✓ Installed. Launch from Spotlight or: open -a $(APP_NAME)"

uninstall:
	rm -rf "/Applications/$(APP_NAME).app"
	@echo "✓ Removed /Applications/$(APP_NAME).app"

clean:
	rm -rf .build
