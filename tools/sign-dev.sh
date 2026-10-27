#!/usr/bin/env bash
# Sign a built .app (and its PlugIns/*.appex) with an iOS Development identity and
# its provisioning profiles, then write an .ipa that `pymobiledevice3 apps install`
# can install. For a device that has no xtool next to it (the build host signs).
#   tools/sign-dev.sh APP.app OUT.ipa [DEV_DIR]
# DEV_DIR (default ~/.config/omarchy-apple-dev/development) holds key.pem, cert.der
# and <bundle id>.mobileprovision per bundle (tools/provision-dev.py writes them).
set -euo pipefail
app=${1:?usage: sign-dev.sh APP.app OUT.ipa [DEV_DIR]}
ipa=${2:?usage: sign-dev.sh APP.app OUT.ipa [DEV_DIR]}
dev=${3:-$HOME/.config/omarchy-apple-dev/development}
[ -d "$app" ] || { echo "no such app: $app" >&2; exit 1; }
source_app=$(realpath "$app")
build_root=$(realpath "$source_app/../..")

sign_one() { # bundle dir
  local dir=$1 bid prof ent team
  bid=$(python3 -c 'import plistlib,sys; print(plistlib.load(open(sys.argv[1]+"/Info.plist","rb"))["CFBundleIdentifier"])' "$dir")
  prof=$dev/$bid.mobileprovision
  [ -f "$prof" ] || { echo "no profile for $bid in $dev" >&2; exit 1; }
  ent=$(mktemp)
  team=$(python3 - "$prof" "$ent" <<'PY'
import plistlib, sys
raw = open(sys.argv[1], "rb").read()
d = plistlib.loads(raw[raw.index(b"<?xml"):raw.rindex(b"</plist>") + 8])
ent = d["Entitlements"]
if "com.apple.developer.icloud-container-identifiers" in ent:
    ent["com.apple.developer.icloud-container-environment"] = "Development"
    ent["com.apple.developer.icloud-services"] = ["CloudKit"]
plistlib.dump(ent, open(sys.argv[2], "wb"))
print(d["TeamIdentifier"][0])
PY
  )
  [[ "$team" =~ ^[A-Z0-9]{10}$ ]] || { echo "bad team id '$team'" >&2; exit 1; }
  cp "$prof" "$dir/embedded.mobileprovision"
  rcodesign sign --pem-file "$dev/key.pem" --certificate-der-file "$dev/cert.der" \
    --team-name "$team" --timestamp-url none --entitlements-xml-file "$ent" "$dir"
  rm -f "$ent"
}

ipa=$(realpath -m "$ipa")
stage=$(mktemp -d)
mkdir "$stage/Payload"
cp -a "$app" "$stage/Payload/"
# SwiftPM build outputs are read-only; rcodesign writes _CodeSignature into
# every bundle it signs.
chmod -R u+w "$stage/Payload"
app=$stage/Payload/$(basename "$app")

# xtool's development build omits Xcode's App Intents extraction step. Without
# this metadata, WidgetKit can display Start/Stop while its action does nothing.
widget=$app/PlugIns/BeHabitWidget.appex
if [ -d "$widget" ]; then
  metadata_tool=${APPINTENTS_META_TOOL:-$(realpath "$build_root/../../../omarchy-apple-dev/tools/appintentsmeta.py")}
  sdk=$(find "$HOME/.cache/xtool" -maxdepth 1 -type d -name 'darwin-iPhoneOS*.xtoolsdk' | sort -V | tail -n 1)
  [ -f "$metadata_tool" ] && [ -n "$sdk" ] || { echo "App Intents metadata tool or iOS SDK missing" >&2; exit 1; }
  const_values=$build_root/.build/out/Intermediates.noindex/HabitQuest.build/Debug-iphoneos/BeHabitWidget-t.build/Objects-normal/arm64/BeHabitWidget.swiftconstvalues
  [ -f "$const_values" ] || { echo "widget App Intents constants missing: $const_values" >&2; exit 1; }
  widget_id=$(python3 -c 'import plistlib,sys; print(plistlib.load(open(sys.argv[1],"rb"))["CFBundleIdentifier"])' "$widget/Info.plist")
  python3 "$metadata_tool" --module-name BeHabitWidget --bundle-identifier "$widget_id" \
    --output "$widget" --binary-file "$widget/BeHabitWidget" \
    --sdk-root "$sdk/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk" \
    --const-values "$const_values"
  [ -s "$widget/Metadata.appintents/extract.actionsdata" ] || { echo "widget App Intents metadata missing" >&2; exit 1; }
fi

shopt -s nullglob
for f in "$app"/Frameworks/*.framework "$app"/Frameworks/*.dylib; do
  rcodesign sign --pem-file "$dev/key.pem" --certificate-der-file "$dev/cert.der" --timestamp-url none "$f"
done
for appex in "$app"/PlugIns/*.appex; do sign_one "$appex"; done
shopt -u nullglob
sign_one "$app"
rm -f "$ipa"
(cd "$stage" && zip -qry "$ipa" Payload)
echo "wrote $ipa (signed copy left in $stage)"
