//
//  ContentView.swift
//  Zaideih
//

import SwiftUI
import Combine

struct ContentView: View {
    // MARK: - Observed Objects and State
    @ObservedObject var viewModel = TrackViewModel()
    @ObservedObject var audioManager = AudioPlayerManager.shared
    @StateObject private var searchManager = DebouncedSearchManager()
    
    // MARK: - Filter States
    // "All" is the default selection for each filter to show everything initially.
    @State private var selectedTypeOf: Set<String> = ["All"]
    @State private var selectedLanguage: Set<String> = ["All"]
    @State private var selectedArtist: Set<String> = ["All"]
    
    // MARK: - View Toggles and Search
    @State private var isListView: Bool = true
    @State private var searchQuery: String = ""
    @State private var showSearchBar: Bool = false
    
    // MARK: - Album Selection
    @State private var selectedAlbum: String?
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            VStack(spacing: 8) {
                // 1. Filters and Search Button Row
                HStack(spacing: 6) {
                    // Type Dropdown
                    FilterDropdown(
                        title: "Type",
                        options: getUniqueValues(for: \.type_of),
                        selections: $selectedTypeOf
                    )
                    
                    // Language Dropdown
                    FilterDropdown(
                        title: "Language",
                        options: getUniqueValues(for: \.language),
                        selections: $selectedLanguage
                    )
                    
                    // Artist Dropdown
                    FilterDropdown(
                        title: "Artist",
                        options: getUniqueValues(for: \.artist),
                        selections: $selectedArtist
                    )
                    
                    // Search Toggle Button (circular)
                    Button(action: {
                        withAnimation {
                            showSearchBar.toggle()
                        }
                    }) {
                        Image(systemName: "magnifyingglass")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .padding(6)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // 2. Search Bar (Visible if toggled)
                if showSearchBar {
                    TextField("Search by album, artist, title, or genres", text: $searchQuery)
                        .font(.caption)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding([.horizontal, .top], 6)
                        .onChange(of: searchQuery) { newValue in
                            searchManager.debounceSearch(newValue)
                        }
                }
                
                // 3. View Toggle Buttons (List View vs. Album View)
                HStack(spacing: 8) {
                    Button("List View") {
                        isListView = true
                        selectedAlbum = nil // Reset album selection
                    }
                    .font(.caption)
                    .padding(6)
                    .background(isListView ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    Button("Album View") {
                        isListView = false
                    }
                    .font(.caption)
                    .padding(6)
                    .background(!isListView ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(.bottom, 6)
                
                // 4. Main Content: Track List or Album Grid
                if isListView {
                    // List View - Filtered tracks displayed in a List
                    List(filteredTracks()) { track in
                        NavigationLink(
                            destination: TrackDetailView(
                                tracks: filteredTracks(),
                                selectedTrackIndex: filteredTracks().firstIndex(of: track) ?? 0
                            )
                        ) {
                            HStack(spacing: 8) {
                                Image(systemName: "music.note")
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(track.title)
                                        .font(.subheadline)
                                    Text(track.artist)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                } else if let album = selectedAlbum {
                    // Album Detail View (all songs in the selected album)
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredTracks().filter { $0.album == album }, id: \.id) { track in
                                NavigationLink(
                                    destination: TrackDetailView(
                                        tracks: filteredTracks(),
                                        selectedTrackIndex: filteredTracks().firstIndex(of: track) ?? 0
                                    )
                                ) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "music.note")
                                            .resizable()
                                            .frame(width: 40, height: 40)
                                            .foregroundColor(.secondary)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(track.title)
                                                .font(.subheadline)
                                            Text(track.artist)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                } else {
                    // Album Grid View (unique albums from the filtered tracks)
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(getUniqueFilteredAlbums(), id: \.self) { album in
                                VStack(spacing: 4) {
                                    Text(album)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                        .padding(8)
                                        .foregroundColor(.primary)
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(6)
                                        .onTapGesture {
                                            selectedAlbum = album
                                        }
                                }
                            }
                        }
                        .padding()
                    }
                }
                
                // 5. Currently Playing Track Controls (if any)
                if let currentTrack = audioManager.currentTrack {
                    VStack(spacing: 4) {
                        Text("Playing: \(currentTrack.title)")
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        
                        Button(action: {
                            if audioManager.isPlaying {
                                audioManager.pause()
                            } else {
                                audioManager.play(track: currentTrack)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 14, height: 14)
                                Text(audioManager.isPlaying ? "Pause" : "Play")
                                    .font(.caption)
                            }
                            .padding(4)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
            // We remove the navigationBarTitle as requested:
            // .navigationBarTitle("Zaideih", displayMode: .inline)
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Helper Functions
    
    /// Filters the tracks based on selected filters and the debounced search query.
    func filteredTracks() -> [Track] {
        viewModel.tracks.filter { track in
            // Check Type filter: if "All" is selected, skip filtering for that category
            let typeMatches = selectedTypeOf.contains("All") || selectedTypeOf.contains(track.type_of)
            
            // Check Language filter
            let languageMatches = selectedLanguage.contains("All") || selectedLanguage.contains(track.language)
            
            // Check Artist filter
            let artistMatches = selectedArtist.contains("All") || selectedArtist.contains(track.artist)
            
            // Search query matches
            let queryMatches = searchManager.debouncedSearchQuery.isEmpty || trackMatchesSearch(track)
            
            return typeMatches && languageMatches && artistMatches && queryMatches
        }
    }
    
    /// Gets a list of unique albums from the filtered tracks.
    func getUniqueFilteredAlbums() -> [String] {
        let albums = filteredTracks().map { $0.album }
        return Array(Set(albums)).sorted()
    }
    
    /// Checks if a track matches the current search query.
    func trackMatchesSearch(_ track: Track) -> Bool {
        track.album.localizedCaseInsensitiveContains(searchManager.debouncedSearchQuery)
        || track.artist.localizedCaseInsensitiveContains(searchManager.debouncedSearchQuery)
        || track.title.localizedCaseInsensitiveContains(searchManager.debouncedSearchQuery)
        || track.genres.localizedCaseInsensitiveContains(searchManager.debouncedSearchQuery)
    }
    
    /// Retrieves a sorted array of unique values for a specific `Track` key path, plus "All" at the start.
    func getUniqueValues(for keyPath: KeyPath<Track, String>) -> [String] {
        let allValues = viewModel.tracks.map { $0[keyPath: keyPath] }
        let unique = Array(Set(allValues)).sorted()
        // Prepend "All" so it appears first in the dropdown
        return ["All"] + unique
    }
}

// MARK: - FilterDropdown View
struct FilterDropdown: View {
    let title: String
    let options: [String]
    @Binding var selections: Set<String>
    
    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button {
                    toggleSelection(for: option)
                } label: {
                    HStack {
                        Text(option)
                            .font(.caption)
                        Spacer()
                        if selections.contains(option) {
                            Image(systemName: "checkmark")
                                .font(.caption)
                        }
                    }
                }
            }
        } label: {
            // Smaller button style
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white)
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .padding(6)
            .background(Color.blue)
            .cornerRadius(6)
        }
    }
    
    /// Toggles the selection state of a specific option.
    private func toggleSelection(for option: String) {
        // If user taps "All", reset to only "All"
        if option == "All" {
            selections = ["All"]
            return
        }
        // Otherwise, remove "All" if previously selected
        if selections.contains("All") {
            selections.remove("All")
        }
        // Then toggle this particular option
        if selections.contains(option) {
            selections.remove(option)
            // If we removed the last option and everything is empty, put back "All"
            if selections.isEmpty {
                selections = ["All"]
            }
        } else {
            selections.insert(option)
        }
    }
}
