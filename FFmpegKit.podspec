Pod::Spec.new do |s|
    s.name             = 'FFmpegKit'
    s.version          = '6.1.0'
    s.summary          = 'FFmpegKit'

    s.description      = <<-DESC
    FFmpeg
    DESC

    s.homepage         = 'https://github.com/vvhh2002/FFmpegKit'
    s.authors = { 'Victor' => 'drjone@gmail.com' }
    s.license          = 'MIT'
    s.source           = { :git => 'https://github.com/vvhh2002/FFmpegKit.git', :tag => s.version.to_s }

    s.ios.deployment_target = '13.0'
    s.osx.deployment_target = '10.15'
    # s.watchos.deployment_target = '2.0'
    s.tvos.deployment_target = '13.0'
    s.default_subspec = 'FFmpegKit'
    s.static_framework = true
    s.source_files = 'Sources/FFmpegKit/**/*.{h,c,m}'
    s.pod_target_xcconfig = {
        'CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER' => 'NO',
        'OTHER_MODULE_VERIFIER_FLAGS' => '-Wno-quoted-include-in-framework-header -F\"${PODS_XCFRAMEWORKS_BUILD_DIR}/${PRODUCT_MODULE_NAME}/${PRODUCT_MODULE_NAME}\"'
    }
    s.subspec 'FFmpegKit' do |ffmpeg|
        ffmpeg.libraries   = 'bz2', 'c++', 'iconv', 'resolv', 'xml2', 'z'
        ffmpeg.osx.libraries = 'expat'
        ffmpeg.frameworks  = 'AudioToolbox', 'AVFoundation', 'CoreMedia', 'VideoToolbox'
        ffmpeg.vendored_frameworks = 'Sources/Libavcodec.xcframework','Sources/Libavfilter.xcframework','Sources/Libavformat.xcframework','Sources/Libavutil.xcframework','Sources/Libswresample.xcframework','Sources/Libswscale.xcframework','Sources/Libavdevice.xcframework',
        'Sources/libshaderc_combined.xcframework','Sources/MoltenVK.xcframework', 'Sources/lcms2.xcframework', 'Sources/libdav1d.xcframework', 'Sources/libplacebo.xcframework',
        'Sources/libfontconfig.xcframework',
        'Sources/gmp.xcframework', 'Sources/nettle.xcframework', 'Sources/hogweed.xcframework',
        'Sources/libsmbclient.xcframework',
        'Sources/libzvbi.xcframework', 'Sources/libsrt.xcframework'
        # Note: gnutls.xcframework removed - only built for maccatalyst; other platforms use SecureTransport
        # For maccatalyst GnuTLS support, use SPM builds instead of CocoaPods
        ffmpeg.osx.vendored_frameworks = 'Sources/libbluray.xcframework'
        ffmpeg.dependency 'Libass'
    end
end
