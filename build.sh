#!/bin/zsh
set -euo pipefail

PROJECT_DIR="/Users/ceaser/Desktop/OpenClaw"
SCHEME="OpenClaw"
CONFIGURATION="Release"
ARCHIVE_PATH="./build/${SCHEME}.xcarchive"
OUTPUT_IPA="${SCHEME}.ipa"

cd "$PROJECT_DIR"

rm -rf build Payload "$OUTPUT_IPA"

xcodebuild archive \
  -project "${SCHEME}.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  DEVELOPMENT_TEAM="" \
  -disableAutomaticPackageResolution

/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$ARCHIVE_PATH/Products/Applications/${SCHEME}.app/Info.plist" >/dev/null
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$ARCHIVE_PATH/Products/Applications/${SCHEME}.app/Info.plist" >/dev/null

mkdir -p Payload
cp -R "$ARCHIVE_PATH/Products/Applications/${SCHEME}.app" Payload/

/usr/bin/zip -qry "$OUTPUT_IPA" Payload

echo "Done: $PROJECT_DIR/$OUTPUT_IPA"
