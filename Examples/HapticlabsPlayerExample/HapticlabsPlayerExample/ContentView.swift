//
//  ContentView.swift
//  HapticlabsPlayerExample
//
//  Created by Michi on 15.01.26.
//
import AVFoundation
import HapticlabsPlayer
import SwiftUICore
import SwiftUI


@available(iOS 13.0, *)
struct ContentView: View {
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
            
            Button("Play AHAP with audio") {
                let ahapPath = Bundle.main.path(forResource: "AHAP/Button", ofType: "ahap") ?? ""
                if ahapPath.isEmpty {
                    statusMessage = "Button.ahap not found in bundle"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        statusMessage = ""
                    }
                } else {
                    player.playAHAP(
                        ahapPath: ahapPath,
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
            
            Button("Play cat AHAP") {
                let ahapPath = Bundle.main.path(forResource: "AHAP/CatPurring", ofType: "ahap") ?? ""
                if ahapPath.isEmpty {
                    statusMessage = "CatPurring.ahap not found in bundle"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        statusMessage = ""
                    }
                } else {
                    player.playAHAP(
                        ahapPath: ahapPath,
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
