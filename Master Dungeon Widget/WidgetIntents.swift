//
//  WidgetIntents.swift
//  Master Dungeon Widget
//
//  AppIntents for widget interactions.
//

import AppIntents
import WidgetKit

private func loadState() -> WidgetGameState {
    WidgetStateStore.load() ?? WidgetGameEngine.createNewGame()
}

struct PickSpellIntent: AppIntent {
    static var title: LocalizedStringResource = "Pick Spell"

    @Parameter(title: "Spell ID")
    var spellID: String

    init() { self.spellID = "" }
    init(spellID: String) { self.spellID = spellID }

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            var state = loadState()
            state = WidgetGameEngine.process(action: .pickSpell(id: spellID), state: state)
            WidgetStateStore.save(state)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "DungeonWidget")
        return .result()
    }
}

struct StartGameIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Game"

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            var state = loadState()
            state = WidgetGameEngine.process(action: .startGame, state: state)
            WidgetStateStore.save(state)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "DungeonWidget")
        return .result()
    }
}

struct SelectSpellIntent: AppIntent {
    static var title: LocalizedStringResource = "Select Spell"

    @Parameter(title: "Spell ID")
    var spellID: String

    init() { self.spellID = "" }
    init(spellID: String) { self.spellID = spellID }

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            var state = loadState()
            state = WidgetGameEngine.process(action: .selectSpell(id: spellID), state: state)
            WidgetStateStore.save(state)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "DungeonWidget")
        return .result()
    }
}

struct TargetHexIntent: AppIntent {
    static var title: LocalizedStringResource = "Target Hex"

    @Parameter(title: "Direction Index")
    var directionIndex: Int

    init() { self.directionIndex = 0 }
    init(directionIndex: Int) { self.directionIndex = directionIndex }

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            var state = loadState()
            state = WidgetGameEngine.process(action: .targetDirection(index: directionIndex), state: state)
            WidgetStateStore.save(state)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "DungeonWidget")
        return .result()
    }
}

struct NextChallengeIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Challenge"

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            var state = loadState()
            state = WidgetGameEngine.process(action: .nextChallenge, state: state)
            WidgetStateStore.save(state)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "DungeonWidget")
        return .result()
    }
}

struct NewGameIntent: AppIntent {
    static var title: LocalizedStringResource = "New Game"

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            let state = WidgetGameEngine.createNewGame()
            WidgetStateStore.save(state)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "DungeonWidget")
        return .result()
    }
}

struct ShowHelpIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Help"

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            var state = loadState()
            state = WidgetGameEngine.process(action: .showHelp, state: state)
            WidgetStateStore.save(state)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "DungeonWidget")
        return .result()
    }
}

struct DismissHelpIntent: AppIntent {
    static var title: LocalizedStringResource = "Dismiss Help"

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            var state = loadState()
            state = WidgetGameEngine.process(action: .dismissHelp, state: state)
            WidgetStateStore.save(state)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "DungeonWidget")
        return .result()
    }
}

struct ShowSpellInfoIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Spell Info"

    @Parameter(title: "Spell ID")
    var spellID: String

    init() { self.spellID = "" }
    init(spellID: String) { self.spellID = spellID }

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            var state = loadState()
            state = WidgetGameEngine.process(action: .showSpellInfo(id: spellID), state: state)
            WidgetStateStore.save(state)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "DungeonWidget")
        return .result()
    }
}

struct DismissSpellInfoIntent: AppIntent {
    static var title: LocalizedStringResource = "Dismiss Spell Info"

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            var state = loadState()
            state = WidgetGameEngine.process(action: .dismissSpellInfo, state: state)
            WidgetStateStore.save(state)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "DungeonWidget")
        return .result()
    }
}

struct BackToSelectionIntent: AppIntent {
    static var title: LocalizedStringResource = "Back to Selection"

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            var state = loadState()
            state = WidgetGameEngine.process(action: .backToSelection, state: state)
            WidgetStateStore.save(state)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "DungeonWidget")
        return .result()
    }
}
