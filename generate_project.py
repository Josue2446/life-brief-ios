#!/usr/bin/env python3
"""Generate LifeBrief.xcodeproj/project.pbxproj deterministically from the source tree."""
import hashlib
import os

ROOT = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(ROOT, "LifeBrief")
PROJDIR = os.path.join(ROOT, "LifeBrief.xcodeproj")


def uuid_for(key: str) -> str:
    return hashlib.sha256(key.encode()).hexdigest()[:24].upper()


def file_type(path: str) -> str:
    if path.endswith(".swift"):
        return "sourcecode.swift"
    if path.endswith(".plist"):
        return "text.plist.xml"
    if path.endswith(".json"):
        return "text.json"
    if path.endswith(".xcassets"):
        return "folder.assetcatalog"
    return "text"


# (relative path from ROOT, build phase or None, owning group key)
FILES = [
    ("LifeBrief/LifeBriefApp.swift", "sources", "app"),
    ("LifeBrief/Info.plist", None, "app"),
    ("LifeBrief/Models/Topic.swift", "sources", "models"),
    ("LifeBrief/Models/Edition.swift", "sources", "models"),
    ("LifeBrief/Models/BriefSection.swift", "sources", "models"),
    ("LifeBrief/Models/StoryItem.swift", "sources", "models"),
    ("LifeBrief/Services/BriefStore.swift", "sources", "services"),
    ("LifeBrief/Views/FloatingTabBar.swift", "sources", "views"),
    ("LifeBrief/Views/RootView.swift", "sources", "views"),
    ("LifeBrief/Views/TopicHomeView.swift", "sources", "views"),
    ("LifeBrief/Views/Sections.swift", "sources", "views"),
    ("LifeBrief/Views/StoryDetailView.swift", "sources", "views"),
    ("LifeBrief/Views/OrganizerView.swift", "sources", "views"),
    ("LifeBrief/Views/SettingsView.swift", "sources", "views"),
    ("LifeBrief/Resources/Assets.xcassets", "resources", "resources"),
    ("LifeBrief/Resources/SeedData/portland-2026-10-02.json", "resources", "seeddata"),
    ("LifeBrief/Resources/SeedData/ai-tech-2026-10-03.json", "resources", "seeddata"),
]

# Filesystem dir backing each group; file ref paths are relative to these,
# exactly like Xcode writes them.
GROUP_DIRS = {
    "app": "LifeBrief",
    "models": "LifeBrief/Models",
    "services": "LifeBrief/Services",
    "views": "LifeBrief/Views",
    "resources": "LifeBrief/Resources",
    "seeddata": "LifeBrief/Resources/SeedData",
}

for rel, _, _ in FILES:
    assert os.path.exists(os.path.join(ROOT, rel)), f"missing: {rel}"

file_ids = {rel: uuid_for("file:" + rel) for rel, _, _ in FILES}
build_ids = {rel: uuid_for("build:" + rel) for rel, phase, _ in FILES if phase}
file_groups = {rel: g for rel, _, g in FILES}

# Groups
G_MAIN = uuid_for("group:main")
G_APP = uuid_for("group:app")
G_MODELS = uuid_for("group:models")
G_SERVICES = uuid_for("group:services")
G_VIEWS = uuid_for("group:views")
G_RES = uuid_for("group:resources")
G_SEED = uuid_for("group:seeddata")
G_PRODUCTS = uuid_for("group:products")
PRODUCT_ID = uuid_for("product:app")

# Target / phases / configs
TARGET_ID = uuid_for("target:app")
PH_SOURCES = uuid_for("phase:sources")
PH_RESOURCES = uuid_for("phase:resources")
PH_FRAMEWORKS = uuid_for("phase:frameworks")
PROJ_ID = uuid_for("project")
CFG_PROJ_DEBUG = uuid_for("cfg:proj:debug")
CFG_PROJ_RELEASE = uuid_for("cfg:proj:release")
CFG_TGT_DEBUG = uuid_for("cfg:tgt:debug")
CFG_TGT_RELEASE = uuid_for("cfg:tgt:release")
CFGLIST_PROJ = uuid_for("cfglist:proj")
CFGLIST_TGT = uuid_for("cfglist:tgt")


def group_refs(prefix):
    return [rel for rel, _, _ in FILES if rel.startswith(prefix)]


children_app = (
    [file_ids["LifeBrief/LifeBriefApp.swift"]]
    + [G_MODELS, G_SERVICES, G_VIEWS, G_RES]
    + [file_ids["LifeBrief/Info.plist"]]
)
children_models = [file_ids[r] for r in group_refs("LifeBrief/Models/")]
children_services = [file_ids[r] for r in group_refs("LifeBrief/Services/")]
children_views = [file_ids[r] for r in group_refs("LifeBrief/Views/")]
children_seed = [file_ids[r] for r in group_refs("LifeBrief/Resources/SeedData/")]


def pbx_group(gid, name, children, path=None):
    path_line = f"\t\t\tpath = {path};\n" if path else "\t\t\tname = %s;\n" % name
    kids = "".join(f"\t\t\t\t{k},\n" for k in children)
    return (
        f"\t\t{gid} = {{\n"
        f"\t\t\tisa = PBXGroup;\n"
        f"\t\t\tchildren = (\n{kids}\t\t\t);\n"
        f"{path_line}"
        f"\t\t\tsourceTree = \"<group>\";\n"
        f"\t\t}};\n"
    )


def file_ref(rel):
    fid = file_ids[rel]
    full_name = os.path.basename(rel)
    # Path relative to the owning group, like Xcode writes it.
    name = os.path.relpath(rel, GROUP_DIRS[file_groups[rel]])
    return (
        f"\t\t{fid} /* {full_name} */ = {{isa = PBXFileReference; "
        f"lastKnownFileType = {file_type(rel)}; name = {full_name}; path = {name}; "
        f"sourceTree = \"<group>\"; }};\n"
    )


objects = []
objects.append("/* Begin PBXBuildFile section */\n")
for rel, phase, _ in FILES:
    if not phase:
        continue
    objects.append(
        f"\t\t{build_ids[rel]} /* {os.path.basename(rel)} in {'Sources' if phase == 'sources' else 'Resources'} */ "
        f"= {{isa = PBXBuildFile; fileRef = {file_ids[rel]} /* {os.path.basename(rel)} */; }};\n"
    )
objects.append("/* End PBXBuildFile section */\n\n")

objects.append("/* Begin PBXFileReference section */\n")
for rel, _, _ in FILES:
    objects.append(file_ref(rel))
objects.append(
    f"\t\t{PRODUCT_ID} /* LifeBrief.app */ = {{isa = PBXFileReference; "
    f"explicitFileType = wrapper.application; includeInIndex = 0; "
    f'path = "LifeBrief.app"; sourceTree = BUILT_PRODUCTS_DIR; }};\n'
)
objects.append("/* End PBXFileReference section */\n\n")

objects.append("/* Begin PBXFrameworksBuildPhase section */\n")
objects.append(
    f"\t\t{PH_FRAMEWORKS} /* Frameworks */ = {{isa = PBXFrameworksBuildPhase; "
    f"buildActionMask = 2147483647; files = (\n\t\t); runOnlyForDeploymentPostprocessing = 0; }};\n"
)
objects.append("/* End PBXFrameworksBuildPhase section */\n\n")

objects.append("/* Begin PBXGroup section */\n")
objects.append(pbx_group(G_MAIN, None, [G_APP, G_PRODUCTS]))
objects[-1] = objects[-1].replace('name = None;', '').replace('path = None;', '')
objects.append(pbx_group(G_APP, "LifeBrief", children_app, path="LifeBrief"))
objects.append(pbx_group(G_MODELS, "Models", children_models, path="Models"))
objects.append(pbx_group(G_SERVICES, "Services", children_services, path="Services"))
objects.append(pbx_group(G_VIEWS, "Views", children_views, path="Views"))
objects.append(pbx_group(G_RES, "Resources", [file_ids["LifeBrief/Resources/Assets.xcassets"], G_SEED], path="Resources"))
objects.append(pbx_group(G_SEED, "SeedData", children_seed, path="SeedData"))
objects.append(pbx_group(G_PRODUCTS, "Products", [PRODUCT_ID]))
objects.append("/* End PBXGroup section */\n\n")

objects.append("/* Begin PBXNativeTarget section */\n")
objects.append(
    f"\t\t{TARGET_ID} /* LifeBrief */ = {{\n"
    f"\t\t\tisa = PBXNativeTarget;\n"
    f"\t\t\tbuildConfigurationList = {CFGLIST_TGT} /* Build configuration list for PBXNativeTarget \"LifeBrief\" */;\n"
    f"\t\t\tbuildPhases = (\n"
    f"\t\t\t\t{PH_SOURCES} /* Sources */,\n"
    f"\t\t\t\t{PH_FRAMEWORKS} /* Frameworks */,\n"
    f"\t\t\t\t{PH_RESOURCES} /* Resources */,\n"
    f"\t\t\t);\n"
    f"\t\t\tbuildRules = (\n"
    f"\t\t\t);\n"
    f"\t\t\tdependencies = (\n"
    f"\t\t\t);\n"
    f"\t\t\tname = LifeBrief;\n"
    f"\t\t\tproductName = LifeBrief;\n"
    f"\t\t\tproductReference = {PRODUCT_ID} /* LifeBrief.app */;\n"
    f"\t\t\tproductType = \"com.apple.product-type.application\";\n"
    f"\t\t}};\n"
)
objects.append("/* End PBXNativeTarget section */\n\n")

objects.append("/* Begin PBXProject section */\n")
objects.append(
    f"\t\t{PROJ_ID} /* Project object */ = {{\n"
    f"\t\t\tisa = PBXProject;\n"
    f"\t\t\tattributes = {{\n"
    f"\t\t\t\tBuildIndependentTargetsInParallel = 1;\n"
    f"\t\t\t\tLastUpgradeCheck = 2600;\n"
    f"\t\t\t\tTargetAttributes = {{\n"
    f"\t\t\t\t\t{TARGET_ID} = {{\n"
    f"\t\t\t\t\t\tCreatedOnToolsVersion = 26.0;\n"
    f"\t\t\t\t\t}};\n"
    f"\t\t\t\t}};\n"
    f"\t\t\t}};\n"
    f"\t\t\tbuildConfigurationList = {CFGLIST_PROJ} /* Build configuration list for PBXProject \"LifeBrief\" */;\n"
    f"\t\t\tcompatibilityVersion = \"Xcode 14.0\";\n"
    f"\t\t\tdevelopmentRegion = en;\n"
    f"\t\t\thasScannedForEncodings = 0;\n"
    f"\t\t\tknownRegions = (\n\t\t\t\ten,\n\t\t\t);\n"
    f"\t\t\tmainGroup = {G_MAIN};\n"
    f"\t\t\tproductRefGroup = {G_PRODUCTS} /* Products */;\n"
    f"\t\t\tprojectDirPath = \"\";\n"
    f"\t\t\tprojectRoot = \"\";\n"
    f"\t\t\ttargets = (\n\t\t\t\t{TARGET_ID} /* LifeBrief */,\n\t\t\t);\n"
    f"\t\t}};\n"
)
objects.append("/* End PBXProject section */\n\n")

objects.append("/* Begin PBXResourcesBuildPhase section */\n")
res_files = "".join(f"\t\t\t\t{build_ids[rel]} /* {os.path.basename(rel)} in Resources */,\n"
                    for rel, phase, _ in FILES if phase == "resources")
objects.append(
    f"\t\t{PH_RESOURCES} /* Resources */ = {{isa = PBXResourcesBuildPhase; "
    f"buildActionMask = 2147483647; files = (\n{res_files}\t\t); "
    f"runOnlyForDeploymentPostprocessing = 0; }};\n"
)
objects.append("/* End PBXResourcesBuildPhase section */\n\n")

objects.append("/* Begin PBXSourcesBuildPhase section */\n")
src_files = "".join(f"\t\t\t\t{build_ids[rel]} /* {os.path.basename(rel)} in Sources */,\n"
                    for rel, phase, _ in FILES if phase == "sources")
objects.append(
    f"\t\t{PH_SOURCES} /* Sources */ = {{isa = PBXSourcesBuildPhase; "
    f"buildActionMask = 2147483647; files = (\n{src_files}\t\t); "
    f"runOnlyForDeploymentPostprocessing = 0; }};\n"
)
objects.append("/* End PBXSourcesBuildPhase section */\n\n")


def xcconfig(cid, name, settings):
    lines = "".join(f"\t\t\t\t{k} = {v};\n" for k, v in settings.items() if v != "")
    return (
        f"\t\t{cid} /* {name} */ = {{\n"
        f"\t\t\tisa = XCBuildConfiguration;\n"
        f"\t\t\tbuildSettings = {{\n{lines}\t\t\t}};\n"
        f"\t\t\tname = {name};\n"
        f"\t\t}};\n"
    )


objects.append("/* Begin XCBuildConfiguration section */\n")
proj_settings = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "CLANG_ANALYZER_NONNULL": "YES",
    "CLANG_CXX_LANGUAGE_STANDARD": '"gnu++20"',
    "COPY_PHASE_STRIP": "NO",
    "DEBUG_INFORMATION_FORMAT": '"dwarf-with-dsym"',
    "ENABLE_STRICT_OBJCMESSAGESEND": "YES",
    "GCC_C_LANGUAGE_STANDARD": "gnu17",
    "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
    "MTL_FAST_MATH": "YES",
    "PRODUCT_NAME": '"$(TARGET_NAME)"',
    "SWIFT_VERSION": "5.0",
}
objects.append(xcconfig(CFG_PROJ_DEBUG, "Debug", {**proj_settings, "ONLY_ACTIVE_ARCH": "YES"}))
objects.append(xcconfig(CFG_PROJ_RELEASE, "Release", proj_settings))

tgt_settings = {
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
    "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "YES",
    "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
    "CODE_SIGN_STYLE": "Automatic",
    "DEVELOPMENT_TEAM": "",
    "ENABLE_PREVIEWS": "YES",
    "GENERATE_INFOPLIST_FILE": "NO",
    "INFOPLIST_FILE": "LifeBrief/Info.plist",
    "IPHONEOS_DEPLOYMENT_TARGET": "26.0",
    "LD_RUNPATH_SEARCH_PATHS": '"$(inherited) @executable_path/Frameworks"',
    "PRODUCT_BUNDLE_IDENTIFIER": "com.example.lifebrief",
    "PRODUCT_NAME": '"$(TARGET_NAME)"',
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "SWIFT_VERSION": "5.0",
    "TARGETED_DEVICE_FAMILY": '"1,2"',
}
objects.append(xcconfig(CFG_TGT_DEBUG, "Debug", tgt_settings))
objects.append(xcconfig(CFG_TGT_RELEASE, "Release", tgt_settings))
objects.append("/* End XCBuildConfiguration section */\n\n")

objects.append("/* Begin XCConfigurationList section */\n")
for list_id, cfgs, comment in [
    (CFGLIST_PROJ, [CFG_PROJ_DEBUG, CFG_PROJ_RELEASE], 'PBXProject "LifeBrief"'),
    (CFGLIST_TGT, [CFG_TGT_DEBUG, CFG_TGT_RELEASE], 'PBXNativeTarget "LifeBrief"'),
]:
    objects.append(
        f"\t\t{list_id} /* Build configuration list for {comment} */ = {{\n"
        f"\t\t\tisa = XCConfigurationList;\n"
        f"\t\t\tbuildConfigurations = (\n"
        f"\t\t\t\t{cfgs[0]} /* Debug */,\n"
        f"\t\t\t\t{cfgs[1]} /* Release */,\n"
        f"\t\t\t);\n"
        f"\t\t\tdefaultConfigurationIsVisible = 0;\n"
        f"\t\t\tdefaultConfigurationName = Release;\n"
        f"\t\t}};\n"
    )
objects.append("/* End XCConfigurationList section */\n")

pbxproj = (
    "// !$*UTF8*$!\n"
    "{\n"
    "\tarchiveVersion = 1;\n"
    "\tclasses = {\n"
    "\t};\n"
    "\tobjectVersion = 56;\n"
    "\tobjects = {\n"
    + "".join(objects) +
    "\t};\n"
    f"\trootObject = {PROJ_ID} /* Project object */;\n"
    "}\n"
)

os.makedirs(PROJDIR, exist_ok=True)
with open(os.path.join(PROJDIR, "project.pbxproj"), "w") as f:
    f.write(pbxproj)
print("wrote", os.path.join(PROJDIR, "project.pbxproj"))
