import AVFoundation
import CoreHaptics
import Foundation
import os

#if os(iOS)
  import UIKit
#endif

@available(macOS 10.15, *)
class AHAPSyncPlayer {
  private var engine: CHHapticEngine

  init(engine: CHHapticEngine) {
    self.engine = engine
  }

  func play(
    ahapURLs: [URL], onCompletion: @escaping () -> Void,
    onFailure: @escaping (String) -> Void
  ) throws {
    // Load all referenced AHAP files into memory to reduce latency.
    let ahapDatas = ahapURLs.map { try! Data(contentsOf: $0) }

    // Get durations of all AHAP files.
    let ahapDurations: [TimeInterval] = ahapURLs.map { ahapURL in
      do {
        if #available(macOS 13.0, iOS 16.0, *) {
          let pattern = try CHHapticPattern(contentsOf: ahapURL)
          return pattern.duration
        } else {
          // Fallback on earlier versions
          return 0.0
        }
      } catch {
        return 0.0
      }
    }

    let longestDuration = ahapDurations.max() ?? 0.0

    return try self.play(
      ahapDatas: ahapDatas, onCompletion: onCompletion, onFailure: onFailure, isRetry: false,
      totalDuration: longestDuration)
  }

  func play(
    ahapDatas: [Data], onCompletion: @escaping () -> Void,
    onFailure: @escaping (String) -> Void, isRetry: Bool, totalDuration: TimeInterval
  ) throws {
    // Start the engine in case it's idle.
    try self.engine.start()

    // Play all patterns.
    for ahapData in ahapDatas {
      do {
        try self.engine.playPattern(from: ahapData)
      } catch {
        // Failed to play the AHAP pattern.

        // Stop
        self.engine.stop()

        // Try again
        if !isRetry {
          return try self.play(
            ahapDatas: ahapDatas, onCompletion: onCompletion, onFailure: onFailure, isRetry: true,
            totalDuration: totalDuration)
        } else {
          onFailure("Failed to play AHAPs: \(error)")
          return
        }
      }
    }

    // Schedule completion handler on a custom serial queue
    // Store a reference to the completion work item so it can be cancelled if needed
    let completionQueue = DispatchQueue(label: "AHAPSyncPlayer.completionQueue")
    var completionWorkItem: DispatchWorkItem?

    // Wrap onCompletion in a DispatchWorkItem
    completionWorkItem = DispatchWorkItem { [onCompletion] in
      onCompletion()
    }

    // Schedule the completion handler
    if let workItem = completionWorkItem {
      completionQueue.asyncAfter(deadline: .now() + totalDuration, execute: workItem)
    }

    // Use a weak reference to self to avoid retain cycles
    self.engine.notifyWhenPlayersFinished(finishedHandler: { error in
      if let error = error {
      // Cancel the scheduled completion if failure occurs
      completionWorkItem?.cancel()
      onFailure("Failed to play AHAPs: \(error)")
      }
      return .leaveEngineRunning
    })
  }
}

struct AHAP: Codable {
  let Version: Int
  let Metadata: Metadata

  struct Metadata: Codable {
    let Project: String
    let Created: String
    let Description: String
  }
}

@available(macOS 10.15, *)
public class HapticlabsPlayer: NSObject {
  var engine: CHHapticEngine?
  // Store AVAudioPlayers to keep them alive during playback
  var audioPlayersStore: [AVAudioPlayer] = []
  // Single delegate instance for all audio players
  private let audioPlayerDelegate: AudioPlayerDelegate

  private class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    weak var parent: HapticlabsPlayer?
    init(parent: HapticlabsPlayer?) {
      self.parent = parent
    }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
      parent?.removeAudioPlayer(player)
    }
  }

  @objc public override init() {
    self.audioPlayerDelegate = AudioPlayerDelegate(parent: nil)
    super.init()
    self.audioPlayerDelegate.parent = self
    createEngine()
  }

  private func removeAudioPlayer(_ player: AVAudioPlayer) {
    if let idx = self.audioPlayersStore.firstIndex(of: player) {
      self.audioPlayersStore.remove(at: idx)
    }
  }

  func playAHAPs(
    ahapPaths: [String], onCompletion: @escaping () -> Void,
    onFailure: @escaping (String) -> Void
  ) {
    print("[Hapticlabs] playAHAPs called with paths: \(ahapPaths)")
    // Create an array of URLs from the AHAP file names.
    let urls = ahapPaths.compactMap { URL(string: "file://" + $0) }
    var datas: [Data] = []

    let fileManager = FileManager.default
    let documentsDirectory = fileManager.urls(
      for: .documentDirectory, in: .userDomainMask
    ).first!

    // Keep track of the timestamps at which to play audio directly
    var audioFileTimestamps: [(String, Double)] = []

    var maxDuration = 0.0

    let decoder = JSONDecoder()
    do {
      // Read the AHAP files and check if any audio files need to be copied to the documents directory.
      for ahapURL in urls {
        // Keep track of total uncompressed samples and files to play directly
        var totalSamples: Int = 0
        var audioFilesToPlayDirectly: [String] = []
        var filteredAudioFileNames: [String] = []

        // Load the ahap file
        let data = try Data(contentsOf: ahapURL)

        var duration: TimeInterval? = nil
        do {
          if #available(macOS 13.0, iOS 16.0, *) {
            duration = try CHHapticPattern(contentsOf: ahapURL).duration
          } else {
            duration = nil
          }
        } catch { duration = nil }

        let parentDirectoryURL = ahapURL.deletingLastPathComponent()

        let ahap = try decoder.decode(AHAP.self, from: data)
        // Code to execute when decoding is successful
        // Extract AHAP_FILES from the description
        let description = ahap.Metadata.Description
        let descriptionParts = description.split(separator: "\n")

        // Get the duration from the description if not available from CHHapticPattern
        if duration == nil {
          if let totalDurationDescriptionPartIndex = descriptionParts.firstIndex(where: {
            $0.starts(with: "TOTAL_DURATION=")
          }) {
            let durationFormat = "^TOTAL_DURATION=([0-9.]+)$"
            let durationRegex = try! NSRegularExpression(pattern: durationFormat, options: [])
            let durationDescriptionPart = String(
              descriptionParts[totalDurationDescriptionPartIndex])

            if let match = durationRegex.firstMatch(
              in: durationDescriptionPart, options: [],
              range: NSRange(location: 0, length: durationDescriptionPart.utf16.count))
            {
              if let range = Range(match.range(at: 1), in: durationDescriptionPart) {
                let durationString = durationDescriptionPart[range]
                if let parsedDuration = Double(durationString) {
                  duration = parsedDuration
                }
              }
            }
          }
        }

        if let supportingAudioDescriptionPartIndex = descriptionParts.firstIndex(where: {
          $0.starts(with: "AUDIO_FILES=")
        }) {
          let audioFormat = "^AUDIO_FILES=\\[((?:[^,]*?)(?:,[^,]*?)*)\\]$"
          let audioRegex = try! NSRegularExpression(pattern: audioFormat, options: [])
          let audioDescriptionPart = String(descriptionParts[supportingAudioDescriptionPartIndex])

          if let match = audioRegex.firstMatch(
            in: audioDescriptionPart, options: [],
            range: NSRange(location: 0, length: audioDescriptionPart.utf16.count))
          {
            if let range = Range(match.range(at: 1), in: audioDescriptionPart) {
              let audioFilesString = audioDescriptionPart[range]
              let arrayOfAudioFileNameStrings = audioFilesString.split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
              }

              // Copy the audio files to the documents directory

              for audioFileNameString in arrayOfAudioFileNameStrings {
                let sourceAudioURL = parentDirectoryURL.appendingPathComponent(audioFileNameString)

                // The audio file is in the same directory as the AHAP file
                let audioFileName = audioFileNameString.split(separator: ".").dropLast().joined(
                  separator: ".")
                let audioFileExtension = audioFileNameString.split(separator: ".").last!

                let targetAudioURL = documentsDirectory.appendingPathComponent(
                  String(audioFileName)
                ).appendingPathExtension(String(audioFileExtension))

                // Copy the file to the documents directory if it doesn't already exist
                if !fileManager.fileExists(atPath: targetAudioURL.path) {
                  do {
                    try fileManager.copyItem(at: sourceAudioURL, to: targetAudioURL)
                  } catch {
                    onFailure(
                      "Failed to copy audio file to documents directory: \(error)")
                    return
                  }
                }

                // Get audio file properties
                let asset = AVURLAsset(url: targetAudioURL)
                guard
                  let format = asset.tracks(withMediaType: .audio).first?.formatDescriptions
                    .first as! CMAudioFormatDescription?,
                  let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(format)
                else {
                  print("[Hapticlabs] Could not get audio format for \(audioFileNameString)")
                  continue
                }
                let sampleRate = Int(asbd.pointee.mSampleRate)
                let channelCount = Int(asbd.pointee.mChannelsPerFrame)
                let durationSeconds = asset.duration.seconds
                let samples = Int(Double(sampleRate * channelCount) * durationSeconds)

                if filteredAudioFileNames.contains(audioFileNameString) {
                  // Already included
                  continue
                }
                if totalSamples + samples > (1 << 21) {
                  // Exceeds limit, mark for direct playback
                  audioFilesToPlayDirectly.append(audioFileNameString)
                  continue  // Do not copy or include in AHAP
                } else {
                  totalSamples += samples
                  filteredAudioFileNames.append(audioFileNameString)
                }
              }

            }
          }
        }

        let fullAHAP = try JSONSerialization.jsonObject(with: data)

        // Iterate the Pattern array to find Events with EventType "AudioCustom"
        // and "WaveformPath" matching audio files to play directly
        // Delete those events from the AHAP, and record their timestamps
        if var fullAHAPDict = fullAHAP as? [String: Any],
          let patternArray = fullAHAPDict["Pattern"] as? [[String: Any]]
        {
          var newPatternArray: [[String: Any]] = []
          for element in patternArray {
            // Look for an "Event" object with "EventType" == "AudioCustom"
            if let event = element["Event"] as? [String: Any],
              let eventTypeValue = event["EventType"] as? String,
              eventTypeValue == "AudioCustom",
              let path = event["EventWaveformPath"] as? String
            {
              // Check if this path is in the audioFilesToPlayDirectly list
              if audioFilesToPlayDirectly.contains(path) {
                // Record the timestamp
                let time = event["Time"] as? Double ?? 0.0
                audioFileTimestamps.append((path, time))
                // Skip adding this element to the new pattern array
                continue
              }
            }

            // Not an audio event to play directly, keep it
            newPatternArray.append(element)
          }
          fullAHAPDict["Pattern"] = newPatternArray
          let modifiedData = try JSONSerialization.data(
            withJSONObject: fullAHAPDict, options: [])
          datas.append(modifiedData)

          if let foundDuration = duration {
            if foundDuration > maxDuration {
              maxDuration = foundDuration
            }
          }
        } else {
          datas.append(data)
        }
      }
    } catch {
      onFailure("Failed to parse AHAP \(error)")
      return
    }

    if let goodEngine = engine {
      let player = AHAPSyncPlayer(engine: goodEngine)
      do {
        // Prepare AVAudioPlayers for each audio file and timestamp
        // Dictionary to store prepared players for each audio file
        var preparedAudioPlayers: [(AVAudioPlayer, Double)] = []
        for (audioFileName, timestamp) in audioFileTimestamps {
          let audioFileURL = documentsDirectory.appendingPathComponent(audioFileName)
          var audioPlayer: AVAudioPlayer
          do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioFileURL)
            audioPlayer.prepareToPlay()
            audioPlayer.delegate = self.audioPlayerDelegate

            preparedAudioPlayers.append((audioPlayer, timestamp))
            self.audioPlayersStore.append(audioPlayer)
          } catch {
            print("[Hapticlabs] Failed to create audio player for \(audioFileName): \(error)")
          }
        }

        // Start the AHAPs (haptics) playback
        try player.play(
          ahapDatas: datas, onCompletion: onCompletion, onFailure: onFailure, isRetry: false,
          totalDuration: maxDuration)

        // Schedule audio playback after starting haptics
        for (player, timestamp) in preparedAudioPlayers {
          if timestamp == 0 {
            player.play()
          } else {
            player.play(atTime: player.deviceCurrentTime + timestamp)
          }

        }

      } catch {
        onFailure("Failed to play AHAPs")
      }
    }
  }

  /// Mute and unmute AHAP-defined haptics.
  /// - Parameter mute: whether to mute (true) or unmute (false) haptics
  @objc public func setHapticsMute(mute: Bool) {
    // Mute haptics
    engine?.isMutedForHaptics = mute
  }

  /// Mute and unmute AHAP-defined audio
  /// - Parameter mute: whether to mute (true) or unmute (false) audio
  @objc public func setAudioMute(mute: Bool) {
    // Mute audio
    engine?.isMutedForAudio = mute
  }

  /// Whether AHAP-defined haptics are muted
  /// - Returns: true if haptics are muted, false else
  @objc public func isHapticsMuted() -> Bool {
    return engine?.isMutedForHaptics ?? false
  }

  /// Whether AHAP-defined audio is muted
  /// - Returns: true if audio is muted, false else
  @objc public func isAudioMuted() -> Bool {
    return engine?.isMutedForAudio ?? false
  }

  /// Plays an AHAP file along with referenced other AHAP files and audio.
  /// - Parameters:
  ///   - ahapPath: Path to the AHAP file (absolute in the filesystem, or relative to the bundle root)
  ///   - onCompletion: called when the playback successfully completed
  ///   - onFailure: called on error. Passes the error message
  @objc public func playAHAP(
    ahapPath: String, onCompletion: @escaping () -> Void = {},
    onFailure: @escaping (String) -> Void = { _ in }
  ) {
    // Find filenames from the AHAP
    // Load the ahap file

    // Handle bundled AHAP files
    let fullPath =
      if ahapPath.starts(with: "/") {
        ahapPath
      } else {
        // Not a full path, try to find in main bundle
        Bundle.main.path(forResource: ahapPath, ofType: nil) ?? Bundle.main.path(
          forResource: ahapPath, ofType: "ahap") ?? ahapPath
      }

    let ahapURL = URL(string: "file://" + fullPath)
    let parentDirectoryURL = ahapURL?.deletingLastPathComponent()
    do {
      let data = try Data(contentsOf: URL(string: "file://" + fullPath)!)
      // Parse the json
      let decoder = JSONDecoder()

      var otherPaths: [String] = []
      do {
        let ahap = try decoder.decode(AHAP.self, from: data)
        // Code to execute when decoding is successful
        // Extract AHAP_FILES from the description
        let description = ahap.Metadata.Description
        let descriptionParts = description.split(separator: "\n")

        if let supportingAHAPDescriptionPartIndex = descriptionParts.firstIndex(where: {
          $0.starts(with: "AHAP_FILES=")
        }) {
          let ahapFormat = "^AHAP_FILES=\\[((?:[^,]*?)(?:,[^,]*?)*)\\]$"
          let ahapRegex = try! NSRegularExpression(pattern: ahapFormat, options: [])
          let ahapDescriptionPart = String(descriptionParts[supportingAHAPDescriptionPartIndex])

          if let match = ahapRegex.firstMatch(
            in: ahapDescriptionPart, options: [],
            range: NSRange(location: 0, length: ahapDescriptionPart.utf16.count))
          {
            if let range = Range(match.range(at: 1), in: ahapDescriptionPart) {
              let ahapFilesString = ahapDescriptionPart[range]
              let arrayOfAHAPFileNameStrings = ahapFilesString.split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
              }

              // Add the parent directory to the file names
              otherPaths = arrayOfAHAPFileNameStrings.map {
                parentDirectoryURL!.appendingPathComponent($0).path
              }
            }
          }
        }
      } catch {
        onFailure("Failed to parse AHAP \(error)")
        return
      }

      playAHAPs(
        ahapPaths: [fullPath] + otherPaths, onCompletion: onCompletion, onFailure: onFailure)

    } catch {
      onFailure("Failed to load ahap: " + fullPath + " because \(error)")
      return
    }
  }

  #if os(iOS)
    /// Plays one of the predefined haptic effects
    /// - Parameter name: the effect to play. Must be one of `"light"`, `"medium"`, `"heavy"`, `"rigid"`, `"soft"`, `"error"`, `"warning"`, `"success"`, `"selection"`
    @objc @MainActor public func playPredefinedIOSVibration(_ name: String) {
      // Log the received data
      if name == "light" {
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
        feedbackGenerator.prepare()

        feedbackGenerator.impactOccurred()
      } else if name == "heavy" {
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
        feedbackGenerator.prepare()

        feedbackGenerator.impactOccurred()
      } else if name == "medium" {
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        feedbackGenerator.prepare()

        feedbackGenerator.impactOccurred()
      } else if name == "rigid" {
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .rigid)
        feedbackGenerator.prepare()

        feedbackGenerator.impactOccurred()
      } else if name == "soft" {
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .soft)
        feedbackGenerator.prepare()

        feedbackGenerator.impactOccurred()
      } else if name == "error" {
        let notificationFeedbackGenerator = UINotificationFeedbackGenerator()
        notificationFeedbackGenerator.notificationOccurred(.error)
      } else if name == "warning" {
        let notificationFeedbackGenerator = UINotificationFeedbackGenerator()
        notificationFeedbackGenerator.notificationOccurred(.warning)
      } else if name == "success" {
        let notificationFeedbackGenerator = UINotificationFeedbackGenerator()
        notificationFeedbackGenerator.notificationOccurred(.success)
      } else if name == "selection" {
        let selectionFeedbackGenerator = UISelectionFeedbackGenerator()
        selectionFeedbackGenerator.prepare()
        selectionFeedbackGenerator.selectionChanged()
      }
    }
  #endif

  func createEngine() {
    // Create and configure a haptic engine.
    do {
      engine = try CHHapticEngine()
    } catch _ {
    }

    guard let engine = engine else {
      print("Failed to create engine!")
      return
    }

    // The stopped handler alerts you of engine stoppage due to external causes.
    engine.stoppedHandler = { reason in
      print("The engine stopped for reason: \(reason.rawValue)")
      switch reason {
      case .audioSessionInterrupt:
        print("Audio session interrupt")
      case .applicationSuspended:
        print("Application suspended")
      case .idleTimeout:
        print("Idle timeout")
      case .systemError:
        print("System error")
      case .notifyWhenFinished:
        print("Playback finished")
      case .gameControllerDisconnect:
        print("Controller disconnected.")
      case .engineDestroyed:
        print("Engine destroyed.")
      @unknown default:
        print("Unknown error")
      }
    }

    // The reset handler provides an opportunity for your app to restart the engine in case of failure.
    engine.resetHandler = {
      // Try restarting the engine.
      do {
        try engine.start()
      } catch {
        print("Failed to restart the engine: \(error)")
      }
    }

    engine.isMutedForAudio = false
    engine.isMutedForHaptics = false
  }
}
