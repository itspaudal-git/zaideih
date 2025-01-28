import AVFoundation
import Combine
import MediaPlayer
import UIKit

class AudioPlayerManager: ObservableObject {
    static let shared = AudioPlayerManager()
    var audioPlayer: AVPlayer?
    @Published var isPlaying = false
    @Published var currentTrack: Track?

    // Publisher to notify when the track ends
    let trackEndedPublisher = PassthroughSubject<Void, Never>()

    private var timeObserverToken: Any?

    private init() {
        configureAudioSession()
        setupNowPlaying()
        // Add observer for when the player finishes playing an item
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying(_:)),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
        // Observe audio interruptions (e.g., phone calls)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    // MARK: - Audio Session Configuration

    private func configureAudioSession() {
        do {
            // Set the audio session category, mode, and options
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
            print("Audio session successfully configured for background playback.")
        } catch {
            print("Failed to configure audio session: \(error.localizedDescription)")
        }
    }

    // MARK: - Now Playing Info

    private func setupNowPlaying() {
        // Configure the Now Playing Info Center with default values
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: "Unknown Title",
            MPMediaItemPropertyArtist: "Unknown Artist",
            MPMediaItemPropertyAlbumTitle: "Unknown Album",
            MPNowPlayingInfoPropertyPlaybackRate: 1.0
        ]

        // Register for remote control events
        UIApplication.shared.beginReceivingRemoteControlEvents()
        setupRemoteCommandCenter()
    }

    private func updateNowPlayingInfo() {
        guard let currentTrack = currentTrack else { return }

        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: currentTrack.title,
            MPMediaItemPropertyArtist: currentTrack.artist,
            MPMediaItemPropertyAlbumTitle: currentTrack.album,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]

        // Set the playback duration if available
        if let duration = audioPlayer?.currentItem?.asset.duration.seconds, duration > 0 {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        }

        // Optionally, set album art
        if let artURL = URL(string: currentTrack.art),
           let imageData = try? Data(contentsOf: artURL),
           let image = UIImage(data: imageData) {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { size in
                return image
            }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        // Play Command
        commandCenter.playCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            if !self.isPlaying, let currentTrack = self.currentTrack {
                self.play(track: currentTrack)
                return .success
            }
            return .commandFailed
        }

        // Pause Command
        commandCenter.pauseCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            if self.isPlaying {
                self.pause()
                return .success
            }
            return .commandFailed
        }

        // Next Track Command
        commandCenter.nextTrackCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            self.trackEndedPublisher.send() // Trigger next track
            return .success
        }

        // Previous Track Command
        commandCenter.previousTrackCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            self.playPreviousTrack()
            return .success
        }
    }

    // MARK: - Playback Controls

    func play(track: Track) {
        if currentTrack?.id != track.id {
            if let url = URL(string: track.link) {
                let playerItem = AVPlayerItem(url: url)
                audioPlayer = AVPlayer(playerItem: playerItem)
                currentTrack = track
                updateNowPlayingInfo()
            } else {
                print("Invalid audio URL for track: \(track.title)")
                return
            }
        }
        audioPlayer?.play()
        isPlaying = true
        updateNowPlayingInfo()
    }

    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }

    func seekTo(time: Double) {
        let timeScale = audioPlayer?.currentItem?.asset.duration.timescale ?? CMTimeScale(NSEC_PER_SEC)
        let cmTime = CMTime(seconds: time, preferredTimescale: timeScale)
        audioPlayer?.seek(to: cmTime)
    }

    func addTimeObserver(_ onUpdate: @escaping (CMTime) -> Void) {
        let interval = CMTime(seconds: 1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = audioPlayer?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            onUpdate(time)
        }
    }

    func getDuration(completion: @escaping (Double) -> Void) {
        guard let asset = audioPlayer?.currentItem?.asset else {
            completion(0)
            return
        }
        asset.loadValuesAsynchronously(forKeys: ["duration"]) {
            var error: NSError? = nil
            let status = asset.statusOfValue(forKey: "duration", error: &error)
            switch status {
            case .loaded:
                let durationInSeconds = asset.duration.seconds
                completion(durationInSeconds)
            default:
                print("Failed to load duration: \(error?.localizedDescription ?? "Unknown error")")
                completion(0)
            }
        }
    }

    @objc private func playerDidFinishPlaying(_ notification: Notification) {
        // Notify listeners that the track has ended
        trackEndedPublisher.send()
        isPlaying = false
        updateNowPlayingInfo()
    }

    // MARK: - Handle Audio Interruptions

    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        if type == .began {
            // Interruption began, pause playback
            pause()
        } else if type == .ended {
            // Interruption ended, optionally resume playback
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume), let currentTrack = currentTrack {
                    play(track: currentTrack)
                }
            }
        }
    }

    func playNextTrack() {
        // Implement logic to play the next track in the playlist
        // For example, if you have a playlist:
        // if let currentIndex = tracks.firstIndex(of: currentTrack!),
        //    currentIndex + 1 < tracks.count {
        //     let nextTrack = tracks[currentIndex + 1]
        //     play(track: nextTrack)
        // } else {
        //     // Optionally loop back to the first track
        //     selectedTrackIndex = 0
        //     play(track: tracks[0])
        // }
    }

    func playPreviousTrack() {
        // Implement logic to play the previous track in the playlist
        // For example:
        // if let currentIndex = tracks.firstIndex(of: currentTrack!),
        //    currentIndex - 1 >= 0 {
        //     let previousTrack = tracks[currentIndex - 1]
        //     play(track: previousTrack)
        // } else {
        //     // Optionally loop back to the last track
        //     selectedTrackIndex = tracks.count - 1
        //     play(track: tracks.last!)
        // }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        if let token = timeObserverToken {
            audioPlayer?.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }
}
