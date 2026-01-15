# HapticlabsPlayer

A Swift package for playing Apple AHAP haptics and synchronized audio on iOS.

## Features
- Play AHAP files with Core Haptics
- Mute/unmute haptics and audio
- Play predefined iOS haptic effects
- Automatic resource management


## Installation

HapticlabsPlayer can be integrated into your project using either Swift Package Manager or CocoaPods.

### Swift Package Manager
Add this package to your Xcode project:

```
https://github.com/HapticlabsIO/swift-hapticlabs-player.git
```

### CocoaPods
Add the following to your Podfile:

```
pod 'HapticlabsPlayer', :git => 'https://github.com/HapticlabsIO/swift-hapticlabs-player.git', :tag => 'v0.1.1'
```

Then run:

```
pod install
```

## Usage

### Import
```swift
import HapticlabsPlayer
```

### Basic Example
```swift
let player = HapticlabsPlayer()
player.playAHAP(
    ahapPath: "/path/to/file.ahap",
    onCompletion: { print("Playback completed") },
    onFailure: { error in print("Error: \(error)") }
)
```

## API Reference

### HapticlabsPlayer

#### Initializer
```swift
public init()
```

#### Playback
```swift
public func playAHAP(
    ahapPath: String,
    onCompletion: @escaping () -> Void,
    onFailure: @escaping (String) -> Void
)
```
Plays an AHAP file (and referenced audio/AHAPs). Calls `onCompletion` when finished, or `onFailure` with an error message. Accepts absolute paths and paths that are relative to the bundle root.

#### Haptics/Audio Mute
```swift
public func setHapticsMute(mute: Bool)
public func setAudioMute(mute: Bool)
public func isHapticsMuted() -> Bool
public func isAudioMuted() -> Bool
```
Mute/unmute haptics or audio, or query mute state.

#### Predefined iOS Haptics
```swift
@MainActor public func playPredefinedIOSVibration(_ name: String)
```
Plays a predefined haptic effect. `name` must be one of:
- "light"
- "medium"
- "heavy"
- "rigid"
- "soft"
- "error"
- "warning"
- "success"
- "selection"

## Example App
See `Examples/HapticlabsPlayerExample` for an iOS demo app.

## License
MIT
