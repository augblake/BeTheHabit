import json
import plistlib
import subprocess
from pathlib import Path

root = Path.cwd()
project = root / "xtool/.xtool-tmp/BeTheHabit.xcodeproj/project.pbxproj"
data = json.loads(subprocess.check_output(["plutil", "-convert", "json", "-o", "-", str(project)]))
objects = data["objects"]
app = next(v for v in objects.values() if v.get("productType") == "com.apple.product-type.application")
catalog = root / "AppIcons.xcassets"
assert (catalog / "AppIcon.appiconset/Contents.json").is_file()

ref = "BEBAB1000000000000000001"
build = "BEBAB1000000000000000002"
phase = "BEBAB1000000000000000003"
objects[ref] = dict(isa="PBXFileReference", lastKnownFileType="folder.assetcatalog", path=str(catalog), sourceTree="<absolute>")
objects[build] = dict(isa="PBXBuildFile", fileRef=ref)
objects[phase] = dict(isa="PBXResourcesBuildPhase", buildActionMask=2147483647, files=[build], runOnlyForDeploymentPostprocessing=0)
app["buildPhases"].append(phase)
objects[data["rootObject"]]["mainGroup"]
group = objects[objects[data["rootObject"]]["mainGroup"]]
group["children"].append(ref)
configs = objects[app["buildConfigurationList"]]["buildConfigurations"]
for config in configs:
    settings = objects[config]["buildSettings"]
    settings["ASSETCATALOG_COMPILER_APPICON_NAME"] = "AppIcon"
    settings["SKIP_INSTALL"] = "NO"
project.write_bytes(plistlib.dumps(data, sort_keys=False))
print("Configured app icon catalog")
