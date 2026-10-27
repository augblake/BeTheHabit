#!/usr/bin/env python3
"""Prepare the official CloudKit release using the installed Linux Apple toolchain.

Requires ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_PATH. Does not upload.
"""
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
toolchain = Path(os.environ.get('APPLE_TOOLCHAIN_ROOT', root.parent / 'omarchy-apple-dev'))
for key in ('ASC_KEY_ID', 'ASC_ISSUER_ID', 'ASC_KEY_PATH'):
    if not os.environ.get(key):
        raise SystemExit(f'Missing {key}')
stage = root / 'xtool/testflight-source'
stage.mkdir(parents=True, exist_ok=True)
for name in ('Sources', 'Tests', 'Package.swift', 'AppIcons.xcassets', 'AppIcon.png', 'PrivacyInfo.xcprivacy', 'WidgetInfo.plist'):
    dest = stage / name
    if dest.is_symlink():
        dest.unlink()
    if not dest.exists():
        if name == 'AppIcon.png':
            shutil.copy2(root / name, dest)
        else:
            dest.symlink_to(root / name)
info = plistlib.loads((root / 'AppInfo.plist').read_bytes())
info['BeHabitCloudSharingEnabled'] = True
info['BeHabitCloudEnvironment'] = 'Production'
info['CFBundleShortVersionString'] = '1.0.1'
(stage / 'AppInfo.plist').write_bytes(plistlib.dumps(info))
config = (root / 'xtool.yml').read_text()
config = config.replace('bundleID: com.example.HabitQuest', 'bundleID: XTL-MXQT5L922T.com.example.HabitQuest')
config = config.replace('entitlementsPath: BeHabit.entitlements', 'entitlementsPath: BeHabit.CloudKit.entitlements')
(stage / 'xtool.yml').write_text(config)
for name in ('BeHabit.CloudKit.entitlements', 'BeHabitWidget.entitlements'):
    data = plistlib.loads((root / name).read_bytes())
    if 'com.apple.developer.icloud-container-environment' in data:
        data['com.apple.developer.icloud-container-environment'] = 'Production'
    (stage / name).write_bytes(plistlib.dumps(data))
# Keep the installed generic toolchain unchanged. Its current signer omits CloudKit
# entitlements; extend only this private staging copy and verify every grant.
pipeline = root / 'xtool/release-tools'
(pipeline / 'tools').mkdir(parents=True, exist_ok=True)
for helper in (toolchain / 'tools').glob('*.py'):
    shutil.copy2(helper, pipeline / 'tools' / helper.name)
ship = (toolchain / 'ship.sh').read_text()
ship = ship.replace('echo "== 6. Distribution identity and signature =="', 'cp PrivacyInfo.xcprivacy "$app/PrivacyInfo.xcprivacy"\necho "== 6. Distribution identity and signature =="')
(pipeline / 'ship.sh').write_text(ship)
asc = pipeline / 'tools/asc.py'
source = asc.read_text()
needle = '        entitlements["get-task-allow"] = False\n'
assert source.count(needle) == 1
source = source.replace(needle, needle + '''        if path == Path(app_dir):
            requested = plistlib.loads(Path(os.environ["ASC_ENTITLEMENTS_PATH"]).read_bytes())
            for key in ("com.apple.developer.icloud-container-identifiers",
                        "com.apple.developer.icloud-services",
                        "com.apple.developer.icloud-container-environment"):
                value = requested[key]
                grant = granted.get(key)
                values = value if isinstance(value, list) else [value]
                grants = grant if isinstance(grant, list) else [grant]
                if not all(v in grants or "*" in grants for v in values):
                    die(f"profile for {ident} does not grant {key}")
                entitlements[key] = value
''')
asc.write_text(source)
env = dict(os.environ)
env['XDG_CACHE_HOME'] = str(root / 'xtool/cache')
env['XDG_CONFIG_HOME'] = str(Path.home() / '.config')
env['ASC_IDENTITY_DIR'] = str(root / 'xtool/distribution')
env['ASC_ENTITLEMENTS_PATH'] = str(stage / 'BeHabit.CloudKit.entitlements')
env['APP_GROUPS'] = 'group.XTL-MXQT5L922T.com.example.behabit'
subprocess.run(['bash', str(pipeline / 'ship.sh')], cwd=stage, env=env, check=True)
sys.path.insert(0, str(pipeline / 'tools'))
from asc import signature_blob

app = stage / 'xtool/HabitQuest.app'
signed = plistlib.loads(signature_blob('rcodesign', app / 'HabitQuest', b'\xfa\xde\x71\x71'))
requested = plistlib.loads((stage / 'BeHabit.CloudKit.entitlements').read_bytes())
for key, value in requested.items():
    if signed.get(key) != value:
        raise SystemExit(f'Signed app does not match requested entitlement: {key}')
widget = app / 'PlugIns/BeHabitWidget.appex'
widget_signed = plistlib.loads(signature_blob('rcodesign', widget / 'BeHabitWidget', b'\xfa\xde\x71\x71'))
group_key = 'com.apple.security.application-groups'
if widget_signed.get(group_key) != requested[group_key]:
    raise SystemExit('Widget App Group does not match the app')
print(f'Ready for upload: {stage / "xtool/HabitQuest.ipa"}')
