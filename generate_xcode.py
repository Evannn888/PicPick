#!/usr/bin/env python3
"""Generate PicPick.xcodeproj/project.pbxproj — v2 (fixed)."""

import os, hashlib

PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))
PBXPROJ_DIR = os.path.join(PROJECT_DIR, "PicPick.xcodeproj")
PBXPROJ_PATH = os.path.join(PBXPROJ_DIR, "project.pbxproj")

def uid(seed):
    return hashlib.sha256(seed.encode()).hexdigest()[:24].upper()

# ── Files ─────────────────────────────────────────────────────────
src = [
    ("PicPick/App", "PicPickApp.swift"),
    ("PicPick/Models", "ImageFile.swift"),
    ("PicPick/Models", "FavoritePhoto.swift"),
    ("PicPick/ViewModels", "PhotoGridViewModel.swift"),
    ("PicPick/ViewModels", "PhotoViewerViewModel.swift"),
    ("PicPick/ViewModels", "FavoritesViewModel.swift"),
    ("PicPick/Views", "ContentView.swift"),
    ("PicPick/Views", "PhotoGridView.swift"),
    ("PicPick/Views", "PhotoGridCell.swift"),
    ("PicPick/Views", "PhotoViewer.swift"),
    ("PicPick/Views", "PhotoCellView.swift"),
    ("PicPick/Views", "PhotoPageViewController.swift"),
    ("PicPick/Views", "ZoomableScrollView.swift"),
    ("PicPick/Services", "FileSystemService.swift"),
    ("PicPick/Services", "ImageCacheService.swift"),
    ("PicPick/Services", "ImageLoadingService.swift"),
    ("PicPick/Services", "PersistenceService.swift"),
    ("PicPick/Cache", "ImageCache.swift"),
]

tests = [
    "FileSystemServiceTests.swift",
    "ImageCacheServiceTests.swift",
    "PhotoViewerViewModelTests.swift",
    "FavoritesViewModelTests.swift",
]

groups = ["App", "Models", "ViewModels", "Views", "Services", "Cache", "Persistence", "Resources"]

# ── UUID registry ─────────────────────────────────────────────────
U = {}
def add(k): U[k] = uid(k)

for f, n in src:
    add(f"bf:{f}/{n}")
    add(f"fr:{f}/{n}")
for n in tests:
    add(f"bf:PicPickTests/{n}")
    add(f"fr:PicPickTests/{n}")
add("fr:Info.plist")
add("bf:Info.plist")
add("prod:app")
add("prod:tests")
for g in groups:
    add(f"grp:{g}")
add("grp:PicPick")
add("grp:Tests")
add("grp:Products")
add("grp:main")
add("phs:src:app")
add("phs:fwk:app")
add("phs:res:app")
add("phs:src:tests")
add("phs:fwk:tests")
add("tgt:app")
add("tgt:tests")
add("cl:proj")
add("cl:app")
add("cl:tests")
add("cfg:proj:D")
add("cfg:proj:R")
add("cfg:app:D")
add("cfg:app:R")
add("cfg:tests:D")
add("cfg:tests:R")
add("proj")
add("proxy:app")
add("tdep:tests")

# ── Helpers ───────────────────────────────────────────────────────
def S(*lines):
    return "\n".join(lines)

def dict_isa(isa, entries, tail=""):
    inner = "\n".join(f"\t\t\t{line}" for line in entries)
    return f"\t\t{{{tail}\n\t\t\tisa = {isa};\n{inner}\n\t\t}};"

# ── Sections ──────────────────────────────────────────────────────

def PBXBuildFile():
    lines = []
    for f, n in src:
        lines.append(f"\t\t{U[f'bf:{f}/{n}']} /* {n} in Sources */ = {{isa = PBXBuildFile; fileRef = {U[f'fr:{f}/{n}']} /* {n} */; }};")
    for n in tests:
        lines.append(f"\t\t{U[f'bf:PicPickTests/{n}']} /* {n} in Sources */ = {{isa = PBXBuildFile; fileRef = {U[f'fr:PicPickTests/{n}']} /* {n} */; }};")
    return S(*lines)

def PBXFileReference():
    lines = []
    for f, n in src:
        lines.append(f"\t\t{U[f'fr:{f}/{n}']} /* {n} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {n}; sourceTree = \"<group>\"; }};")
    for n in tests:
        lines.append(f"\t\t{U[f'fr:PicPickTests/{n}']} /* {n} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {n}; sourceTree = \"<group>\"; }};")
    lines.append(f"\t\t{U['fr:Info.plist']} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};")
    lines.append(f"\t\t{U['prod:app']} /* PicPick.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = PicPick.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
    lines.append(f"\t\t{U['prod:tests']} /* PicPickTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = PicPickTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};")
    return S(*lines)

def PBXGroup():
    lines = []

    # --- main ---
    lines.append(f"\t\t{U['grp:main']} = {{")
    lines.append(f"\t\t\tisa = PBXGroup;")
    lines.append(f"\t\t\tchildren = (")
    lines.append(f"\t\t\t\t{U['grp:PicPick']} /* PicPick */,")
    lines.append(f"\t\t\t\t{U['grp:Tests']} /* PicPickTests */,")
    lines.append(f"\t\t\t\t{U['grp:Products']} /* Products */,")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t\tsourceTree = \"<group>\";")
    lines.append(f"\t\t}};")

    # --- PicPick ---
    lines.append(f"\t\t{U['grp:PicPick']} = {{")
    lines.append(f"\t\t\tisa = PBXGroup;")
    lines.append(f"\t\t\tchildren = (")
    for g in groups:
        lines.append(f"\t\t\t\t{U[f'grp:{g}']} /* {g} */,")
    lines.append(f"\t\t\t\t{U['fr:Info.plist']} /* Info.plist */,")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t\tpath = PicPick;")
    lines.append(f"\t\t\tsourceTree = \"<group>\";")
    lines.append(f"\t\t}};")

    # --- subgroups ---
    sg = {
        "App": [("PicPick/App", "PicPickApp.swift")],
        "Models": [("PicPick/Models", "ImageFile.swift"), ("PicPick/Models", "FavoritePhoto.swift")],
        "ViewModels": [("PicPick/ViewModels", "PhotoGridViewModel.swift"), ("PicPick/ViewModels", "PhotoViewerViewModel.swift"), ("PicPick/ViewModels", "FavoritesViewModel.swift")],
        "Views": [("PicPick/Views", n) for n in ["ContentView.swift","PhotoGridView.swift","PhotoGridCell.swift","PhotoViewer.swift","PhotoCellView.swift","PhotoPageViewController.swift","ZoomableScrollView.swift"]],
        "Services": [("PicPick/Services", n) for n in ["FileSystemService.swift","ImageCacheService.swift","ImageLoadingService.swift","PersistenceService.swift"]],
        "Cache": [("PicPick/Cache", "ImageCache.swift")],
        "Persistence": [],
        "Resources": [],
    }
    for g in groups:
        kids = [U[f"fr:{f}/{n}"] for f, n in sg[g]]
        lines.append(f"\t\t{U[f'grp:{g}']} = {{")
        lines.append(f"\t\t\tisa = PBXGroup;")
        lines.append(f"\t\t\tchildren = (")
        for k in kids:
            lines.append(f"\t\t\t\t{k} /* */,")
        lines.append(f"\t\t\t);")
        lines.append(f"\t\t\tpath = {g};")
        lines.append(f"\t\t\tsourceTree = \"<group>\";")
        lines.append(f"\t\t}};")

    # --- Tests ---
    lines.append(f"\t\t{U['grp:Tests']} = {{")
    lines.append(f"\t\t\tisa = PBXGroup;")
    lines.append(f"\t\t\tchildren = (")
    for n in tests:
        lines.append(f"\t\t\t\t{U[f'fr:PicPickTests/{n}']} /* {n} */,")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t\tpath = PicPickTests;")
    lines.append(f"\t\t\tsourceTree = \"<group>\";")
    lines.append(f"\t\t}};")

    # --- Products ---
    lines.append(f"\t\t{U['grp:Products']} = {{")
    lines.append(f"\t\t\tisa = PBXGroup;")
    lines.append(f"\t\t\tchildren = (")
    lines.append(f"\t\t\t\t{U['prod:app']} /* PicPick.app */,")
    lines.append(f"\t\t\t\t{U['prod:tests']} /* PicPickTests.xctest */,")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t\tname = Products;")
    lines.append(f"\t\t\tsourceTree = \"<group>\";")
    lines.append(f"\t\t}};")

    return S(*lines)

def PBXNativeTarget():
    lines = []

    # App target
    lines.append(f"\t\t{U['tgt:app']} /* PicPick */ = {{")
    lines.append(f"\t\t\tisa = PBXNativeTarget;")
    lines.append(f"\t\t\tbuildConfigurationList = {U['cl:app']} /* Build configuration list for PBXNativeTarget \"PicPick\" */;")
    lines.append(f"\t\t\tbuildPhases = (")
    lines.append(f"\t\t\t\t{U['phs:src:app']} /* Sources */,")
    lines.append(f"\t\t\t\t{U['phs:fwk:app']} /* Frameworks */,")
    lines.append(f"\t\t\t\t{U['phs:res:app']} /* Resources */,")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t\tbuildRules = (")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t\tdependencies = (")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t\tname = PicPick;")
    lines.append(f"\t\t\tproductName = PicPick;")
    lines.append(f"\t\t\tproductReference = {U['prod:app']} /* PicPick.app */;")
    lines.append(f"\t\t\tproductType = \"com.apple.product-type.application\";")
    lines.append(f"\t\t}};")

    # Test target
    lines.append(f"\t\t{U['tgt:tests']} /* PicPickTests */ = {{")
    lines.append(f"\t\t\tisa = PBXNativeTarget;")
    lines.append(f"\t\t\tbuildConfigurationList = {U['cl:tests']} /* Build configuration list for PBXNativeTarget \"PicPickTests\" */;")
    lines.append(f"\t\t\tbuildPhases = (")
    lines.append(f"\t\t\t\t{U['phs:src:tests']} /* Sources */,")
    lines.append(f"\t\t\t\t{U['phs:fwk:tests']} /* Frameworks */,")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t\tbuildRules = (")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t\tdependencies = (")
    lines.append(f"\t\t\t\t{U['tdep:tests']} /* PBXTargetDependency */,")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t\tname = PicPickTests;")
    lines.append(f"\t\t\tproductName = PicPickTests;")
    lines.append(f"\t\t\tproductReference = {U['prod:tests']} /* PicPickTests.xctest */;")
    lines.append(f"\t\t\tproductType = \"com.apple.product-type.bundle.unit-test\";")
    lines.append(f"\t\t}};")

    return S(*lines)

def PBXProject():
    return f"""\t\t{U['proj']} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1600;
\t\t\t\tLastUpgradeCheck = 1600;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{U['tgt:app']} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;
\t\t\t\t\t}};
\t\t\t\t\t{U['tgt:tests']} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;
\t\t\t\t\t\tTestTargetID = {U['tgt:app']};
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {U['cl:proj']} /* Build configuration list for PBXProject \"PicPick\" */;
\t\t\tcompatibilityVersion = \"Xcode 14.0\";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {U['grp:main']};
\t\t\tproductRefGroup = {U['grp:Products']} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{U['tgt:app']} /* PicPick */,
\t\t\t\t{U['tgt:tests']} /* PicPickTests */,
\t\t\t);
\t\t}};"""

def PBXSourcesBuildPhase():
    lines = []

    # App sources
    lines.append(f"\t\t{U['phs:src:app']} /* Sources */ = {{")
    lines.append(f"\t\t\tisa = PBXSourcesBuildPhase;")
    lines.append(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append(f"\t\t\tfiles = (")
    for f, n in src:
        lines.append(f"\t\t\t\t{U[f'bf:{f}/{n}']} /* {n} in Sources */,")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t}};")

    # App frameworks
    lines.append(f"\t\t{U['phs:fwk:app']} /* Frameworks */ = {{")
    lines.append(f"\t\t\tisa = PBXFrameworksBuildPhase;")
    lines.append(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append(f"\t\t\tfiles = (")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t}};")

    # App resources
    lines.append(f"\t\t{U['phs:res:app']} /* Resources */ = {{")
    lines.append(f"\t\t\tisa = PBXResourcesBuildPhase;")
    lines.append(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append(f"\t\t\tfiles = (")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t}};")

    # Test sources
    lines.append(f"\t\t{U['phs:src:tests']} /* Sources */ = {{")
    lines.append(f"\t\t\tisa = PBXSourcesBuildPhase;")
    lines.append(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append(f"\t\t\tfiles = (")
    for n in tests:
        lines.append(f"\t\t\t\t{U[f'bf:PicPickTests/{n}']} /* {n} in Sources */,")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t}};")

    # Test frameworks
    lines.append(f"\t\t{U['phs:fwk:tests']} /* Frameworks */ = {{")
    lines.append(f"\t\t\tisa = PBXFrameworksBuildPhase;")
    lines.append(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append(f"\t\t\tfiles = (")
    lines.append(f"\t\t\t);")
    lines.append(f"\t\t}};")

    return S(*lines)

def PBXContainerItemProxy():
    return f"""\t\t{U['proxy:app']} /* PBXContainerItemProxy */ = {{
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = {U['proj']} /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = {U['tgt:app']};
\t\t\tremoteInfo = PicPick;
\t\t}};"""

def PBXTargetDependency():
    return f"""\t\t{U['tdep:tests']} /* PBXTargetDependency */ = {{
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = {U['tgt:app']} /* PicPick */;
\t\t\ttargetProxy = {U['proxy:app']} /* PBXContainerItemProxy */;
\t\t}};"""

def XCBuildConfiguration():
    lines = []

    def cfg(id_, name, entries):
        inner = "\n".join(f"\t\t\t\t{line}" for line in entries)
        return f"\t\t{id_} /* {name} */ = {{\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {{\n{inner}\n\t\t\t}};\n\t\t\tname = {name};\n\t\t}};"

    debug_flag = lambda b: "YES" if b else "NO"

    # Project Debug
    lines.append(cfg(U["cfg:proj:D"], "Debug", [
        'ALWAYS_SEARCH_USER_PATHS = NO;',
        'ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;',
        'CLANG_ANALYZER_NONNULL = YES;',
        'CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";',
        'CLANG_ENABLE_MODULES = YES;',
        'CLANG_ENABLE_OBJC_ARC = YES;',
        'COPY_PHASE_STRIP = NO;',
        'DEBUG_INFORMATION_FORMAT = dwarf;',
        'ENABLE_STRICT_OBJC_MSGSEND = YES;',
        'ENABLE_TESTABILITY = YES;',
        'ENABLE_USER_SCRIPT_SANDBOXING = YES;',
        'GCC_OPTIMIZATION_LEVEL = 0;',
        'IPHONEOS_DEPLOYMENT_TARGET = 18.0;',
        'LOCALIZATION_PREFERS_STRING_CATALOGS = YES;',
        'MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;',
        'ONLY_ACTIVE_ARCH = YES;',
        'SDKROOT = iphoneos;',
        'SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;',
        'SWIFT_OPTIMIZATION_LEVEL = "-Onone";',
        'SWIFT_VERSION = 6.0;',
    ]))

    # Project Release
    lines.append(cfg(U["cfg:proj:R"], "Release", [
        'ALWAYS_SEARCH_USER_PATHS = NO;',
        'ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;',
        'CLANG_ANALYZER_NONNULL = YES;',
        'CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";',
        'CLANG_ENABLE_MODULES = YES;',
        'CLANG_ENABLE_OBJC_ARC = YES;',
        'COPY_PHASE_STRIP = NO;',
        'DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";',
        'ENABLE_STRICT_OBJC_MSGSEND = YES;',
        'ENABLE_TESTABILITY = NO;',
        'ENABLE_USER_SCRIPT_SANDBOXING = YES;',
        'GCC_OPTIMIZATION_LEVEL = s;',
        'IPHONEOS_DEPLOYMENT_TARGET = 18.0;',
        'LOCALIZATION_PREFERS_STRING_CATALOGS = YES;',
        'MTL_ENABLE_DEBUG_INFO = NO;',
        'ONLY_ACTIVE_ARCH = NO;',
        'SDKROOT = iphoneos;',
        'SWIFT_ACTIVE_COMPILATION_CONDITIONS = "";',
        'SWIFT_OPTIMIZATION_LEVEL = "-O";',
        'SWIFT_VERSION = 6.0;',
    ]))

    # App Debug
    lines.append(cfg(U["cfg:app:D"], "Debug", [
        'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;',
        'CODE_SIGN_STYLE = Automatic;',
        'CURRENT_PROJECT_VERSION = 1;',
        'DEVELOPMENT_TEAM = "";',
        'ENABLE_PREVIEWS = YES;',
        'GENERATE_INFOPLIST_FILE = YES;',
        'INFOPLIST_FILE = PicPick/Info.plist;',
        'INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;',
        'INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;',
        'INFOPLIST_KEY_UILaunchScreen_Generation = YES;',
        'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";',
        'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";',
        'LD_RUNPATH_SEARCH_PATHS = (',
        '\t"$(inherited)",',
        '\t"@executable_path/Frameworks",',
        ');',
        'MARKETING_VERSION = 1.0;',
        'PRODUCT_BUNDLE_IDENTIFIER = com.picpick;',
        'PRODUCT_NAME = PicPick;',
        'SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";',
        'SUPPORTS_MACCATALYST = NO;',
        'SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO;',
        'SWIFT_EMIT_LOC_STRINGS = YES;',
        'TARGETED_DEVICE_FAMILY = 1;',
    ]))

    # App Release
    lines.append(cfg(U["cfg:app:R"], "Release", [
        'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;',
        'CODE_SIGN_STYLE = Automatic;',
        'CURRENT_PROJECT_VERSION = 1;',
        'DEVELOPMENT_TEAM = "";',
        'ENABLE_PREVIEWS = YES;',
        'GENERATE_INFOPLIST_FILE = YES;',
        'INFOPLIST_FILE = PicPick/Info.plist;',
        'INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;',
        'INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;',
        'INFOPLIST_KEY_UILaunchScreen_Generation = YES;',
        'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";',
        'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";',
        'LD_RUNPATH_SEARCH_PATHS = (',
        '\t"$(inherited)",',
        '\t"@executable_path/Frameworks",',
        ');',
        'MARKETING_VERSION = 1.0;',
        'PRODUCT_BUNDLE_IDENTIFIER = com.picpick;',
        'PRODUCT_NAME = PicPick;',
        'SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";',
        'SUPPORTS_MACCATALYST = NO;',
        'SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO;',
        'SWIFT_EMIT_LOC_STRINGS = YES;',
        'TARGETED_DEVICE_FAMILY = 1;',
    ]))

    # Test Debug
    lines.append(cfg(U["cfg:tests:D"], "Debug", [
        'BUNDLE_LOADER = "$(TEST_HOST)";',
        'CODE_SIGN_STYLE = Automatic;',
        'CURRENT_PROJECT_VERSION = 1;',
        'GENERATE_INFOPLIST_FILE = YES;',
        'IPHONEOS_DEPLOYMENT_TARGET = 18.0;',
        'MARKETING_VERSION = 1.0;',
        'PRODUCT_BUNDLE_IDENTIFIER = com.picpick.tests;',
        'PRODUCT_NAME = PicPickTests;',
        'SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";',
        'SWIFT_EMIT_LOC_STRINGS = NO;',
        'SWIFT_VERSION = 6.0;',
        'TARGETED_DEVICE_FAMILY = 1;',
        'TEST_HOST = "$(BUILT_PRODUCTS_DIR)/PicPick.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/PicPick";',
    ]))

    # Test Release
    lines.append(cfg(U["cfg:tests:R"], "Release", [
        'BUNDLE_LOADER = "$(TEST_HOST)";',
        'CODE_SIGN_STYLE = Automatic;',
        'CURRENT_PROJECT_VERSION = 1;',
        'GENERATE_INFOPLIST_FILE = YES;',
        'IPHONEOS_DEPLOYMENT_TARGET = 18.0;',
        'MARKETING_VERSION = 1.0;',
        'PRODUCT_BUNDLE_IDENTIFIER = com.picpick.tests;',
        'PRODUCT_NAME = PicPickTests;',
        'SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";',
        'SWIFT_EMIT_LOC_STRINGS = NO;',
        'SWIFT_VERSION = 6.0;',
        'TARGETED_DEVICE_FAMILY = 1;',
        'TEST_HOST = "$(BUILT_PRODUCTS_DIR)/PicPick.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/PicPick";',
    ]))

    return S(*lines)

def XCConfigurationList():
    lines = []

    def cl(id_, name, debug_id, release_id):
        return f"""\t\t{id_} /* Build configuration list for {name} */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{debug_id} /* Debug */,
\t\t\t\t{release_id} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};"""

    lines.append(cl(U["cl:proj"], 'PBXProject "PicPick"', U["cfg:proj:D"], U["cfg:proj:R"]))
    lines.append(cl(U["cl:app"], 'PBXNativeTarget "PicPick"', U["cfg:app:D"], U["cfg:app:R"]))
    lines.append(cl(U["cl:tests"], 'PBXNativeTarget "PicPickTests"', U["cfg:tests:D"], U["cfg:tests:R"]))

    return S(*lines)

# ── Assemble ──────────────────────────────────────────────────────
def generate():
    content = f"""// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{
\t}};
\tobjectVersion = 56;
\tobjects = {{

/* Begin PBXBuildFile section */
{PBXBuildFile()}
/* End PBXBuildFile section */

/* Begin PBXContainerItemProxy section */
{PBXContainerItemProxy()}
/* End PBXContainerItemProxy section */

/* Begin PBXFileReference section */
{PBXFileReference()}
/* End PBXFileReference section */

/* Begin PBXGroup section */
{PBXGroup()}
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
{PBXNativeTarget()}
/* End PBXNativeTarget section */

/* Begin PBXProject section */
{PBXProject()}
/* End PBXProject section */

/* Begin PBXSourcesBuildPhase section */
{PBXSourcesBuildPhase()}
/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
{PBXTargetDependency()}
/* End PBXTargetDependency section */

/* Begin XCBuildConfiguration section */
{XCBuildConfiguration()}
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
{XCConfigurationList()}
/* End XCConfigurationList section */

\t}};
\trootObject = {U["proj"]} /* Project object */;
}}
"""
    os.makedirs(PBXPROJ_DIR, exist_ok=True)
    with open(PBXPROJ_PATH, "w") as f:
        f.write(content)
    print("Generated PicPick.xcodeproj/project.pbxproj (v2)")

if __name__ == "__main__":
    generate()
