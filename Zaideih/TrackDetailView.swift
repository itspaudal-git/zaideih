import SwiftUI
import AVFoundation
import Combine

struct TrackDetailView: View {
    var tracks: [Track]
    @State var selectedTrackIndex: Int

    @ObservedObject var audioManager = AudioPlayerManager.shared
    @State private var showLyrics: Bool = false
    @State private var lyricFontSize: CGFloat = 20
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0

    // Add a cancellable to manage the subscription
    @State private var cancellable: AnyCancellable?

    var currentTrack: Track {
        return tracks[selectedTrackIndex]
    }

    var body: some View {
        VStack(spacing: 20) {
            // Album Art
            if let artURL = URL(string: currentTrack.art), !currentTrack.art.isEmpty {
                AsyncImage(url: artURL)
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .cornerRadius(10)
            } else {
                Image(systemName: "music.note")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .foregroundColor(.gray)
            }

            // Track Info
            Text(currentTrack.title)
                .font(.title)
                .bold()
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text("Artist: \(currentTrack.artist)")
                .font(.subheadline)

            Text("Album: \(currentTrack.album)")
                .font(.subheadline)

            // Lyrics Button
            if !currentTrack.lyric.isEmpty {
                Button(action: {
                    showLyrics = true
                }) {
                    Text("View Lyrics")
                        .font(.caption) // Smaller font
                        .foregroundColor(.white)
                        .padding(5)
                        .background(Color.blue)
                        .cornerRadius(5)
                }
            }

            // Playback Controls
            HStack(spacing: 30) { // Adjust spacing as needed
                Button(action: {
                    playPreviousTrack()
                }) {
                    Image(systemName: "backward.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 25, height: 25) // Smaller size
                        .padding(10)
                        .background(Color.blue.opacity(0.7))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }

                Button(action: {
                    if audioManager.isPlaying && audioManager.currentTrack?.id == currentTrack.id {
                        audioManager.pause()
                    } else {
                        audioManager.play(track: currentTrack)
                    }
                }) {
                    Image(systemName: audioManager.isPlaying && audioManager.currentTrack?.id == currentTrack.id ? "pause.fill" : "play.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30) // Adjust as needed
                        .padding(12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }

                Button(action: {
                    playNextTrack()
                }) {
                    Image(systemName: "forward.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 25, height: 25) // Smaller size
                        .padding(10)
                        .background(Color.blue.opacity(0.7))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
            }

            // Seek Bar (Slider)
            Slider(value: $currentTime, in: 0...duration, onEditingChanged: { isEditing in
                if !isEditing {
                    seekTo(time: currentTime)
                }
            })
            .padding()

            // Time labels for current time and duration
            HStack {
                Text("\(formattedTime(seconds: currentTime))")
                    .font(.caption) // Smaller font
                Spacer()
                Text("\(formattedTime(seconds: duration))")
                    .font(.caption) // Smaller font
            }
            .padding(.horizontal)

            Spacer()
        }
        .onAppear {
            playCurrentTrack()
            subscribeToTrackEnd()
        }
        .onDisappear {
            // Cancel the subscription when the view disappears to prevent memory leaks
            cancellable?.cancel()
        }
        .navigationTitle(currentTrack.title)
        .sheet(isPresented: $showLyrics) {
            LyricsView(lyrics: currentTrack.lyric, fontSize: $lyricFontSize)
        }
    }

    // MARK: - Playback Functions

    func playCurrentTrack() {
        audioManager.play(track: currentTrack)
        audioManager.getDuration { dur in
            DispatchQueue.main.async {
                self.duration = dur
            }
        }
        audioManager.addTimeObserver { time in
            DispatchQueue.main.async {
                self.currentTime = time.seconds
            }
        }
    }

    func playNextTrack() {
        if selectedTrackIndex + 1 < tracks.count {
            selectedTrackIndex += 1
        } else {
            // Loop back to the first track
            selectedTrackIndex = 0
        }
        playCurrentTrack()
    }

    func playPreviousTrack() {
        if selectedTrackIndex - 1 >= 0 {
            selectedTrackIndex -= 1
        } else {
            // Loop back to the last track
            selectedTrackIndex = tracks.count - 1
        }
        playCurrentTrack()
    }

    func seekTo(time: Double) {
        audioManager.seekTo(time: time)
    }

    func formattedTime(seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    // MARK: - Subscription to Track End

    func subscribeToTrackEnd() {
        cancellable = audioManager.trackEndedPublisher
            .receive(on: RunLoop.main)
            .sink {
                playNextTrack()
            }
    }
}

// MARK: - Lyrics View
struct LyricsView: View {
    var lyrics: String
    @Binding var fontSize: CGFloat

    var body: some View {
        VStack {
            Text("Lyrics")
                .font(.title)
                .padding()

            ScrollView {
                Text(lyrics)
                    .font(.system(size: fontSize))
                    .padding()
            }

            // Font size adjustment controls
            HStack {
                Button(action: {
                    if fontSize > 12 {
                        fontSize -= 2
                    }
                }) {
                    Text("A-")
                        .font(.title2)
                        .padding(8)
                        .background(Color.blue.opacity(0.7))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                .disabled(fontSize <= 12)
                .padding()

                Button(action: {
                    if fontSize < 30 {
                        fontSize += 2
                    }
                }) {
                    Text("A+")
                        .font(.title2)
                        .padding(8)
                        .background(Color.blue.opacity(0.7))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                .disabled(fontSize >= 30)
                .padding()
            }
        }
    }
}
