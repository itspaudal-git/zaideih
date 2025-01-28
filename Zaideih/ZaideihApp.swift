//
//ZaideihApp.swift
//  Zaideih
//

import SwiftUI
import Firebase

@main
struct LungdamApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
