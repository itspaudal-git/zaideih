import Foundation
import FirebaseDatabase
import Firebase

class TrackViewModel: ObservableObject {
    @Published var tracks: [Track] = []
    
    private var ref: DatabaseReference!
    
    init() {
        // Initialize Firebase if not already done
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        fetchTracks()
    }
    
    func fetchTracks() {
        ref = Database.database().reference()
        ref.child("Music").observeSingleEvent(of: .value) { snapshot in
            var tempTracks: [Track] = []
            print("Snapshot has \(snapshot.childrenCount) children")
            for child in snapshot.children {
                if let snapshot = child as? DataSnapshot,
                   let dict = snapshot.value as? [String: Any],
                   let track = self.parseTrack(dict: dict, id: snapshot.key) {
                    tempTracks.append(track)
                } else {
                    print("Failed to parse track for snapshot: \(child)")
                }
            }
            DispatchQueue.main.async {
                self.tracks = tempTracks
                print("Fetched \(self.tracks.count) tracks")
            }
        } withCancel: { error in
            print("Error fetching tracks: \(error.localizedDescription)")
        }
    }
    
    private func parseTrack(dict: [String: Any], id: String) -> Track? {
        // Required fields
        guard
            let name = dict["name"] as? Int,
            let link = dict["link"] as? String,
            let title = dict["title"] as? String
        else {
            print("Failed to parse essential fields for track: \(dict)")
            return nil
        }
        
        // Optional fields with default values
        let album = dict["album"] as? String ?? "Unknown Album"
        let art = dict["art"] as? String ?? ""
        let artist = dict["artist"] as? String ?? "Unknown Artist"
        let bitrate = dict["bitrate"] as? String ?? ""
        let genres = dict["genres"] as? String ?? ""
        let language = dict["language"] as? String ?? ""
        let lyric = dict["lyric"] as? String ?? ""
        let playcount = dict["playcount"] as? Int ?? 0
        let rating = dict["rating"] as? String ?? ""
        let type_of = dict["type"] as? String ?? ""
        let year = dict["year"] as? Int ?? 0

        return Track(
            id: id,
            album: album,
            art: art,
            artist: artist,
            bitrate: bitrate,
            genres: genres,
            language: language,
            link: link,
            lyric: lyric,
            name: name,
            playcount: playcount,
            rating: rating,
            title: title,
            type_of: type_of,
            year: year
        )
    }
}
