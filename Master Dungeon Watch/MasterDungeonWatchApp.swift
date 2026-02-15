//
//  MasterDungeonWatchApp.swift
//  Master Dungeon Watch
//
//  Entry point for the watchOS app.
//

import SwiftUI

@main
struct MasterDungeonWatchApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WatchSpellSelectionView()
            }
        }
    }
}
