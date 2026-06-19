//
//  BuildMPV.swift
//
//
//  Created by Victor on 12/26/23.
//

import Foundation

class BuildMPV: BaseBuild {
    init() {
        super.init(library: .libmpv)
        let path = directoryURL + "meson.build"
        if let data = FileManager.default.contents(atPath: path.path), var str = String(data: data, encoding: .utf8) {
            str = str.replacingOccurrences(of: "# ffmpeg", with: """
            add_languages('objc')
            #ffmpeg
            """)
            str = str.replacingOccurrences(of: """
            subprocess_source = files('osdep/subprocess-posix.c')
            """, with: """
            if host_machine.subsystem() == 'tvos' or host_machine.subsystem() == 'tvos-simulator'
                subprocess_source = files('osdep/subprocess-dummy.c')
            else
                subprocess_source =files('osdep/subprocess-posix.c')
            endif
            """)
            str = str.replacingOccurrences(of: """
            if posix
                if not get_option('fuzzers') and cc.has_function('fork', prefix : '#include <unistd.h>')
                    sources += files('osdep/subprocess-posix.c')
                else
                    sources += files('osdep/subprocess-dummy.c')
                endif
            """, with: """
            if posix
                if host_machine.subsystem() == 'tvos' or host_machine.subsystem() == 'tvos-simulator'
                    sources += files('osdep/subprocess-dummy.c')
                elif not get_option('fuzzers') and cc.has_function('fork', prefix : '#include <unistd.h>')
                    sources += files('osdep/subprocess-posix.c')
                else
                    sources += files('osdep/subprocess-dummy.c')
                endif
            """)
            try! str.write(toFile: path.path, atomically: true, encoding: .utf8)
        }
    }

    override func flagsDependencelibrarys() -> [Library] {
        [.gmp, .libsmbclient]
    }

    override func build(platform: PlatformType, arch: ArchType, buildURL: URL) throws {
        try super.build(platform: platform, arch: arch, buildURL: buildURL)
        if platform == .macos {
            try rebuildMacOSStaticArchive(platform: platform, arch: arch, buildURL: buildURL)
        }
    }

    private func rebuildMacOSStaticArchive(platform: PlatformType, arch: ArchType, buildURL: URL) throws {
        let objectDir = buildURL + "libmpv.a.p"
        let output = thinDir(platform: platform, arch: arch) + "lib/libmpv.a"
        guard FileManager.default.fileExists(atPath: objectDir.path),
              FileManager.default.fileExists(atPath: output.path)
        else {
            return
        }

        var inputs: [String] = []
        let swiftArchive = buildURL + "osdep/mac/swift.o"
        if FileManager.default.fileExists(atPath: swiftArchive.path) {
            inputs.append(swiftArchive.path)
        }

        var objectFiles: [String] = []
        if let enumerator = FileManager.default.enumerator(
            at: objectDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator where fileURL.pathExtension == "o" {
                objectFiles.append(fileURL.path)
            }
        }
        objectFiles.sort()
        inputs.append(contentsOf: objectFiles)
        guard !inputs.isEmpty else {
            return
        }

        let fileList = buildURL + "libmpv-static-filelist.txt"
        try inputs.joined(separator: "\n").write(to: fileList, atomically: true, encoding: .utf8)
        try Utility.launch(path: "/usr/bin/libtool", arguments: ["-static", "-filelist", fileList.path, "-o", output.path])
    }

    override func arguments(platform: PlatformType, arch: ArchType) -> [String] {
        var array = [
            "-Dlibmpv=true",
            "-Dgl=enabled",
            "-Dplain-gl=enabled",
            "-Diconv=enabled",
            "-Dcplayer=false",
        ]
        if BaseBuild.disableGPL {
            array.append("-Dgpl=false")
        }
        if platform == .macos {
            array.append("-Dswift-flags=-sdk \(platform.isysroot) -target \(platform.deploymentTarget(arch: arch))")
            array.append("-Dcocoa=enabled")
            array.append("-Dcoreaudio=enabled")
            array.append("-Dgl-cocoa=enabled")
            array.append("-Dvideotoolbox-gl=enabled")
        } else {
            array.append("-Dvideotoolbox-gl=disabled")
            array.append("-Dswift-build=disabled")
            array.append("-Daudiounit=enabled")
            array.append("-Dcoreaudio=disabled")
            array.append("-Davfoundation=disabled")
            if platform == .maccatalyst {
                array.append("-Dcocoa=disabled")
            } else if platform == .xros || platform == .xrsimulator {
                array.append("-Dios-gl=disabled")
            } else {
                array.append("-Dios-gl=enabled")
            }
        }
        return array
    }
}
