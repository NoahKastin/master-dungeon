//
//  WidgetGameState.swift
//  Master Dungeon Widget
//
//  Codable game state for persistence between widget interactions.
//

import Foundation

/// Serializable hex coordinate
struct CodableHexCoord: Codable, Hashable {
    let q: Int
    let r: Int

    var hexCoord: HexCoord { HexCoord(q: q, r: r) }
    init(_ coord: HexCoord) { q = coord.q; r = coord.r }
    init(q: Int, r: Int) { self.q = q; self.r = r }
}

/// Serializable enemy
struct CodableEnemy: Codable, Identifiable {
    let id: String
    var hp: Int
    var maxHP: Int
    var damage: Int
    var behavior: String
    var position: CodableHexCoord
    var isStunned: Bool
    var stunTurnsRemaining: Int
    var isMerged: Bool
    var mergeCount: Int
}

/// Serializable obstacle
struct CodableObstacle: Codable {
    var position: CodableHexCoord
    var hp: Int
    var obstacleId: String
}

/// Serializable interactive element (targets, NPCs, darkness, triggers)
struct CodableInteractive: Codable {
    var position: CodableHexCoord
    var kind: String  // "target", "npc", "darkness", "trigger"
    var currentHP: Int
    var maxHP: Int
    var radius: Int
    var dispelled: Bool
    var activatesId: String
    var isCompleted: Bool
}

/// Full game state snapshot
struct WidgetGameState: Codable {
    var playerHP: Int
    var playerMaxHP: Int
    var playerPosition: CodableHexCoord

    var spellIDs: [String]
    var selectedSpellID: String?

    var enemies: [CodableEnemy]
    var obstacles: [CodableObstacle]
    var blockedHexes: [CodableHexCoord]
    var interactives: [CodableInteractive]

    var challengeCount: Int
    var challengeDescription: String
    var challengeHadEnemies: Bool
    var phase: InteractionPhase

    /// Spells available for selection (only used during spellSelection phase)
    var selectedSpellIDs: Set<String>

    /// Spell ID to show info for (used in spellInfo phase)
    var infoSpellID: String?

    /// Whether help overlay is shown during spell selection
    var showHelp: Bool

    enum InteractionPhase: String, Codable {
        case spellSelection
        case help
        case selectSpell
        case selectTarget
        case spellInfo
        case victory
        case gameOver
    }
}

// MARK: - Persistence

enum WidgetStateStore {
    static let stateKey = "widgetGameState"

    static func load() -> WidgetGameState? {
        guard let data = UserDefaults.standard.data(forKey: stateKey) else { return nil }
        return try? JSONDecoder().decode(WidgetGameState.self, from: data)
    }

    static func save(_ state: WidgetGameState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: stateKey)
    }
}
