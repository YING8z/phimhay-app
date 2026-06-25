#!/bin/bash

echo ""
echo "========================================"
echo "  Xiao Phim - Build iOS (IPA)"
echo "========================================"
echo ""

if [ -z "$1" ]; then
    read -p "Nhap version (vd: 3.3.0): " VERSION
    if [ -z "$VERSION" ]; then
        echo "Version khong duoc trong!"
        exit 1
    fi
else
    VERSION=$1
fi

echo "Version: $VERSION"
echo ""

# Doc version hien tai
OLD_VER=$(grep -oP 'version:\s*\K\S+' pubspec.yaml)
BUILD=$(echo "$OLD_VER" | cut -d'+' -f2)
NEW_BUILD=$((BUILD + 1))
NEW_VER="${VERSION}+${NEW_BUILD}"

# Cap nhat pubspec.yaml
echo "Cap nhat pubspec.yaml: $NEW_VER"
sed -i '' "s/version: .*/version: $NEW_VER/" pubspec.yaml
echo "Done"
echo ""

# Build IPA (can codesign de tao .ipa)
echo "Building IPA..."
flutter build ipa --release
if [ $? -ne 0 ]; then
    echo "Build that bai!"
    exit 1
fi

# Tim file IPA va rename
mkdir -p build/output
IPA_PATH=$(find build/ios -name "*.ipa" | head -1)
if [ -n "$IPA_PATH" ]; then
    # Xoa file cu trong build/output de tiet kiem dung luong
    echo "Xoa file cu..."
    rm -f build/output/xiaophim-*.ipa
    echo "Done"

    cp "$IPA_PATH" "build/output/xiaophim-${VERSION}.ipa"
    echo ""
    echo "========================================"
    echo "  BUILD IPA HOAN TAT!"
    echo "========================================"
    echo ""
    echo "File: build/output/xiaophim-${VERSION}.ipa"
    echo ""
    echo "Upload file nay vao thu muc Downloads tren server"
    echo "Mo admin.php -> Bam 'Ap dung'"
    echo ""
else
    echo "Khong tim thay file IPA!"
    exit 1
fi
