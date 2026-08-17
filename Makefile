# Makefile for CyberHorizon Sentry

SWIFTC = swiftc
FLAGS = -O -module-cache-path .build/module-cache
FRAMEWORKS = -framework AppKit -framework AVFoundation -framework AudioToolbox -framework CoreAudio -framework IOKit -framework CoreGraphics
SOURCES = Sources/Sentry/*.swift
TARGET = Sentry
APP_NAME = CyberHorizon Sentry.app
DMG_NAME = CyberHorizonSentry.dmg

all: $(TARGET) app dmg

$(TARGET): $(SOURCES)
	@mkdir -p .build/module-cache
	$(SWIFTC) $(FLAGS) $(FRAMEWORKS) $(SOURCES) -o $(TARGET)

app: $(TARGET)
	@echo "[+] Creating $(APP_NAME) bundle..."
	@mkdir -p "$(APP_NAME)/Contents/MacOS"
	@mkdir -p "$(APP_NAME)/Contents/Resources"
	@cp $(TARGET) "$(APP_NAME)/Contents/MacOS/$(TARGET)"
	@cp Info.plist "$(APP_NAME)/Contents/Info.plist"
	@if [ -f AppIcon.icns ]; then cp AppIcon.icns "$(APP_NAME)/Contents/Resources/"; fi
	@if [ -f favicon.png ]; then cp favicon.png "$(APP_NAME)/Contents/Resources/"; fi
	@if [ -f .env ]; then cp .env "$(APP_NAME)/Contents/Resources/"; fi
	@echo "[+] App bundle created at: $(APP_NAME)"

dmg: app
	@echo "[+] Generating $(DMG_NAME)..."
	@rm -rf .dmg_dist $(DMG_NAME)
	@mkdir -p .dmg_dist
	@cp -R "$(APP_NAME)" .dmg_dist/
	@ln -s /Applications .dmg_dist/Applications
	@hdiutil create -volname "CyberHorizon Sentry" -srcfolder .dmg_dist -ov -format UDZO -o $(DMG_NAME)
	@rm -rf .dmg_dist
	@echo "[+] Disk image created at: $(DMG_NAME)"

clean:
	rm -rf $(TARGET) "$(APP_NAME)" $(DMG_NAME) .build .dmg_dist AppIcon.icns

run: $(TARGET)
	./$(TARGET)

.PHONY: all app dmg clean run
