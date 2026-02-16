//
//  DungeonWidget.swift
//  Master Dungeon Widget
//
//  TimelineProvider and Widget definition.
//

import WidgetKit
import SwiftUI

struct DungeonWidgetEntry: TimelineEntry {
    let date: Date
    let state: WidgetGameState
}

struct DungeonWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> DungeonWidgetEntry {
        DungeonWidgetEntry(date: .now, state: WidgetGameEngine.createNewGame())
    }

    func getSnapshot(in context: Context, completion: @escaping (DungeonWidgetEntry) -> Void) {
        let state = loadOrCreateState()
        completion(DungeonWidgetEntry(date: .now, state: state))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DungeonWidgetEntry>) -> Void) {
        let state = loadOrCreateState()
        let entry = DungeonWidgetEntry(date: .now, state: state)
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }

    private func loadOrCreateState() -> WidgetGameState {
        if let state = WidgetStateStore.load() { return state }
        let newState = WidgetGameEngine.createNewGame()
        WidgetStateStore.save(newState)
        return newState
    }
}

struct DungeonWidget: Widget {
    let kind: String = "DungeonWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DungeonWidgetProvider()) { entry in
            WidgetEntryView(state: entry.state)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("Master Dungeon")
        .description("Play a quick dungeon challenge!")
        .supportedFamilies([.systemMedium])
    }
}
