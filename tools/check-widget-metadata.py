#!/usr/bin/env python3
"""Refuse an IPA whose widget lacks the App Intents metadata WidgetKit needs.

The widget uses AppIntentConfiguration, so iOS reads ChooseHabit and ActivateHabit
from <widget>.appex/Metadata.appintents. Without that file a build still compiles,
signs, uploads and passes processing, but the widget on the phone misbehaves.

    tools/check-widget-metadata.py APP.ipa
"""
import json
import plistlib
import sys
import zipfile

REQUIRED_ACTIONS = {'ChooseHabit', 'ActivateHabit'}


def check(ipa):
    with zipfile.ZipFile(ipa) as archive:
        names = archive.namelist()
        widgets = sorted({n.split('.appex/')[0] + '.appex' for n in names
                          if '.app/PlugIns/' in n and '.appex/' in n})
        if len(widgets) != 1:
            return f'expected one widget extension, found {len(widgets)}: {widgets}'
        widget = widgets[0]
        metadata = f'{widget}/Metadata.appintents/extract.actionsdata'
        if metadata not in names:
            return f'{widget} has no Metadata.appintents'
        actions = json.loads(archive.read(metadata)).get('actions', {})
        missing = REQUIRED_ACTIONS - set(actions)
        if missing:
            return f'{widget} metadata is missing {sorted(missing)}'
        app_info = plistlib.loads(archive.read(widget.split('/PlugIns/')[0] + '/Info.plist'))
        widget_info = plistlib.loads(archive.read(f'{widget}/Info.plist'))
        for key in ('CFBundleShortVersionString', 'CFBundleVersion'):
            if app_info.get(key) != widget_info.get(key):
                return f'{key} differs: app {app_info.get(key)}, widget {widget_info.get(key)}'
        print(f"Widget metadata OK: {sorted(actions)}, "
              f"build {app_info['CFBundleShortVersionString']} ({app_info['CFBundleVersion']})")
    return None


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    problem = check(sys.argv[1])
    if problem:
        raise SystemExit(f'Widget check failed: {problem}')
