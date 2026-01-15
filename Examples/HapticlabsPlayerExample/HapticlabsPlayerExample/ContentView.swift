//
//  ContentView.swift
//  HapticlabsPlayerExample
//
//  Created by Michi on 15.01.26.
//
import AVFoundation
import HapticlabsPlayer
import SwiftUI
import SwiftUICore

@available(iOS 13.0, *)
struct ContentView: View {
    private func ahapButton(title: String, resource: String) -> some View {
        Button(title) {
                player.playAHAP(
                    ahapPath: resource,
                    onCompletion: {
                        statusMessage = "Playback completed"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            statusMessage = ""
                        }
                    },
                    onFailure: { error in
                        statusMessage = "Error: \(error)"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            statusMessage = ""
                        }
                    }
                )
            
        }
    }
    @State private var player = HapticlabsPlayer()
    @State private var hapticsMuted = false
    @State private var audioMuted = false
    @State private var statusMessage = ""

    var body: some View {
        VStack(spacing: 20) {
            Button("Play Predefined: Light") {
                player.playPredefinedIOSVibration("light")
            }

            Button("Play Predefined: Success") {
                player.playPredefinedIOSVibration("success")
            }

            Text("AHAP haptics are \(hapticsMuted ? "" : "not ")muted")

            Button(hapticsMuted ? "Unmute Haptics" : "Mute Haptics") {
                hapticsMuted.toggle()
                player.setHapticsMute(mute: hapticsMuted)
            }

            Text("AHAP audio is \(audioMuted ? "" : "not ")muted")

            Button(audioMuted ? "Unmute Audio" : "Mute Audio") {
                audioMuted.toggle()
                player.setAudioMute(mute: audioMuted)
            }

            ahapButton(
                title: "Play AHAP with audio", resource: "AHAP/Button.ahap")
            ahapButton(
                title: "Play cat AHAP", resource: "AHAP/CatPurring")

            Text(statusMessage)
                .font(.footnote)
                .foregroundColor(.gray)
                .padding(.top, 10)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
