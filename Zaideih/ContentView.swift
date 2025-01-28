import SwiftUI
import Combine

struct ContentView: View {
    @ObservedObject var viewModel = TrackViewModel()
    @ObservedObject var audioManager = AudioPlayerManager.shared
    @StateObject private var searchManager = DebouncedSearchManager()
    
    @State private var selectedTypeOf: Set<String> = []
    @State private var selectedLanguage: Set<String> = []
    @State private var isListView: Bool = true
    @State private var searchQuery: String = ""
    
    // Track the current album and the list of songs in that album
    @State private var selectedAlbum: String?
    
    var body: some View {
        NavigationView {
            VStack {
                // Filters Section
                VStack(alignment: .leading) {
                    // Filter by Type
                    ScrollView(.horizontal) {
                        HStack {
                            ForEach(getUniqueValues(for: \.type_of), id: \.self) { type in
                                Checkbox(isChecked: selectedTypeOf.contains(type), label: type) {
                                    toggleFilter(for: type, in: &selectedTypeOf)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Filter by Language
                    ScrollView(.horizontal) {
                        HStack {
                            ForEach(getUniqueValues(for: \.language), id: \.self) { language in
                                Checkbox(isChecked: selectedLanguage.contains(language), label: language) {
                                    toggleFilter(for: language, in: &selectedLanguage)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
                
                // Search Bar with Debouncing
                TextField("Search by album, artist, title, or genres", text: $searchQuery)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                    .onChange(of: searchQuery) { newValue in
                        searchManager.debounceSearch(newValue)
                    }
                
                // View Toggle Buttons
                HStack {
                    Button("List View") {
                        isListView = true
                        selectedAlbum = nil // Reset album selection
                    }
                    .padding(8)
                    .background(isListView ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .font(.system(size: 14))
                    
                    Button("Album View") {
                        isListView = false
                    }
                    .padding(8)
                    .background(!isListView ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .font(.system(size: 14))
                }
                .padding(.bottom)
                
                // Track List / Album Grid
                if isListView {
                    // List View - Show all tracks filtered by type_of and language
                    List(filteredTracks()) { track in
                        NavigationLink(
                            destination: TrackDetailView(
                                tracks: filteredTracks(),
                                selectedTrackIndex: filteredTracks().firstIndex(of: track) ?? 0
                            )
                        ) {
                            HStack {
                                Image(systemName: "music.note")
                                    .resizable()
                                    .frame(width: 50, height: 50)
                                    .padding(.trailing, 10)
                                VStack(alignment: .leading) {
                                    Text(track.title)
                                        .font(.headline)
                                    Text(track.artist)
                                        .font(.subheadline)
                                }
                            }
                        }
                    }
                } else if let album = selectedAlbum {
                    // Show all songs in the selected album (filtered tracks)
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            ForEach(filteredTracks().filter { $0.album == album }, id: \.id) { track in
                                NavigationLink(
                                    destination: TrackDetailView(
                                        tracks: filteredTracks(),
                                        selectedTrackIndex: filteredTracks().firstIndex(of: track) ?? 0
                                    )
                                ) {
                                    HStack {
                                        Image(systemName: "music.note")
                                            .resizable()
                                            .frame(width: 50, height: 50)
                                            .padding(.trailing, 10)
                                        VStack(alignment: .leading) {
                                            Text(track.title)
                                                .font(.headline)
                                            Text(track.artist)
                                                .font(.subheadline)
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                } else {
                    // Album View - Show unique albums based on the filtered tracks
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                            ForEach(getUniqueFilteredAlbums(), id: \.self) { album in
                                VStack {
                                    Text(album)
                                        .font(.headline)
                                        .lineLimit(1)
                                        .padding()
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(10)
                                        .onTapGesture {
                                            selectedAlbum = album
                                        }
                                }
                            }
                        }
                        .padding()
                    }
                }
                

                // Currently playing track controls (if needed)
                if let currentTrack = audioManager.currentTrack {
                    VStack {
                        // Optional: Keep or remove the currently playing text
                        Text("Playing: \(currentTrack.title)")
                            .font(.subheadline)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        
                        Button(action: {
                            if audioManager.isPlaying {
                                audioManager.pause()
                            } else {
                                audioManager.play(track: currentTrack)
                            }
                        }) {
                            HStack {
                                Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20) // Smaller icon
                                Text(audioManager.isPlaying ? "Pause" : "Play")
                                    .font(.caption) // Smaller text
                            }
                            .padding(6) // Reduced padding
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                    .padding(.bottom, 10) // Adjust padding as needed
                }


            }
        }
    }
    
    // MARK: - Filtering and Helper Functions
    
    func filteredTracks() -> [Track] {
        // Apply filters for type_of, language, and search query
        return viewModel.tracks.filter { track in
            (selectedTypeOf.isEmpty || selectedTypeOf.contains(track.type_of)) &&
            (selectedLanguage.isEmpty || selectedLanguage.contains(track.language)) &&
            (searchManager.debouncedSearchQuery.isEmpty || trackMatchesSearch(track))
        }
    }
    
    // Get unique albums based on filtered tracks
    func getUniqueFilteredAlbums() -> [String] {
        let albums = filteredTracks().map { $0.album }
        return Array(Set(albums)).sorted()
    }
    
    func trackMatchesSearch(_ track: Track) -> Bool {
        return track.album.localizedCaseInsensitiveContains(searchManager.debouncedSearchQuery) ||
            track.artist.localizedCaseInsensitiveContains(searchManager.debouncedSearchQuery) ||
            track.title.localizedCaseInsensitiveContains(searchManager.debouncedSearchQuery) ||
            track.genres.localizedCaseInsensitiveContains(searchManager.debouncedSearchQuery)
    }
    
    func getUniqueValues(for keyPath: KeyPath<Track, String>) -> [String] {
        let values = viewModel.tracks.map { $0[keyPath: keyPath] }
        return Array(Set(values)).sorted()
    }
    
    func toggleFilter(for value: String, in set: inout Set<String>) {
        if set.contains(value) {
            set.remove(value)
        } else {
            set.insert(value)
        }
    }
}

// MARK: - Checkbox View
struct Checkbox: View {
    var isChecked: Bool
    var label: String
    var action: () -> Void
    
    var body: some View {
        Button(action: {
            action()
        }) {
            HStack {
                Image(systemName: isChecked ? "checkmark.square" : "square")
                Text(label)
            }
            .padding(5)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(5)
        }
    }
}
