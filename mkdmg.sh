#!/bin/sh
set -e 

VOLNAME="Audiobook Binder"
APPNAME=AudiobookBinder
INSTALL_TARGET="AudioBookBinder.app"
INSTALL_SUBTARGET="abbinder"
TARGET_BUILD_DIR=/Users/gonzo/Projects/AudioBookBinder/build/Release
VERSION=`grep -A 1 CFBundleShortVersionString AudioBookBinder-Info.plist  | tail -1 | sed 's/[^0-9]*>//' | sed 's/<.*//'`

rm -Rf build
xcodebuild -configuration Release -alltargets

if [ -e "/Volumes/$VOLNAME" ]; then
	echo "Detaching old $VOLNAME"
	hdiutil detach "/Volumes/$VOLNAME"
fi

rm -f "$TARGET_BUILD_DIR/$VOLNAME.dmg" "$TARGET_BUILD_DIR/${VOLNAME}_big.dmg"

# create/attach dmg for distribution
echo "Creating blank DMG"

hdiutil create -size 15000k -volname "$VOLNAME" -attach -fs HFS+ "$TARGET_BUILD_DIR/${VOLNAME}_big.dmg"

cp -R "$TARGET_BUILD_DIR/$INSTALL_TARGET" "/Volumes/$VOLNAME/"
cp "$TARGET_BUILD_DIR/$INSTALL_SUBTARGET" "/Volumes/$VOLNAME/$INSTALL_TARGET/Contents/MacOS/"

cp -R README "Chapters - HowTo.webloc" "/Volumes/$VOLNAME/"

ls -la "/Volumes/$VOLNAME/"
hdiutil detach "/Volumes/$VOLNAME"

echo "Compresing disk image"
rm -f "$APPNAME-$VERSION.dmg"
hdiutil convert -format UDZO -o "$APPNAME-$VERSION.dmg" "$TARGET_BUILD_DIR/${VOLNAME}_big.dmg"

rm -f "$TARGET_BUILD_DIR/${VOLNAME}_big.dmg"
