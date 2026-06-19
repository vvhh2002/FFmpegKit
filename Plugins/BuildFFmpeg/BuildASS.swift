//
//  BuildASS.swift
//
//
//  Created by Victor on 12/26/23.
//

import Foundation

class BuildFribidi: BaseBuild {
    init() {
        super.init(library: .libfribidi)
    }

    override func arguments(platform _: PlatformType, arch _: ArchType) -> [String] {
        [
            "-Ddeprecated=false",
            "-Ddocs=false",
            "-Dtests=false",
        ]
    }
}

class BuildHarfbuzz: BaseBuild {
    init() {
        super.init(library: .libharfbuzz)
    }

    override func flagsDependencelibrarys() -> [Library] {
        [.libfreetype]
    }

    override func arguments(platform _: PlatformType, arch _: ArchType) -> [String] {
        [
            "-Dglib=disabled",
            "-Dgobject=disabled",
            "-Dintrospection=disabled",
            "-Dtests=disabled",
            "-Ddocs=disabled",
            "-Dcairo=disabled",
            "-Dchafa=disabled",
            "-Dicu=disabled",
            "-Dpng=disabled",
            "-Dzlib=disabled",
            "-Dgraphite2=disabled",
            "-Dfontations=disabled",
            "-Dharfrust=disabled",
            "-Dwasm=disabled",
            "-Draster=disabled",
            "-Dvector=disabled",
            "-Dgpu=disabled",
            "-Dgpu_demo=disabled",
            "-Dsubset=disabled",
            "-Dutilities=disabled",
            "-Dfreetype=enabled",
        ]
    }
}

class BuildFreetype: BaseBuild {
    init() {
        super.init(library: .libfreetype)
    }

    override func arguments(platform _: PlatformType, arch _: ArchType) -> [String] {
        [
            "-Dbrotli=disabled",
            "-Dharfbuzz=disabled",
            "-Dpng=disabled",
        ]
    }
}

class BuildPng: BaseBuild {
    init() {
        super.init(library: .libpng)
    }

    override func arguments(platform _: PlatformType, arch _: ArchType) -> [String] {
        ["-DPNG_HARDWARE_OPTIMIZATIONS=yes"]
    }
}

class BuildASS: BaseBuild {
    init() {
        super.init(library: .libass)
    }

    override func arguments(platform _: PlatformType, arch: ArchType) -> [String] {
        var result =
            [
                "-Dfontconfig=disabled",
                "-Drequire-system-font-provider=false",
                "-Dtest=disabled",
                "-Dcompare=disabled",
                "-Dprofile=disabled",
                "-Dfuzz=disabled",
                "-Dcheckasm=disabled",
                "-Dlibunibreak=disabled",
            ]
        if arch == .x86_64 {
            result.append("-Dasm=enabled")
        } else {
            result.append("-Dasm=disabled")
        }
        return result
    }
}
