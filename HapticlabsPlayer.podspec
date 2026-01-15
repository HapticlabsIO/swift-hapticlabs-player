Pod::Spec.new do |s|
    s.name             = 'HapticlabsPlayer'
    s.version          = '0.1.0'
    s.summary          = 'A Swift package for playing AHAP and predefined haptics on iOS.'
    s.description      = <<-DESC
        HapticlabsPlayer lets you play AHAP files with Core Haptics, mute/unmute haptics and audio, play predefined iOS haptic effects, and manage resources automatically. Hapticlabs Studio can be used to create AHAP files compatible with this package.
    DESC
    s.homepage         = 'https://github.com/HapticlabsIO/swift-hapticlabs-player'
    s.license          = { :type => 'MIT', :file => 'LICENSE' }
    s.author           = { 'HapticlabsIO' => 'michael@hapticlabs.io' }
    s.source           = { :git => 'https://github.com/HapticlabsIO/swift-hapticlabs-player.git', :tag => 'v0.1.0' }
    s.ios.deployment_target = '15.0'
    s.swift_version    = '5.9'
    s.source_files     = 'Sources/**/*.{swift}'
end