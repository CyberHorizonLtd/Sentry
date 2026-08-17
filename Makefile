# Makefile for CyberHorizon Sentry

SWIFTC = swiftc
FLAGS = -O -module-cache-path .build/module-cache
FRAMEWORKS = -framework AppKit -framework AVFoundation -framework AudioToolbox -framework CoreAudio -framework IOKit -framework CoreGraphics
SOURCES = Sources/Sentry/*.swift
TARGET = Sentry
APP_NAME = CyberHorizon Sentry.app
DMG_NAME = CyberHorizonSentry.dmg

all: icon $(TARGET) app dmg

icon: favicon.png
	@echo "[+] Generating AppIcon.icns from favicon.png..."
	@mkdir -p AppIcon.iconset
	@sips -z 16 16 favicon.png --out AppIcon.iconset/icon_16x16.png > /dev/null
	@sips -z 32 32 favicon.png --out AppIcon.iconset/icon_16x16@2x.png > /dev/null
	@sips -z 32 32 favicon.png --out AppIcon.iconset/icon_32x32.png > /dev/null
	@sips -z 64 64 favicon.png --out AppIcon.iconset/icon_32x32@2x.png > /dev/null
	@sips -z 128 128 favicon.png --out AppIcon.iconset/icon_128x128.png > /dev/null
	@sips -z 256 256 favicon.png --out AppIcon.iconset/icon_128x128@2x.png > /dev/null
	@sips -z 256 256 favicon.png --out AppIcon.iconset/icon_256x256.png > /dev/null
	@sips -z 512 512 favicon.png --out AppIcon.iconset/icon_256x256@2x.png > /dev/null
	@sips -z 512 512 favicon.png --out AppIcon.iconset/icon_512x512.png > /dev/null
	@sips -z 1024 1024 favicon.png --out AppIcon.iconset/icon_512x512@2x.png > /dev/null
	@iconutil -c icns AppIcon.iconset -o AppIcon.icns
	@rm -rf AppIcon.iconset

$(TARGET): $(SOURCES)
	@mkdir -p .build/module-cache
	$(SWIFTC) $(FLAGS) $(FRAMEWORKS) $(SOURCES) -o $(TARGET)

app: $(TARGET) icon
	@echo "[+] Creating $(APP_NAME) bundle..."
	@mkdir -p "$(APP_NAME)/Contents/MacOS"
	@mkdir -p "$(APP_NAME)/Contents/Resources"
	@cp $(TARGET) "$(APP_NAME)/Contents/MacOS/$(TARGET)"
	@cp Info.plist "$(APP_NAME)/Contents/Info.plist"
	@if [ -f AppIcon.icns ]; then cp AppIcon.icns "$(APP_NAME)/Contents/Resources/"; fi
	@if [ -f favicon.png ]; then cp favicon.png "$(APP_NAME)/Contents/Resources/"; fi
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

.PHONY: all icon app dmg clean run
