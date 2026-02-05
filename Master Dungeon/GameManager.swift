//
//  GameManager.swift
//  Master Dungeon
//
//  Singleton to manage game state between scenes.
//

import Foundation

enum GameMode {
    case normal
    case hardcore
}

class GameManager {
    static let shared = GameManager()

    private init() {}

    // Game mode
    var gameMode: GameMode = .normal

    // Current loadout selected by player
    var currentLoadout: SpellLoadout = SpellLoadout()

    // Game statistics
    var challengesCompleted: Int = 0
    var totalDamageDealt: Int = 0
    var totalHealing: Int = 0

    // Multiplayer loadouts (for future P2P)
    var playerLoadouts: [Int: SpellLoadout] = [:]

    func reset() {
        gameMode = .normal
        currentLoadout = SpellLoadout()
        challengesCompleted = 0
        totalDamageDealt = 0
        totalHealing = 0
        playerLoadouts.removeAll()
    }

    func recordDamage(_ amount: Int) {
        totalDamageDealt += amount
    }

    func recordHealing(_ amount: Int) {
        totalHealing += amount
    }

    func completeChallenge() {
        challengesCompleted += 1
    }
}
