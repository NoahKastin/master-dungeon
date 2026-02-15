//
//  WatchGameEngine.swift
//  Master Dungeon Watch
//
//  Turn-based game loop for watchOS, ported from GameScene.
//

import SwiftUI
import WatchKit

/// Content occupying a hex on the grid
enum HexContent {
    case empty
    case player
    case enemy(Enemy)
    case obstacle(hp: Int)
    case npc(currentHP: Int, maxHP: Int)
    case target
    case darkness(dispelled: Bool)
    case hazard
}

/// Interactive element tracking (mirrored from GameScene)
struct WatchInteractiveElement: Identifiable {
    let id = UUID()
    var position: HexCoord
    var type: InteractiveType
    var isCompleted: Bool = false

    enum InteractiveType {
        case target
        case npc(currentHP: Int, maxHP: Int)
        case trigger(activatesId: String)
        case obstacle(id: String, hp: Int)
        case darkness(radius: Int, dispelled: Bool)
    }
}

/// Events emitted by the engine for the UI to react to
enum GameEvent: Equatable {
    case damage(Int, at: HexCoord)
    case healing(Int, at: HexCoord)
    case enemyKilled(at: HexCoord)
    case stunned(at: HexCoord)
    case statusText(String, at: HexCoord)
    case challengeComplete
    case playerHit(Int)
    case spellCast
}

@Observable
final class WatchGameEngine {
    // MARK: - Published State

    var playerHP: Int = Player.maxHP
    var playerMaxHP: Int = Player.maxHP
    var challengeDescription: String = ""
    var challengeCount: Int = 0
    var isGameOver: Bool = false
    var selectedSpellIndex: Int = 0
    var targetDirectionIndex: Int = 0
    var isTargeting: Bool = false
    var highlightedHex: HexCoord? = nil
    var isProcessingTurn: Bool = false
    var latestEvent: GameEvent? = nil
    var eventCounter: Int = 0

    // Grid state
    var hexContents: [HexCoord: HexContent] = [:]

    // The 7 hex coords visible in Easy mode (center + 6 neighbors)
    let visibleHexes: [HexCoord] = {
        let center = HexCoord.zero
        return [center] + center.neighbors()
    }()

    // MARK: - Internal State

    private(set) var spells: [Spell] = []
    private var player: Player!
    private var activeEnemies: [Enemy] = []
    private var interactiveElements: [UUID: WatchInteractiveElement] = [:]
    private var challengeGenerator: ChallengeGenerator!
    private var currentChallenge: Challenge?
    private var blockedHexes: Set<HexCoord> = []
    private var challengeHadEnemies: Bool = false
    private var challengeCompleted: Bool = false
    private var challengeTimer: TimeInterval = 0
    private var challengeTimeLimit: TimeInterval = 0
    private var playerDetected: Bool = false

    var selectedSpell: Spell? {
        guard spells.indices.contains(selectedSpellIndex) else { return nil }
        return spells[selectedSpellIndex]
    }

    // MARK: - Game Lifecycle

    func startGame(with loadout: SpellLoadout) {
        GameManager.shared.gameMode = .easy
        GameManager.shared.challengesCompleted = 0
        GameManager.shared.totalDamageDealt = 0
        GameManager.shared.totalHealing = 0

        player = Player()
        player.setLoadout(loadout)
        spells = [SpellData.moveSpell] + loadout.spells

        challengeGenerator = ChallengeGenerator()

        playerHP = player.hp
        playerMaxHP = Player.maxHP
        challengeCount = 0
        isGameOver = false
        selectedSpellIndex = 0
        isTargeting = false
        challengeCompleted = false

        generateNewChallenge()
    }

    // MARK: - Spell Selection (Crown)

    func selectSpellIndex(_ index: Int) {
        guard !isProcessingTurn else { return }
        let count = spells.count
        guard count > 0 else { return }
        selectedSpellIndex = ((index % count) + count) % count
        // If we were targeting, exit targeting when switching spells
        if isTargeting {
            isTargeting = false
            highlightedHex = nil
        }
    }

    // MARK: - Targeting

    func enterTargeting() {
        guard !isProcessingTurn, let spell = selectedSpell else { return }

        // Range-0 spells auto-cast on player hex
        if spell.range == 0 {
            castSpell(at: .zero)
            return
        }

        isTargeting = true
        targetDirectionIndex = 0
        updateHighlightedHex()
    }

    func cycleTarget(_ index: Int) {
        guard isTargeting else { return }
        let validTargets = validTargetHexes()
        guard !validTargets.isEmpty else { return }
        targetDirectionIndex = ((index % validTargets.count) + validTargets.count) % validTargets.count
        updateHighlightedHex()
    }

    func confirmCast() {
        guard isTargeting, let target = highlightedHex else { return }
        isTargeting = false
        highlightedHex = nil
        castSpell(at: target)
    }

    func cancelTargeting() {
        isTargeting = false
        highlightedHex = nil
    }

    // MARK: - Private Helpers

    private func validTargetHexes() -> [HexCoord] {
        guard let spell = selectedSpell else { return [] }
        let neighbors = HexCoord.zero.neighbors()

        if spell.isAoE {
            // AoE in easy mode can't target self
            return neighbors
        }
        // Single target: only hexes with something on them, or all neighbors
        return neighbors
    }

    private func updateHighlightedHex() {
        let targets = validTargetHexes()
        guard !targets.isEmpty else {
            highlightedHex = nil
            return
        }
        let idx = ((targetDirectionIndex % targets.count) + targets.count) % targets.count
        highlightedHex = targets[idx]
    }

    // MARK: - Spell Casting

    private func castSpell(at target: HexCoord) {
        guard let spell = selectedSpell, !isProcessingTurn else { return }

        // Movement spell — move player instead of casting
        if spell.id == "move" {
            let worldTarget = target + player.position
            // Can't move onto blocked hexes or enemies
            if blockedHexes.contains(worldTarget) { return }
            if enemyAt(worldTarget) != nil { return }

            isProcessingTurn = true
            player.teleport(to: worldTarget)
            emitEvent(.spellCast)

            // Process enemy turns after moving
            if !challengeCompleted && !isGameOver {
                processEnemyTurns()
                removeDeadEnemies()
                checkPlayerDeath()
            }

            if !challengeCompleted && !isGameOver {
                checkChallengeCompletion()
            }

            refreshHexContents()
            isProcessingTurn = false
            return
        }

        guard player.canCast(spell) else { return }

        isProcessingTurn = true

        // World position (player always at 0,0 in easy mode)
        let worldTarget = target + player.position

        let result = player.castSpell(spell, at: worldTarget)

        switch result {
        case .success(let effect):
            emitEvent(.spellCast)
            applySpellEffect(spell: spell, at: worldTarget, effect: effect)
        case .failure:
            isProcessingTurn = false
            return
        }

        // Remove dead enemies
        removeDeadEnemies()

        // Check completion before enemy turns
        if !challengeCompleted {
            checkChallengeCompletion()
        }

        if !challengeCompleted && !isGameOver {
            processEnemyTurns()
            removeDeadEnemies()
            checkPlayerDeath()

            if !challengeCompleted && !isGameOver {
                checkChallengeCompletion()
            }
        }

        refreshHexContents()
        isProcessingTurn = false
    }

    // MARK: - Spell Effect Resolution

    private func applySpellEffect(spell: Spell, at coord: HexCoord, effect: SpellEffect) {
        var damageDealt = 0

        // Offensive spells
        if spell.isOffensive {
            if spell.isAoE {
                let radius = max(1, spell.range / 2)
                let affectedHexes = coord.hexesInRange(radius)
                for hex in affectedHexes {
                    if let enemy = enemyAt(hex) {
                        let damage = spell.rollOffense()
                        enemy.takeDamage(damage)
                        damageDealt += damage
                        GameManager.shared.recordDamage(damage)
                        emitEvent(.damage(damage, at: hex - player.position))
                    } else if damageObstacleAt(hex, damage: spell.rollOffense()) {
                        // Obstacle hit
                    }
                }
            } else {
                if let enemy = enemyAt(coord) {
                    if case .damage(let amount) = effect {
                        enemy.takeDamage(amount)
                        damageDealt = amount
                        GameManager.shared.recordDamage(amount)
                        emitEvent(.damage(amount, at: coord - player.position))
                    } else {
                        let damage = spell.rollOffense()
                        enemy.takeDamage(damage)
                        damageDealt = damage
                        GameManager.shared.recordDamage(damage)
                        emitEvent(.damage(damage, at: coord - player.position))
                    }
                }
            }
        }

        // Healing spells
        if spell.isDefensive {
            if spell.isOffensive && damageDealt > 0 {
                // Life steal
                let healing = spell.rollDefense()
                player.heal(healing)
                playerHP = player.hp
                GameManager.shared.recordHealing(healing)
                emitEvent(.healing(healing, at: .zero))
            } else if spell.isOffensive && blockedHexes.contains(coord) {
                // Life steal off barrier
                let healing = spell.rollDefense()
                player.heal(healing)
                playerHP = player.hp
                GameManager.shared.recordHealing(healing)
                emitEvent(.healing(healing, at: .zero))
            } else if !spell.isOffensive {
                // Pure healing — check for NPCs first
                if let healAmount = healNPCAt(coord, amount: spell.rollDefense()) {
                    emitEvent(.healing(healAmount, at: coord - player.position))
                } else {
                    if case .healing(let amount) = effect {
                        player.heal(amount)
                        playerHP = player.hp
                        GameManager.shared.recordHealing(amount)
                        emitEvent(.healing(amount, at: .zero))
                    }
                }
            }
        }

        // Crowd control
        if spell.causesParalysis {
            if spell.isAoE {
                let radius = max(1, spell.range / 2)
                let affectedHexes = coord.hexesInRange(radius)
                for hex in affectedHexes {
                    if let enemy = enemyAt(hex) {
                        enemy.stun(turns: 2)
                        emitEvent(.stunned(at: hex - player.position))
                    }
                }
            } else if let enemy = enemyAt(coord) {
                enemy.stun(turns: 2)
                emitEvent(.stunned(at: coord - player.position))
            }
        }

        // Illumination (dispel darkness)
        if spell.producesLight {
            dispelDarknessAt(coord)
        }

        // Damage destructible obstacles (if no enemy hit)
        if spell.isOffensive && damageDealt == 0 {
            _ = damageObstacleAt(coord, damage: spell.rollOffense())
        }
    }

    // MARK: - Enemy Turns

    private func processEnemyTurns() {
        let enemyPositions = Set(activeEnemies.filter { $0.isAlive }.map { $0.position })
        let pathBlocked = blockedHexes.union(enemyPositions)

        for enemy in activeEnemies where enemy.isAlive {
            let blockedForThisEnemy = pathBlocked.subtracting([enemy.position])
            let action = enemy.takeTurn(playerPosition: player.position, blocked: blockedForThisEnemy)

            switch action {
            case .attack(_, let damage):
                player.takeDamage(damage)
                playerHP = player.hp
                emitEvent(.playerHit(damage))

            case .move:
                break // Movement already happened in takeTurn

            case .specialAttack(let type, let center, let radius, let damage):
                if type == .areaSlam {
                    let affectedHexes = center.hexesInRange(radius)
                    if affectedHexes.contains(player.position) {
                        player.takeDamage(damage)
                        playerHP = player.hp
                        emitEvent(.playerHit(damage))
                    }
                }

            case .healAlly(let amount, let range):
                let allies = activeEnemies.filter { ally in
                    ally.id != enemy.id &&
                    ally.isAlive &&
                    ally.hp < ally.maxHP &&
                    enemy.position.distance(to: ally.position) <= range
                }
                if let target = allies.min(by: { $0.hp < $1.hp }) {
                    target.heal(amount)
                }

            case .stunned, .wait:
                break
            }
        }

        checkAndMergeEnemies()
    }

    // MARK: - Challenge Generation

    private func generateNewChallenge() {
        let difficulty = 1 + GameManager.shared.challengesCompleted / ChallengeAI.bossInterval
        currentChallenge = challengeGenerator.generateChallenge(for: player.loadout, difficulty: difficulty)
        challengeDescription = currentChallenge?.description ?? "Explore!"

        // Clear state
        activeEnemies.removeAll()
        interactiveElements.removeAll()
        blockedHexes.removeAll()
        challengeHadEnemies = false
        challengeCompleted = false
        playerDetected = false
        challengeTimer = 0
        challengeTimeLimit = 0

        if let challenge = currentChallenge {
            // Timer-based challenges
            let isLightOnlyPuzzle = challenge.type == .puzzle
                && challenge.requiredCapabilities == [.illumination]
            if challenge.type == .timed || challenge.type == .stealth || isLightOnlyPuzzle {
                challengeTimeLimit = 20.0 // Easy mode
            }

            // Clamp element positions to within distance 1 (visible 7-hex grid)
            var usedPositions: Set<HexCoord> = [.zero]
            for element in challenge.elements {
                var relativePos = element.position
                if relativePos.distance(to: .zero) > 1 {
                    // Relocate to nearest available neighbor hex
                    let neighbors = HexCoord.zero.neighbors().filter { !usedPositions.contains($0) }
                    if let nearest = neighbors.first {
                        relativePos = nearest
                    }
                }
                usedPositions.insert(relativePos)
                let worldPosition = relativePos + player.position

                if case .obstacle(let blocking, _) = element.type, blocking {
                    blockedHexes.insert(worldPosition)
                }

                if let enemy = EnemyFactory.createEnemy(from: element, at: worldPosition) {
                    activeEnemies.append(enemy)
                    challengeHadEnemies = true
                } else {
                    if let interactive = createInteractiveElement(from: element, at: worldPosition) {
                        interactiveElements[interactive.id] = interactive
                    }
                }
            }
        }

        refreshHexContents()
    }

    private func createInteractiveElement(from element: ChallengeElement, at position: HexCoord) -> WatchInteractiveElement? {
        switch element.type {
        case .target:
            return WatchInteractiveElement(position: position, type: .target)

        case .npc(let needsHealing, _):
            if needsHealing {
                let currentHP = element.properties["hp"] as? Int ?? 1
                let maxHP = element.properties["maxHp"] as? Int ?? 3
                return WatchInteractiveElement(position: position, type: .npc(currentHP: currentHP, maxHP: maxHP))
            }
            return WatchInteractiveElement(position: position, type: .target)

        case .trigger(let activates):
            return WatchInteractiveElement(position: position, type: .trigger(activatesId: activates))

        case .darkness(let radius):
            return WatchInteractiveElement(position: position, type: .darkness(radius: radius, dispelled: false))

        case .obstacle(_, let destructible):
            if destructible {
                let hp = element.properties["hp"] as? Int ?? 3
                let id = element.properties["id"] as? String ?? UUID().uuidString
                return WatchInteractiveElement(position: position, type: .obstacle(id: id, hp: hp))
            }
            return nil

        default:
            return nil
        }
    }

    // MARK: - Challenge Completion

    private func checkChallengeCompletion() {
        guard let challenge = currentChallenge, !challengeCompleted else { return }

        var isComplete = false

        switch challenge.type {
        case .combat, .survival:
            let aliveEnemies = activeEnemies.filter { $0.isAlive }
            isComplete = challengeHadEnemies && aliveEnemies.isEmpty

        case .obstacle, .timed:
            if challengeTimeLimit > 0 && challengeTimer >= challengeTimeLimit {
                handleTimerExpired()
                return
            }
            isComplete = checkAllTargetsReached()

        case .stealth:
            if challengeTimeLimit > 0 && challengeTimer >= challengeTimeLimit {
                handleTimerExpired()
                return
            }
            if playerDetected {
                player.takeDamage(1)
                playerHP = player.hp
                emitEvent(.playerHit(1))
                if !player.isAlive { showGameOver(); return }
                advanceChallenge()
                return
            }
            isComplete = checkAllTargetsReached()

        case .rescue:
            isComplete = checkAllNPCsRescued()

        case .puzzle:
            if challengeTimeLimit > 0 && challengeTimer >= challengeTimeLimit {
                handleTimerExpired()
                return
            }
            isComplete = checkPuzzleSolved()
        }

        if isComplete {
            challengeCompleted = true
            GameManager.shared.completeChallenge()
            challengeCount = GameManager.shared.challengesCompleted
            challengeDescription = "Victory!"
            emitEvent(.challengeComplete)

            // Auto-generate next challenge after brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.generateNewChallenge()
            }
        }
    }

    private func handleTimerExpired() {
        player.takeDamage(1)
        playerHP = player.hp
        emitEvent(.playerHit(1))
        if !player.isAlive { showGameOver(); return }
        advanceChallenge()
    }

    private func advanceChallenge() {
        challengeCompleted = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.generateNewChallenge()
        }
    }

    private func checkAllTargetsReached() -> Bool {
        var targetCount = 0
        for (_, element) in interactiveElements {
            if case .target = element.type {
                targetCount += 1
                if player.position.distance(to: element.position) > 1 {
                    return false
                }
            }
        }
        return targetCount > 0
    }

    private func checkAllNPCsRescued() -> Bool {
        for (_, element) in interactiveElements {
            if case .npc(let currentHP, let maxHP) = element.type {
                if currentHP < maxHP { return false }
            }
            if case .target = element.type, !element.isCompleted {
                return false
            }
        }
        return activeEnemies.filter { $0.isAlive }.isEmpty
    }

    private func checkPuzzleSolved() -> Bool {
        for (_, element) in interactiveElements {
            switch element.type {
            case .darkness(_, let dispelled):
                if !dispelled { return false }
            case .trigger:
                if !element.isCompleted { return false }
            case .target:
                if player.position.distance(to: element.position) > 1 { return false }
            default:
                break
            }
        }
        return true
    }

    // MARK: - Helper Methods

    private func enemyAt(_ position: HexCoord) -> Enemy? {
        activeEnemies.first { $0.isAlive && $0.position == position }
    }

    private func removeDeadEnemies() {
        for enemy in activeEnemies where !enemy.isAlive {
            emitEvent(.enemyKilled(at: enemy.position - player.position))
        }
        activeEnemies.removeAll { !$0.isAlive }
    }

    private func healNPCAt(_ position: HexCoord, amount: Int) -> Int? {
        for (id, var element) in interactiveElements {
            if element.position == position, case .npc(let currentHP, let maxHP) = element.type {
                let newHP = min(maxHP, currentHP + amount)
                let healed = newHP - currentHP
                element.type = .npc(currentHP: newHP, maxHP: maxHP)
                interactiveElements[id] = element
                return healed > 0 ? healed : nil
            }
        }
        return nil
    }

    @discardableResult
    private func damageObstacleAt(_ position: HexCoord, damage: Int) -> Bool {
        for (id, var element) in interactiveElements {
            if element.position == position, case .obstacle(let obstId, let hp) = element.type {
                let newHP = hp - damage
                if newHP <= 0 {
                    interactiveElements.removeValue(forKey: id)
                    blockedHexes.remove(position)
                } else {
                    element.type = .obstacle(id: obstId, hp: newHP)
                    interactiveElements[id] = element
                }
                return true
            }
        }
        return false
    }

    private func dispelDarknessAt(_ position: HexCoord) {
        for (id, var element) in interactiveElements {
            if case .darkness(let radius, _) = element.type {
                let dist = position.distance(to: element.position)
                if dist <= radius {
                    element.type = .darkness(radius: radius, dispelled: true)
                    interactiveElements[id] = element
                    emitEvent(.statusText("Light!", at: element.position - player.position))
                }
            }
        }
    }

    private func checkAndMergeEnemies() {
        var enemiesByPosition: [HexCoord: [Enemy]] = [:]
        for enemy in activeEnemies where enemy.isAlive {
            enemiesByPosition[enemy.position, default: []].append(enemy)
        }

        for (position, enemies) in enemiesByPosition where enemies.count >= 2 {
            if let merged = Enemy.merge(enemies, at: position) {
                for enemy in enemies {
                    activeEnemies.removeAll { $0.id == enemy.id }
                }
                activeEnemies.append(merged)
            }
        }
    }

    private func checkPlayerDeath() {
        if !player.isAlive {
            showGameOver()
        }
    }

    private func showGameOver() {
        isGameOver = true
    }

    private func emitEvent(_ event: GameEvent) {
        latestEvent = event
        eventCounter += 1
        // Haptic feedback
        switch event {
        case .playerHit:
            WKInterfaceDevice.current().play(.failure)
        case .enemyKilled:
            WKInterfaceDevice.current().play(.success)
        case .challengeComplete:
            WKInterfaceDevice.current().play(.success)
        case .spellCast:
            WKInterfaceDevice.current().play(.click)
        default:
            break
        }
    }

    // MARK: - Grid State

    func refreshHexContents() {
        var contents: [HexCoord: HexContent] = [:]

        for hex in visibleHexes {
            let worldPos = hex + player.position
            contents[hex] = .empty

            // Check for interactive elements
            for (_, element) in interactiveElements {
                if element.position == worldPos {
                    switch element.type {
                    case .target:
                        contents[hex] = .target
                    case .npc(let hp, let maxHP):
                        contents[hex] = .npc(currentHP: hp, maxHP: maxHP)
                    case .obstacle(_, let hp):
                        contents[hex] = .obstacle(hp: hp)
                    case .darkness(_, let dispelled):
                        contents[hex] = .darkness(dispelled: dispelled)
                    case .trigger:
                        contents[hex] = .target
                    }
                }
            }

            // Non-destructible obstacles
            if blockedHexes.contains(worldPos) && contents[hex] == nil || contents[hex]?.isEmpty == true {
                contents[hex] = .obstacle(hp: 0)
            }

            // Enemies override
            if let enemy = enemyAt(worldPos) {
                // Check if enemy is in undispelled darkness
                let inDarkness = interactiveElements.values.contains { element in
                    if case .darkness(let radius, let dispelled) = element.type, !dispelled {
                        return element.position.distance(to: worldPos) <= radius
                    }
                    return false
                }
                if inDarkness {
                    contents[hex] = .darkness(dispelled: false)
                } else {
                    contents[hex] = .enemy(enemy)
                }
            }
        }

        // Player always at center
        contents[.zero] = .player

        hexContents = contents
    }

    /// Increment the challenge timer (called by timed challenges)
    func tickTimer(_ dt: TimeInterval) {
        guard challengeTimeLimit > 0, !challengeCompleted else { return }
        challengeTimer += dt
        if challengeTimer >= challengeTimeLimit {
            checkChallengeCompletion()
        }
    }
}

// MARK: - HexContent helpers

private extension HexContent {
    var isEmpty: Bool {
        if case .empty = self { return true }
        return false
    }
}
