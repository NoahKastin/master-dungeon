//
//  WidgetGameEngine.swift
//  Master Dungeon Widget
//
//  Stateless game engine: process(action, state) -> state.
//  Reconstructs Player/Enemy from codable state, uses shared game logic.
//

import Foundation

enum WidgetAction {
    case pickSpell(id: String)        // Toggle spell during selection
    case startGame                     // Begin with selected spells
    case selectSpell(id: String)      // Select spell during gameplay
    case targetDirection(index: Int)  // Cast at neighbor hex (0-5)
    case nextChallenge
    case newGame
    case showHelp                      // Show help during spell selection
    case dismissHelp                   // Dismiss help
    case showSpellInfo(id: String)    // Show spell stats mid-game
    case dismissSpellInfo              // Back to gameplay
    case backToSelection               // Return to spell selection from gameplay
}

struct WidgetGameEngine {

    // MARK: - Main Entry Point

    static func process(action: WidgetAction, state: WidgetGameState) -> WidgetGameState {
        // Ensure easy mode is set for shared game logic
        GameManager.shared.gameMode = .easy

        var s = state
        switch action {
        case .pickSpell(let id):
            return handlePickSpell(id: id, state: &s)
        case .startGame:
            return handleStartGame(state: &s)
        case .selectSpell(let id):
            return handleSelectSpell(id: id, state: &s)
        case .targetDirection(let index):
            return handleTargetDirection(index: index, state: &s)
        case .nextChallenge:
            return handleNextChallenge(state: &s)
        case .newGame:
            return createNewGame()
        case .showHelp:
            s.phase = .help
            return s
        case .dismissHelp:
            s.phase = .spellSelection
            return s
        case .showSpellInfo(let id):
            s.infoSpellID = id
            s.phase = .spellInfo
            return s
        case .dismissSpellInfo:
            s.infoSpellID = nil
            s.phase = .selectSpell
            return s
        case .backToSelection:
            return createNewGame()
        }
    }

    // MARK: - New Game

    static func createNewGame() -> WidgetGameState {
        GameManager.shared.gameMode = .easy
        GameManager.shared.challengesCompleted = 0
        GameManager.shared.totalDamageDealt = 0
        GameManager.shared.totalHealing = 0

        return WidgetGameState(
            playerHP: Player.maxHP,
            playerMaxHP: Player.maxHP,
            playerPosition: CodableHexCoord(.zero),
            spellIDs: [],
            selectedSpellID: nil,
            enemies: [],
            obstacles: [],
            blockedHexes: [],
            interactives: [],
            challengeCount: 0,
            challengeDescription: "Choose 3 spells",
            challengeHadEnemies: false,
            phase: .spellSelection,
            selectedSpellIDs: [],
            infoSpellID: nil,
            showHelp: false
        )
    }

    // MARK: - Spell Selection Phase

    private static func handlePickSpell(id: String, state: inout WidgetGameState) -> WidgetGameState {
        guard state.phase == .spellSelection else { return state }

        if state.selectedSpellIDs.contains(id) {
            state.selectedSpellIDs.remove(id)
        } else if state.selectedSpellIDs.count < 3 {
            state.selectedSpellIDs.insert(id)
        }

        if state.selectedSpellIDs.count == 3 {
            state.challengeDescription = "Tap Play to begin!"
        } else {
            state.challengeDescription = "Choose \(3 - state.selectedSpellIDs.count) more"
        }

        return state
    }

    private static func handleStartGame(state: inout WidgetGameState) -> WidgetGameState {
        guard state.phase == .spellSelection, state.selectedSpellIDs.count == 3 else { return state }

        // Build loadout
        state.spellIDs = ["move"] + state.selectedSpellIDs.sorted()

        // Generate first challenge
        return generateChallenge(state: &state)
    }

    // MARK: - Gameplay

    private static func handleSelectSpell(id: String, state: inout WidgetGameState) -> WidgetGameState {
        guard state.phase == .selectSpell else { return state }

        let spell = resolveSpell(id)

        // Range-0 spells auto-cast on player
        if spell.range == 0 {
            state.selectedSpellID = id
            return castSpell(at: .zero, state: &state)
        }

        state.selectedSpellID = id
        state.phase = .selectTarget
        return state
    }

    private static func handleTargetDirection(index: Int, state: inout WidgetGameState) -> WidgetGameState {
        guard state.phase == .selectTarget, state.selectedSpellID != nil else { return state }

        let neighbors = HexCoord.zero.neighbors()
        guard index >= 0 && index < neighbors.count else { return state }

        let target = neighbors[index]
        return castSpell(at: target, state: &state)
    }

    private static func handleNextChallenge(state: inout WidgetGameState) -> WidgetGameState {
        guard state.phase == .victory else { return state }
        return generateChallenge(state: &state)
    }

    // MARK: - Spell Casting

    private static func castSpell(at target: HexCoord, state: inout WidgetGameState) -> WidgetGameState {
        guard let spellID = state.selectedSpellID else { return state }
        let spell = resolveSpell(spellID)
        let playerPos = state.playerPosition.hexCoord

        // Movement
        if spell.id == "move" {
            let worldTarget = target + playerPos
            let blockedSet = Set(state.blockedHexes.map { $0.hexCoord })
            let enemyPositions = Set(state.enemies.map { $0.position.hexCoord })

            if blockedSet.contains(worldTarget) || enemyPositions.contains(worldTarget) {
                state.selectedSpellID = nil
                state.phase = .selectSpell
                return state
            }

            state.playerPosition = CodableHexCoord(worldTarget)
            state.selectedSpellID = nil
            state.phase = .selectSpell

            processEnemyTurns(state: &state)
            checkPlayerDeath(state: &state)
            if state.phase != .gameOver {
                checkChallengeCompletion(state: &state)
            }
            return state
        }

        // Reconstruct player and cast
        let player = reconstructPlayer(from: state)
        guard player.canCast(spell) else {
            state.selectedSpellID = nil
            state.phase = .selectSpell
            return state
        }

        let worldTarget = target + playerPos
        let result = player.castSpell(spell, at: worldTarget)

        switch result {
        case .success(let effect):
            applySpellEffect(spell: spell, at: worldTarget, effect: effect, state: &state, player: player)
        case .failure:
            state.selectedSpellID = nil
            state.phase = .selectSpell
            return state
        }

        // Sync player HP
        state.playerHP = player.hp

        // Remove dead enemies
        state.enemies.removeAll { $0.hp <= 0 }

        // Check completion before enemy turns
        checkChallengeCompletion(state: &state)

        if state.phase == .selectSpell || state.phase == .selectTarget {
            processEnemyTurns(state: &state)
            state.enemies.removeAll { $0.hp <= 0 }
            checkPlayerDeath(state: &state)
            if state.phase != .gameOver {
                checkChallengeCompletion(state: &state)
            }
        }

        state.selectedSpellID = nil
        if state.phase == .selectTarget {
            state.phase = .selectSpell
        }
        return state
    }

    // MARK: - Spell Effects

    private static func applySpellEffect(spell: Spell, at coord: HexCoord, effect: SpellEffect, state: inout WidgetGameState, player: Player) {
        var damageDealt = 0

        if spell.isOffensive {
            if spell.isAoE {
                let radius = max(1, spell.range / 2)
                let affectedHexes = coord.hexesInRange(radius)
                for i in state.enemies.indices {
                    let enemyPos = state.enemies[i].position.hexCoord
                    if affectedHexes.contains(enemyPos) {
                        let dmg = spell.rollOffense()
                        state.enemies[i].hp -= dmg
                        damageDealt += dmg
                        GameManager.shared.recordDamage(dmg)
                    }
                }
                // AoE obstacle damage
                for hex in affectedHexes {
                    damageObstacle(at: hex, damage: spell.rollOffense(), state: &state)
                }
            } else {
                for i in state.enemies.indices {
                    if state.enemies[i].position.hexCoord == coord {
                        let dmg: Int
                        if case .damage(let amount) = effect {
                            dmg = amount
                        } else {
                            dmg = spell.rollOffense()
                        }
                        state.enemies[i].hp -= dmg
                        damageDealt += dmg
                        GameManager.shared.recordDamage(dmg)
                        break
                    }
                }
            }
        }

        if spell.isDefensive {
            if spell.isOffensive && damageDealt > 0 {
                let healing = spell.rollDefense()
                player.heal(healing)
                state.playerHP = player.hp
                GameManager.shared.recordHealing(healing)
            } else if spell.isOffensive {
                // Life steal off barrier
                let blockedSet = Set(state.blockedHexes.map { $0.hexCoord })
                if blockedSet.contains(coord) {
                    let healing = spell.rollDefense()
                    player.heal(healing)
                    state.playerHP = player.hp
                    GameManager.shared.recordHealing(healing)
                }
            } else {
                // Pure healing — check NPCs first
                if let npcIdx = state.interactives.firstIndex(where: { $0.position.hexCoord == coord && $0.kind == "npc" }) {
                    let healing = spell.rollDefense()
                    state.interactives[npcIdx].currentHP = min(state.interactives[npcIdx].maxHP, state.interactives[npcIdx].currentHP + healing)
                } else {
                    if case .healing(let amount) = effect {
                        player.heal(amount)
                        state.playerHP = player.hp
                        GameManager.shared.recordHealing(amount)
                    }
                }
            }
        }

        if spell.causesParalysis {
            if spell.isAoE {
                let radius = max(1, spell.range / 2)
                let affectedHexes = coord.hexesInRange(radius)
                for i in state.enemies.indices {
                    if affectedHexes.contains(state.enemies[i].position.hexCoord) {
                        state.enemies[i].isStunned = true
                        state.enemies[i].stunTurnsRemaining = 2
                    }
                }
            } else {
                for i in state.enemies.indices {
                    if state.enemies[i].position.hexCoord == coord {
                        state.enemies[i].isStunned = true
                        state.enemies[i].stunTurnsRemaining = 2
                        break
                    }
                }
            }
        }

        if spell.producesLight {
            for i in state.interactives.indices {
                if state.interactives[i].kind == "darkness" && !state.interactives[i].dispelled {
                    let dist = coord.distance(to: state.interactives[i].position.hexCoord)
                    if dist <= state.interactives[i].radius {
                        state.interactives[i].dispelled = true
                    }
                }
            }
        }

        // Offensive spell hit nothing — try obstacle
        if spell.isOffensive && damageDealt == 0 && !spell.isAoE {
            damageObstacle(at: coord, damage: spell.rollOffense(), state: &state)
        }
    }

    @discardableResult
    private static func damageObstacle(at position: HexCoord, damage: Int, state: inout WidgetGameState) -> Bool {
        if let idx = state.obstacles.firstIndex(where: { $0.position.hexCoord == position && $0.hp > 0 }) {
            state.obstacles[idx].hp -= damage
            if state.obstacles[idx].hp <= 0 {
                state.blockedHexes.removeAll { $0.hexCoord == position }
                state.obstacles.remove(at: idx)
            }
            return true
        }
        return false
    }

    // MARK: - Enemy Turns

    private static func processEnemyTurns(state: inout WidgetGameState) {
        let playerPos = state.playerPosition.hexCoord
        let blockedSet = Set(state.blockedHexes.map { $0.hexCoord })

        for i in state.enemies.indices {
            guard state.enemies[i].hp > 0 else { continue }

            // Handle stun
            if state.enemies[i].isStunned {
                state.enemies[i].stunTurnsRemaining -= 1
                if state.enemies[i].stunTurnsRemaining <= 0 {
                    state.enemies[i].isStunned = false
                }
                continue
            }

            let enemyPos = state.enemies[i].position.hexCoord
            _ = enemyPos.distance(to: playerPos)

            // Reconstruct for AI decision
            let enemy = reconstructEnemy(from: state.enemies[i])
            let enemyPositions = Set(state.enemies.filter { $0.hp > 0 }.map { $0.position.hexCoord })
            let blocked = blockedSet.union(enemyPositions).subtracting([enemyPos])
            let action = enemy.takeTurn(playerPosition: playerPos, blocked: blocked)

            switch action {
            case .attack(_, let damage):
                state.playerHP -= damage
                GameManager.shared.recordDamage(damage)

            case .move:
                // Enemy moved internally; sync position
                state.enemies[i].position = CodableHexCoord(enemy.position)

            case .specialAttack(let type, let center, let radius, let damage):
                if type == .areaSlam {
                    let affectedHexes = center.hexesInRange(radius)
                    if affectedHexes.contains(playerPos) {
                        state.playerHP -= damage
                    }
                }

            case .healAlly(let amount, let range):
                // Find weakest ally in range
                var weakestIdx: Int?
                var weakestHP = Int.max
                for j in state.enemies.indices {
                    guard j != i, state.enemies[j].hp > 0 else { continue }
                    let allyPos = state.enemies[j].position.hexCoord
                    if enemyPos.distance(to: allyPos) <= range && state.enemies[j].hp < weakestHP {
                        weakestHP = state.enemies[j].hp
                        weakestIdx = j
                    }
                }
                if let idx = weakestIdx {
                    state.enemies[idx].hp = min(state.enemies[idx].maxHP, state.enemies[idx].hp + amount)
                }

            case .stunned, .wait:
                break
            }
        }

        // Check for merges
        checkAndMergeEnemies(state: &state)
    }

    private static func checkAndMergeEnemies(state: inout WidgetGameState) {
        var positionGroups: [CodableHexCoord: [Int]] = [:]
        for i in state.enemies.indices where state.enemies[i].hp > 0 {
            positionGroups[state.enemies[i].position, default: []].append(i)
        }

        var toRemove: Set<Int> = []
        for (_, indices) in positionGroups where indices.count >= 2 {
            // Merge into first
            let keepIdx = indices[0]
            for mergeIdx in indices.dropFirst() {
                state.enemies[keepIdx].hp += state.enemies[mergeIdx].hp
                state.enemies[keepIdx].maxHP += state.enemies[mergeIdx].maxHP
                state.enemies[keepIdx].mergeCount += state.enemies[mergeIdx].mergeCount
                state.enemies[keepIdx].isMerged = true
                toRemove.insert(mergeIdx)
            }
        }

        for idx in toRemove.sorted(by: >) {
            state.enemies.remove(at: idx)
        }
    }

    // MARK: - Challenge Generation

    private static func generateChallenge(state: inout WidgetGameState) -> WidgetGameState {
        GameManager.shared.gameMode = .easy
        GameManager.shared.challengesCompleted = state.challengeCount

        // Reset player position
        state.playerPosition = CodableHexCoord(.zero)
        state.enemies.removeAll()
        state.obstacles.removeAll()
        state.blockedHexes.removeAll()
        state.interactives.removeAll()
        state.challengeHadEnemies = false
        state.selectedSpellID = nil

        // Build loadout from spell IDs
        let loadout = buildLoadout(from: state.spellIDs)

        let difficulty = 1 + state.challengeCount / ChallengeAI.bossInterval
        let generator = ChallengeGenerator()
        let challenge = generator.generateChallenge(for: loadout, difficulty: difficulty)

        state.challengeDescription = challenge.description

        // Place elements, clamped to 7-hex grid
        var usedPositions: Set<HexCoord> = [.zero]
        for element in challenge.elements {
            var relativePos = element.position
            if relativePos.distance(to: .zero) > 1 {
                let neighbors = HexCoord.zero.neighbors().filter { !usedPositions.contains($0) }
                if let nearest = neighbors.first {
                    relativePos = nearest
                }
            }
            usedPositions.insert(relativePos)

            if case .obstacle(let blocking, _) = element.type, blocking {
                state.blockedHexes.append(CodableHexCoord(relativePos))
            }

            if let enemy = EnemyFactory.createEnemy(from: element, at: relativePos) {
                state.enemies.append(CodableEnemy(
                    id: enemy.id.uuidString,
                    hp: enemy.hp,
                    maxHP: enemy.maxHP,
                    damage: enemy.damage,
                    behavior: behaviorString(enemy.behavior),
                    position: CodableHexCoord(relativePos),
                    isStunned: false,
                    stunTurnsRemaining: 0,
                    isMerged: false,
                    mergeCount: 1
                ))
                state.challengeHadEnemies = true
            } else {
                if let interactive = createInteractive(from: element, at: relativePos) {
                    state.interactives.append(interactive)
                }
            }
        }

        state.phase = .selectSpell
        return state
    }

    private static func createInteractive(from element: ChallengeElement, at position: HexCoord) -> CodableInteractive? {
        switch element.type {
        case .target:
            return CodableInteractive(position: CodableHexCoord(position), kind: "target",
                                       currentHP: 0, maxHP: 0, radius: 0, dispelled: false,
                                       activatesId: "", isCompleted: false)
        case .npc(let needsHealing, _):
            if needsHealing {
                let hp = element.properties["hp"] as? Int ?? 1
                let maxHP = element.properties["maxHp"] as? Int ?? 3
                return CodableInteractive(position: CodableHexCoord(position), kind: "npc",
                                           currentHP: hp, maxHP: maxHP, radius: 0, dispelled: false,
                                           activatesId: "", isCompleted: false)
            }
            return CodableInteractive(position: CodableHexCoord(position), kind: "target",
                                       currentHP: 0, maxHP: 0, radius: 0, dispelled: false,
                                       activatesId: "", isCompleted: false)
        case .darkness(let radius):
            return CodableInteractive(position: CodableHexCoord(position), kind: "darkness",
                                       currentHP: 0, maxHP: 0, radius: radius, dispelled: false,
                                       activatesId: "", isCompleted: false)
        case .trigger(let activates):
            return CodableInteractive(position: CodableHexCoord(position), kind: "trigger",
                                       currentHP: 0, maxHP: 0, radius: 0, dispelled: false,
                                       activatesId: activates, isCompleted: false)
        case .obstacle(_, let destructible):
            if destructible {
                return nil // Obstacles handled separately via state.obstacles
            }
            return nil
        default:
            return nil
        }
    }

    // MARK: - Challenge Completion

    private static func checkChallengeCompletion(state: inout WidgetGameState) {
        guard state.phase == .selectSpell || state.phase == .selectTarget else { return }

        let aliveEnemies = state.enemies.filter { $0.hp > 0 }

        // Combat: all enemies dead
        if state.challengeHadEnemies && aliveEnemies.isEmpty {
            completeChallenge(state: &state)
            return
        }

        // Target-based: player reached all targets
        let targets = state.interactives.filter { $0.kind == "target" }
        if !targets.isEmpty {
            let playerPos = state.playerPosition.hexCoord
            let allReached = targets.allSatisfy { playerPos.distance(to: $0.position.hexCoord) <= 1 }
            if allReached && aliveEnemies.isEmpty {
                completeChallenge(state: &state)
                return
            }
        }

        // NPC rescue: all healed
        let npcs = state.interactives.filter { $0.kind == "npc" }
        if !npcs.isEmpty {
            let allHealed = npcs.allSatisfy { $0.currentHP >= $0.maxHP }
            if allHealed && aliveEnemies.isEmpty {
                completeChallenge(state: &state)
                return
            }
        }

        // Puzzle: all darkness dispelled + targets reached
        let darkness = state.interactives.filter { $0.kind == "darkness" }
        if !darkness.isEmpty {
            let allDispelled = darkness.allSatisfy { $0.dispelled }
            let playerPos = state.playerPosition.hexCoord
            let allTargetsReached = targets.allSatisfy { playerPos.distance(to: $0.position.hexCoord) <= 1 }
            if allDispelled && (targets.isEmpty || allTargetsReached) {
                completeChallenge(state: &state)
                return
            }
        }
    }

    private static func completeChallenge(state: inout WidgetGameState) {
        state.challengeCount += 1
        GameManager.shared.completeChallenge()
        state.challengeDescription = "Victory!"
        state.phase = .victory
        state.selectedSpellID = nil
    }

    private static func checkPlayerDeath(state: inout WidgetGameState) {
        if state.playerHP <= 0 {
            state.phase = .gameOver
            state.challengeDescription = "Game Over"
            state.selectedSpellID = nil
        }
    }

    // MARK: - Helpers

    static func resolveSpell(_ id: String) -> Spell {
        if id == "move" { return SpellData.moveSpell }
        return SpellData.easySpells.first { $0.id == id } ?? SpellData.moveSpell
    }

    private static func buildLoadout(from spellIDs: [String]) -> SpellLoadout {
        var loadout = SpellLoadout()
        for id in spellIDs where id != "move" {
            if let spell = SpellData.easySpells.first(where: { $0.id == id }) {
                _ = loadout.addSpell(spell)
            }
        }
        return loadout
    }

    private static func reconstructPlayer(from state: WidgetGameState) -> Player {
        let player = Player()
        let loadout = buildLoadout(from: state.spellIDs)
        player.setLoadout(loadout)
        // Set HP to match state
        let damage = state.playerMaxHP - state.playerHP
        if damage > 0 {
            player.takeDamage(damage)
        }
        player.teleport(to: state.playerPosition.hexCoord)
        return player
    }

    private static func reconstructEnemy(from codable: CodableEnemy) -> Enemy {
        let behavior = parseBehavior(codable.behavior)
        let enemy = Enemy(hp: codable.hp, maxHP: codable.maxHP, damage: codable.damage,
                          behavior: behavior, position: codable.position.hexCoord,
                          isMerged: codable.isMerged, mergeCount: codable.mergeCount)
        if codable.isStunned {
            enemy.stun(turns: codable.stunTurnsRemaining)
        }
        return enemy
    }

    private static func behaviorString(_ behavior: EnemyBehavior) -> String {
        switch behavior {
        case .aggressive: return "aggressive"
        case .defensive: return "defensive"
        case .ranged: return "ranged"
        case .healer: return "healer"
        case .swarm: return "swarm"
        case .boss: return "boss"
        }
    }

    private static func parseBehavior(_ string: String) -> EnemyBehavior {
        switch string {
        case "defensive": return .defensive
        case "ranged": return .ranged
        case "healer": return .healer
        case "swarm": return .swarm
        case "boss": return .boss
        default: return .aggressive
        }
    }
}
