#!/bin/bash
# Dung file IPA KHONG ky (unsigned) - TrollStore/SideStore se tu ky khi cai.
set -e
cd "$(dirname "$0")"
SDK=$(xcrun --sdk iphoneos --show-sdk-path)
rm -rf build
mkdir -p build/Payload/T2GO.app
xcrun swiftc -O -parse-as-library -module-name T2GO \
  -target arm64-apple-ios15.0 -sdk "$SDK" \
  -framework UIKit -framework WebKit \
  -o build/Payload/T2GO.app/T2GO \
  Sources/T2GOApp.swift
cp Sources/Info.plist build/Payload/T2GO.app/Info.plist
cp Icons/*.png build/Payload/T2GO.app/
cd build && zip -qry ../T2GO.ipa Payload
echo "XONG: T2GO.ipa"
