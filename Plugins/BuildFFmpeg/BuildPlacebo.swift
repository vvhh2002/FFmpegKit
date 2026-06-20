//
//  BuildPlacebo.swift
//
//
//  Created by Victor on 12/26/23.
//

import Foundation

class BuildPlacebo: BaseBuild {
    init() {
        super.init(library: .libplacebo)
        let path = directoryURL + "demos/meson.build"
        if let data = FileManager.default.contents(atPath: path.path), var str = String(data: data, encoding: .utf8) {
            str = str.replacingOccurrences(of: "if sdl.found()", with: "if false")
            try! str.write(toFile: path.path, atomically: true, encoding: .utf8)
        }
    }

    override func arguments(platform: PlatformType, arch _: ArchType) -> [String] {
        var args = ["-Dxxhash=disabled", "-Dopengl=disabled"]
        if platform == .maccatalyst {
            args.append("-Dvulkan=disabled")
        }
        return args
    }
}

class BuildVulkan: BaseBuild {
    init() {
        super.init(library: .vulkan)
    }

    private var staticXCFrameworkURL: URL {
        directoryURL + "Package/Release/MoltenVK/static/MoltenVK.xcframework"
    }

    private var deploymentTargetEnvironment: [String: String] {
        [
            "IPHONEOS_DEPLOYMENT_TARGET": PlatformType.ios.minVersion,
            "MACOSX_DEPLOYMENT_TARGET": PlatformType.macos.minVersion,
            "TVOS_DEPLOYMENT_TARGET": PlatformType.tvos.minVersion,
            "XROS_DEPLOYMENT_TARGET": PlatformType.xros.minVersion,
        ]
    }

    private var deploymentTargetMakeArguments: [String] {
        deploymentTargetEnvironment.keys.sorted().map {
            "\($0)=\(deploymentTargetEnvironment[$0]!)"
        }
    }

    override func platforms() -> [PlatformType] {
        // Placebo编译maccatalyst的时候，vulkan会报找不到UIKit的问题，所以要先屏蔽。
        super.platforms().filter {
            ![.maccatalyst].contains($0)
        }
    }

    override func buildALL() throws {
        try patchMoltenVKBuildFiles()
        var arguments = platforms().map {
            "--\($0.name)"
        }
        let environment = deploymentTargetEnvironment
        if !FileManager.default.fileExists(atPath: (directoryURL + "External/build/Release").path) {
            try Utility.launch(path: (directoryURL + "fetchDependencies").path, arguments: arguments, currentDirectoryURL: directoryURL, environment: environment)
        }
        if !FileManager.default.fileExists(atPath: staticXCFrameworkURL.path) || !BaseBuild.notRecompile {
            for platform in platforms() {
                arguments = [platform.name]
                arguments.append(contentsOf: deploymentTargetMakeArguments)
                do {
                    try Utility.launch(path: "/usr/bin/make", arguments: arguments, currentDirectoryURL: directoryURL, environment: environment)
                } catch {
                    if hasUsableStaticXCFramework() {
                        print("MoltenVK static xcframework is usable; continuing after package target failure: \(error)")
                    } else {
                        throw error
                    }
                }
            }
        }
        guard hasUsableStaticXCFramework() else {
            throw NSError(domain: "BuildFFmpeg", code: 1, userInfo: [NSLocalizedDescriptionKey: "MoltenVK static xcframework is missing required platform slices"])
        }
        try? FileManager.default.removeItem(at: URL.currentDirectory() + "../Sources/MoltenVK.xcframework")
        try? FileManager.default.copyItem(at: staticXCFrameworkURL, to: URL.currentDirectory() + "../Sources/MoltenVK.xcframework")
        for platform in platforms() {
            var frameworks = ["CoreFoundation", "CoreGraphics", "Foundation", "IOSurface", "Metal", "QuartzCore"]
            if platform == .macos {
                frameworks.append("Cocoa")
            } else {
                frameworks.append("UIKit")
            }
            if !(platform == .tvos || platform == .tvsimulator) {
                frameworks.append("IOKit")
            }
            let libframework = frameworks.map {
                "-framework \($0)"
            }.joined(separator: " ")
            for arch in platform.architectures {
                let prefix = thinDir(platform: platform, arch: arch) + "lib/pkgconfig"
                try? FileManager.default.removeItem(at: prefix)
                try? FileManager.default.createDirectory(at: prefix, withIntermediateDirectories: true, attributes: nil)
                let vulkanPC = prefix + "vulkan.pc"

                let content = """
                prefix=\((directoryURL + "Package/Release/MoltenVK").path)
                includedir=${prefix}/include
                libdir=${prefix}/static/MoltenVK.xcframework/\(platform.frameworkName)

                Name: Vulkan-Loader
                Description: Vulkan Loader
                Version: 1.2
                Libs: -L${libdir} -lMoltenVK \(libframework)
                Cflags: -I${includedir}
                """
                FileManager.default.createFile(atPath: vulkanPC.path, contents: content.data(using: .utf8), attributes: nil)
            }
        }
    }

    private func patchMoltenVKBuildFiles() throws {
        let makefile = directoryURL + "Makefile"
        if let data = FileManager.default.contents(atPath: makefile.path), var content = String(data: data, encoding: .utf8) {
            let original = "GCC_PREPROCESSOR_DEFINITIONS='$${inherited} $(MAKEARGS)' $(OUTPUT_FMT_CMD)"
            let replacement = "$(MAKEARGS) GCC_PREPROCESSOR_DEFINITIONS='$${inherited} $(MAKEARGS)' $(OUTPUT_FMT_CMD)"
            if content.contains(original), !content.contains(replacement) {
                content = content.replacingOccurrences(of: original, with: replacement)
                try content.write(to: makefile, atomically: true, encoding: .utf8)
            }
        }

        let project = directoryURL + "MoltenVK/MoltenVK.xcodeproj/project.pbxproj"
        if let data = FileManager.default.contents(atPath: project.path), var content = String(data: data, encoding: .utf8) {
            content = content
                .replacingOccurrences(of: "IPHONEOS_DEPLOYMENT_TARGET = 13.0;", with: "IPHONEOS_DEPLOYMENT_TARGET = \(PlatformType.ios.minVersion);")
                .replacingOccurrences(of: "MACOSX_DEPLOYMENT_TARGET = 10.15;", with: "MACOSX_DEPLOYMENT_TARGET = \(PlatformType.macos.minVersion);")
                .replacingOccurrences(of: "TVOS_DEPLOYMENT_TARGET = 13.0;", with: "TVOS_DEPLOYMENT_TARGET = \(PlatformType.tvos.minVersion);")
            try content.write(to: project, atomically: true, encoding: .utf8)
        }
    }

    private func hasUsableStaticXCFramework() -> Bool {
        let infoPlist = staticXCFrameworkURL + "Info.plist"
        guard let data = FileManager.default.contents(atPath: infoPlist.path),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let availableLibraries = plist["AvailableLibraries"] as? [[String: Any]]
        else {
            return false
        }
        let availableIdentifiers = Set(availableLibraries.compactMap { $0["LibraryIdentifier"] as? String })
        let requiredIdentifiers = Set(platforms().map(\.frameworkName))
        return requiredIdentifiers.isSubset(of: availableIdentifiers)
    }
}

class BuildGlslang: BaseBuild {
    init() {
        super.init(library: .libglslang)
        _ = try? Utility.launch(executableURL: directoryURL + "./update_glslang_sources.py", arguments: [], currentDirectoryURL: directoryURL)
        var path = directoryURL + "External/spirv-tools/tools/reduce/reduce.cpp"
        if let data = FileManager.default.contents(atPath: path.path), var str = String(data: data, encoding: .utf8) {
            str = str.replacingOccurrences(of: """
              int res = std::system(nullptr);
              return res != 0;
            """, with: """
              FILE* fp = popen(nullptr, "r");
              return fp == NULL;
            """)
            str = str.replacingOccurrences(of: """
              int status = std::system(command.c_str());
            """, with: """
              FILE* fp = popen(command.c_str(), "r");
            """)
            str = str.replacingOccurrences(of: """
              return status == 0;
            """, with: """
              return fp != NULL;
            """)
            try! str.write(toFile: path.path, atomically: true, encoding: .utf8)
        }
        path = directoryURL + "External/spirv-tools/tools/fuzz/fuzz.cpp"
        if let data = FileManager.default.contents(atPath: path.path), var str = String(data: data, encoding: .utf8) {
            str = str.replacingOccurrences(of: """
              int res = std::system(nullptr);
              return res != 0;
            """, with: """
              FILE* fp = popen(nullptr, "r");
              return fp == NULL;
            """)
            str = str.replacingOccurrences(of: """
              int status = std::system(command.c_str());
            """, with: """
              FILE* fp = popen(command.c_str(), "r");
            """)
            str = str.replacingOccurrences(of: """
              return status == 0;
            """, with: """
              return fp != NULL;
            """)
            try! str.write(toFile: path.path, atomically: true, encoding: .utf8)
        }
    }
}

class BuildShaderc: BaseBuild {
    init() {
        super.init(library: .libshaderc)
        _ = try? Utility.launch(executableURL: directoryURL + "utils/git-sync-deps", arguments: [], currentDirectoryURL: directoryURL)
        var path = directoryURL + "third_party/spirv-tools/tools/reduce/reduce.cpp"
        if let data = FileManager.default.contents(atPath: path.path), var str = String(data: data, encoding: .utf8) {
            str = str.replacingOccurrences(of: """
              int res = std::system(nullptr);
              return res != 0;
            """, with: """
              FILE* fp = popen(nullptr, "r");
              return fp == NULL;
            """)
            str = str.replacingOccurrences(of: """
              int status = std::system(command.c_str());
            """, with: """
              FILE* fp = popen(command.c_str(), "r");
            """)
            str = str.replacingOccurrences(of: """
              return status == 0;
            """, with: """
              return fp != NULL;
            """)
            try! str.write(toFile: path.path, atomically: true, encoding: .utf8)
        }
        path = directoryURL + "third_party/spirv-tools/tools/fuzz/fuzz.cpp"
        if let data = FileManager.default.contents(atPath: path.path), var str = String(data: data, encoding: .utf8) {
            str = str.replacingOccurrences(of: """
              int res = std::system(nullptr);
              return res != 0;
            """, with: """
              FILE* fp = popen(nullptr, "r");
              return fp == NULL;
            """)
            str = str.replacingOccurrences(of: """
              int status = std::system(command.c_str());
            """, with: """
              FILE* fp = popen(command.c_str(), "r");
            """)
            str = str.replacingOccurrences(of: """
              return status == 0;
            """, with: """
              return fp != NULL;
            """)
            try! str.write(toFile: path.path, atomically: true, encoding: .utf8)
        }
    }

    override func frameworks() throws -> [String] {
        ["libshaderc_combined"]
    }

    override func arguments(platform _: PlatformType, arch _: ArchType) -> [String] {
        [
            "-DSHADERC_SKIP_TESTS=ON",
            "-DSHADERC_SKIP_EXAMPLES=ON",
            "-DSHADERC_SKIP_EXECUTABLES=ON",
            "-DSPIRV_SKIP_TESTS=ON",
            "-DEFFCEE_BUILD_TESTING=OFF",
            "-DBUILD_TESTING=OFF",
        ]
    }

    override func build(platform: PlatformType, arch: ArchType, buildURL: URL) throws {
        try super.build(platform: platform, arch: arch, buildURL: buildURL)
        let thinDir = thinDir(platform: platform, arch: arch)
        let pkgconfig = thinDir + "lib/pkgconfig"
        try FileManager.default.moveItem(at: pkgconfig + "shaderc.pc", to: pkgconfig + "shaderc_shared.pc")
        try FileManager.default.moveItem(at: pkgconfig + "shaderc_combined.pc", to: pkgconfig + "shaderc.pc")
    }
}

class BuildLittleCms: BaseBuild {
    init() {
        super.init(library: .lcms2)
    }
}

class BuildDav1d: BaseBuild {
    init() {
        super.init(library: .libdav1d)
        if Utility.shell("which nasm") == nil {
            Utility.shell("brew install nasm")
        }
    }

    override func arguments(platform _: PlatformType, arch _: ArchType) -> [String] {
        ["-Denable_asm=true", "-Denable_tools=false", "-Denable_examples=false", "-Denable_tests=false"]
    }
}

class BuildDovi: BaseBuild {
    init() {
        super.init(library: .libdovi)
    }
}
