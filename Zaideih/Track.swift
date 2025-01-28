//
//Track.swift
//  Zaideih
//

import Foundation

struct Track: Identifiable, Equatable {
    let id: String
    let album: String
    let art: String
    let artist: String
    let bitrate: String
    let genres: String
    let language: String
    let link: String
    let lyric: String
    let name: Int
    let playcount: Int
    let rating: String
    let title: String
    let type_of: String
    let year: Int



    // Equatable conformance (if needed)
    static func ==(lhs: Track, rhs: Track) -> Bool {
        return lhs.id == rhs.id
    }
}
