# HapticlabsPlayer

A Swift package for playing Apple AHAP haptics and synchronized audio on iOS.

## Features
- Play AHAP files with Core Haptics
- Mute/unmute haptics and audio
- Play predefined iOS haptic effects
- Automatic resource management

## Installation
Add this package to your Xcode project using Swift Package Manager:

```
https://github.com/HapticlabsIO/swift-hapticlabs-player.git
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
    ahapPath: "path/to/file.ahap",
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
Plays an AHAP file (and referenced audio/AHAPs). Calls `onCompletion` when finished, or `onFailure` with an error message.

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
