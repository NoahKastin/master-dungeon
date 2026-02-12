//
//  ChallengeAI.swift
//  Master Dungeon
//
//  AI algorithms for challenge generation and validation:
//  - Constraint Satisfaction Problem (CSP) for valid challenge construction
//  - Monte Carlo Simulation for solvability verification
//  - Fitness Function for challenge quality scoring
//
//  These are real AI/ML techniques used in game AI, procedural generation,
//  and optimization problems.
//

import Foundation
import GameplayKit

// MARK: - Challenge AI System

/// AI system that generates and validates challenges using multiple algorithms
class ChallengeAI {
    private let randomSource: GKRandomSource

    // Configuration
    static var hexRange: Int { GameManager.shared.gameMode == .medium ? 2 : 3 }
    static let bossInterval = 5
    static let bossBaseHP = 6
    // Boss damage uses enemyDamage(strong: true) for mode-aware scaling
    private let maxSimulationSteps = 50
    private let simulationRuns = 10
    private let maxGenerationAttempts = 20

    /// Enemy damage for the current mode. Medium uses d1-d3 weighted low; others use 1.
    private func enemyDamage(strong: Bool = false) -> Int {
        guard GameManager.shared.gameMode == .medium else { return 1 }
        if strong {
            return randomSource.nextInt(upperBound: 3) < 2 ? 2 : 3
        }
        return randomSource.nextInt(upperBound: 3) < 2 ? 1 : 2
    }

    init(seed: UInt64? = nil) {
        if let seed = seed {
            randomSource = GKMersenneTwisterRandomSource(seed: seed)
        } else {
            randomSource = GKMersenneTwisterRandomSource()
        }
    }

    // MARK: - Main Entry Point

    /// Generate a challenge that is guaranteed to be solvable
    /// Uses CSP for construction, Monte Carlo for verification
    func generateSolvableChallenge(for loadout: SpellLoadout, type: ChallengeType, difficulty: Int = 1) -> Challenge? {
        print("AI CHALLENGE DEBUG: Generating type=\(type)")
        // Step 1: Build constraint model from loadout
        let constraints = buildConstraints(from: loadout)

        // Step 2: Generate candidate challenges using CSP
        for attempt in 0..<maxGenerationAttempts {
            // Use CSP to generate a valid challenge structure
            if let candidate = generateWithCSP(type: type, constraints: constraints, difficulty: difficulty, attempt: attempt) {

                // Step 3: Verify solvability with Monte Carlo simulation
                let (solvable, confidence) = verifySolvability(challenge: candidate, loadout: loadout)

                // Boss challenges accept a lower solvability bar — they're meant to be hard
                let isBoss = Self.isBossChallenge
                if isBoss && confidence >= 0.3 {
                    return candidate
                }

                if solvable && confidence >= 0.7 {
                    // Step 4: Score the challenge quality
                    let fitness = calculateFitness(challenge: candidate, loadout: loadout, confidence: confidence)

                    // Accept challenges with reasonable fitness
                    if fitness >= 0.5 {
                        return candidate
                    }
                }
            }
        }

        // Fallback: Generate a simple, guaranteed-solvable challenge
        print("AI CHALLENGE DEBUG: Using fallback for type=\(type)")
        let fallbackChallenge = generateFallbackChallenge(type: type, loadout: loadout)
        print("AI CHALLENGE DEBUG: Fallback created \(fallbackChallenge.elements.count) elements for \(type)")
        for element in fallbackChallenge.elements {
            print("AI CHALLENGE DEBUG:   - \(element.type) at \(element.position)")
        }
        return fallbackChallenge
    }

    // MARK: - Constraint Satisfaction Problem (CSP)

    /// Constraints derived from the player's spell loadout
    struct ConstraintModel {
        // What the player CAN do
        let canDealDamage: Bool
        let maxDamagePerTurn: Int
        let canHeal: Bool
        let maxHealPerTurn: Int
        let canAttackAtRange: Bool
        let maxAttackRange: Int
        let canAoE: Bool
        let aoERadius: Int
        let canCrowdControl: Bool
        let canIlluminate: Bool
        let canDetectHidden: Bool

        // Resource constraints
        let totalMana: Int
        let spellCount: Int
        let averageManaCost: Int

        // Derived constraints for challenge generation
        var maxEnemyHP: Int {
            // Player should be able to kill enemies within reasonable turns
            return max(1, maxDamagePerTurn * 5)
        }

        var maxEnemyCount: Int {
            if canAoE {
                return 6  // AoE can handle more enemies
            } else {
                return max(1, totalMana / max(1, averageManaCost))
            }
        }

        var maxChallengeDistance: Int {
            if canAttackAtRange {
                return maxAttackRange
            } else {
                return ChallengeAI.hexRange
            }
        }
    }

    /// Build constraint model from player's loadout (CSP domain definition)
    private func buildConstraints(from loadout: SpellLoadout) -> ConstraintModel {
        let spells = loadout.spells

        // Calculate damage potential
        let damageSpells = spells.filter { $0.isOffensive }
        let maxDamage = damageSpells.map { $0.rollOffense() }.max() ?? 0

        // Calculate healing potential
        let healingSpells = spells.filter { $0.isDefensive && !$0.isOffensive }
        let maxHeal = healingSpells.map { $0.rollDefense() }.max() ?? 0

        // Calculate attack range
        let maxRange = damageSpells.map { $0.range }.max() ?? 1

        // Check for AoE
        let aoESpells = spells.filter { $0.isAoE }
        let aoERadius = aoESpells.isEmpty ? 0 : max(1, (aoESpells.first?.range ?? 2) / 2)

        // Calculate mana efficiency
        let totalManaCost = spells.reduce(0) { $0 + $1.manaCost }
        let avgCost = spells.isEmpty ? 5 : totalManaCost / spells.count

        return ConstraintModel(
            canDealDamage: !damageSpells.isEmpty,
            maxDamagePerTurn: maxDamage,
            canHeal: !healingSpells.isEmpty,
            maxHealPerTurn: maxHeal,
            canAttackAtRange: maxRange >= 2,
            maxAttackRange: maxRange,
            canAoE: !aoESpells.isEmpty,
            aoERadius: aoERadius,
            canCrowdControl: loadout.hasCapability(.crowdControl),
            canIlluminate: loadout.hasCapability(.illumination),
            canDetectHidden: loadout.hasCapability(.information),
            totalMana: Player.maxMana,
            spellCount: spells.count,
            averageManaCost: avgCost
        )
    }

    /// Whether the current challenge should be a boss encounter
    static var isBossChallenge: Bool {
        let completed = GameManager.shared.challengesCompleted
        return completed > 0 && completed % bossInterval == 0
    }

    /// Generate challenge using Constraint Satisfaction
    /// CSP ensures all elements satisfy the constraint model
    private func generateWithCSP(type: ChallengeType, constraints: ConstraintModel, difficulty: Int, attempt: Int) -> Challenge? {
        var elements: [ChallengeElement] = []
        var usedPositions: Set<HexCoord> = [.zero]

        // CSP: Select elements that satisfy constraints
        switch type {
        case .combat:
            if Self.isBossChallenge {
                elements = generateBossCombatCSP(constraints: constraints, difficulty: difficulty, usedPositions: &usedPositions)
            } else {
                elements = generateCombatCSP(constraints: constraints, difficulty: difficulty, usedPositions: &usedPositions)
            }

        case .obstacle:
            // Constraint: Player must be able to destroy obstacles
            guard constraints.canDealDamage else { return nil }
            elements = generateObstacleCSP(constraints: constraints, usedPositions: &usedPositions)

        case .puzzle:
            // Constraint: Player must have illumination for puzzle challenges
            guard constraints.canIlluminate else { return nil }
            elements = generatePuzzleCSP(constraints: constraints, usedPositions: &usedPositions)

        case .survival:
            // Constraint: Player must be able to deal damage AND heal
            guard constraints.canDealDamage && constraints.canHeal else { return nil }
            elements = generateSurvivalCSP(constraints: constraints, difficulty: difficulty, usedPositions: &usedPositions)

        case .stealth:
            // Constraint: Player must have crowd control to sneak past
            guard constraints.canCrowdControl else { return nil }
            elements = generateStealthCSP(constraints: constraints, usedPositions: &usedPositions)

        case .rescue:
            // Constraint: Player must be able to help NPCs (heal or reach them)
            guard constraints.canHeal || constraints.canDealDamage else { return nil }
            elements = generateRescueCSP(constraints: constraints, usedPositions: &usedPositions)

        case .timed:
            // Constraint: Player must be able to reach targets
            guard constraints.canAttackAtRange else { return nil }
            elements = generateTimedCSP(constraints: constraints, usedPositions: &usedPositions)
        }

        guard !elements.isEmpty else { return nil }

        // Build required capabilities set
        var required: Set<SpellCapability> = []
        for element in elements {
            required.formUnion(capabilitiesNeeded(for: element))
        }

        let description = generateDescription(type: type, elements: elements, attempt: attempt)

        return Challenge(
            type: type,
            description: description,
            requiredCapabilities: required,
            elements: elements,
            threatLevel: 1
        )
    }

    // MARK: - CSP Element Generators

    private func generateCombatCSP(constraints: ConstraintModel, difficulty: Int, usedPositions: inout Set<HexCoord>) -> [ChallengeElement] {
        var elements: [ChallengeElement] = []

        // CSP Constraint: Enemy HP must be killable with available damage
        let maxHP = min(constraints.maxEnemyHP, 2 + difficulty * 2)

        // CSP Constraint: Enemy count based on player's capabilities
        let enemyCount: Int
        if constraints.canAoE {
            enemyCount = min(constraints.maxEnemyCount, 3 + difficulty)
        } else {
            enemyCount = min(constraints.maxEnemyCount, 1 + difficulty / 2)
        }

        // CSP Constraint: Enemy distance based on player's range
        let maxDistance = constraints.canAttackAtRange ? constraints.maxAttackRange : ChallengeAI.hexRange

        // Special case: Ranged attack players get ranged OR healer enemies (50/50)
        if constraints.canAttackAtRange {
            if randomSource.nextBool() {
                let rangedPos = randomValidPosition(minDist: constraints.maxAttackRange, maxDist: constraints.maxAttackRange, avoiding: usedPositions)
                usedPositions.insert(rangedPos)
                elements.append(ChallengeElement(
                    type: .enemy(hp: 1, damage: enemyDamage(), behavior: .ranged),
                    position: rangedPos,
                    properties: [:]
                ))
            } else {
                // Front-line enemy + healer support
                let frontPos = randomValidPosition(minDist: 2, maxDist: 2, avoiding: usedPositions)
                usedPositions.insert(frontPos)
                elements.append(ChallengeElement(
                    type: .enemy(hp: 3 + difficulty, damage: enemyDamage(strong: true), behavior: .aggressive),
                    position: frontPos,
                    properties: [:]
                ))

                let healerPos = randomValidPosition(minDist: constraints.maxAttackRange, maxDist: constraints.maxAttackRange, avoiding: usedPositions)
                usedPositions.insert(healerPos)
                elements.append(ChallengeElement(
                    type: .enemy(hp: 2, damage: enemyDamage(), behavior: .healer),
                    position: healerPos,
                    properties: [:]
                ))
            }
            return elements
        }

        for _ in 0..<enemyCount {
            let pos = randomValidPosition(minDist: 2, maxDist: maxDistance, avoiding: usedPositions)
            usedPositions.insert(pos)

            let hp = constraints.canAoE ? 1 : maxHP  // Swarm enemies have 1 HP
            let behavior: EnemyBehavior = constraints.canAttackAtRange ? .defensive : .aggressive

            elements.append(ChallengeElement(
                type: .enemy(hp: hp, damage: enemyDamage(strong: !constraints.canAoE), behavior: behavior),
                position: pos,
                properties: [:]
            ))
        }

        // Add invisible enemy only if player can detect
        if constraints.canDetectHidden && randomSource.nextBool() {
            let pos = randomValidPosition(minDist: 2, maxDist: maxDistance, avoiding: usedPositions)
            usedPositions.insert(pos)
            elements.append(ChallengeElement(
                type: .invisibleEnemy(hp: 2, damage: enemyDamage()),
                position: pos,
                properties: [:]
            ))
        }

        // Add darkness only if player can illuminate, with a hidden enemy inside
        if constraints.canIlluminate && randomSource.nextBool() {
            let darknessPos = randomValidPosition(minDist: 1, maxDist: ChallengeAI.hexRange - 1, avoiding: usedPositions)
            elements.append(ChallengeElement(
                type: .darkness(radius: 2),
                position: darknessPos,
                properties: [:]
            ))

            // Move an existing enemy into the darkness zone instead of adding a new one
            let darknessHexes = darknessPos.hexesInRange(2).filter { !usedPositions.contains($0) && $0 != .zero && $0.distance(to: .zero) <= ChallengeAI.hexRange }
            if !darknessHexes.isEmpty,
               let enemyIdx = elements.indices.first(where: { if case .enemy = elements[$0].type { return true }; return false }) {
                let newPos = darknessHexes[randomSource.nextInt(upperBound: darknessHexes.count)]
                usedPositions.remove(elements[enemyIdx].position)
                usedPositions.insert(newPos)
                let old = elements[enemyIdx]
                elements[enemyIdx] = ChallengeElement(type: old.type, position: newPos, properties: old.properties)
            }
        }

        return elements
    }

    private func generateBossCombatCSP(constraints: ConstraintModel, difficulty: Int, usedPositions: inout Set<HexCoord>) -> [ChallengeElement] {
        var elements: [ChallengeElement] = []

        let bossHP = Self.bossBaseHP + difficulty
        let bossDamage = enemyDamage(strong: true)
        let bossPos = randomValidPosition(minDist: 2, maxDist: min(3, ChallengeAI.hexRange), avoiding: usedPositions)
        usedPositions.insert(bossPos)

        elements.append(ChallengeElement(
            type: .enemy(hp: bossHP, damage: bossDamage, behavior: .boss),
            position: bossPos,
            properties: [:]
        ))

        return elements
    }

    private func generateObstacleCSP(constraints: ConstraintModel, usedPositions: inout Set<HexCoord>) -> [ChallengeElement] {
        var elements: [ChallengeElement] = []

        // Place target at r=2 (within 3-hex visible radius)
        let targetPos = HexCoord(q: 0, r: 2)
        usedPositions.insert(targetPos)
        elements.append(ChallengeElement(
            type: .target(required: true),
            position: targetPos,
            properties: [:]
        ))

        // Create obstacle line at r=1 (between player at 0,0 and target)
        // At r=1, we can cover q=-2 to q=2, all within 3-hex visible range
        // This prevents bypassing the wall
        let obstacleR = 1

        for q in -2...2 {
            let pos = HexCoord(q: q, r: obstacleR)
            usedPositions.insert(pos)

            // Choose obstacle type based on player capabilities
            if constraints.canDealDamage {
                // Destructible obstacle - player can blast through
                elements.append(ChallengeElement(
                    type: .obstacle(blocking: true, destructible: true),
                    position: pos,
                    properties: ["hp": min(constraints.maxDamagePerTurn * 2, 4)]
                ))
            } else {
                // Destructible as fallback (if damage available) or skip
                if constraints.canDealDamage {
                    elements.append(ChallengeElement(
                        type: .obstacle(blocking: true, destructible: true),
                        position: pos,
                        properties: ["hp": 2]
                    ))
                }
            }
        }

        return elements
    }

    private func generatePuzzleCSP(constraints: ConstraintModel, usedPositions: inout Set<HexCoord>) -> [ChallengeElement] {
        var elements: [ChallengeElement] = []

        // CSP: Only add elements player can interact with
        if constraints.canIlluminate {
            let pos = randomValidPosition(minDist: 1, maxDist: 2, avoiding: usedPositions)
            elements.append(ChallengeElement(
                type: .darkness(radius: 3),
                position: pos,
                properties: [:]
            ))
        }

        // Target (within 3-hex visible range)
        let targetPos = randomValidPosition(minDist: 2, maxDist: ChallengeAI.hexRange, avoiding: usedPositions)
        usedPositions.insert(targetPos)
        elements.append(ChallengeElement(
            type: .target(required: true),
            position: targetPos,
            properties: [:]
        ))

        return elements
    }

    private func generateSurvivalCSP(constraints: ConstraintModel, difficulty: Int, usedPositions: inout Set<HexCoord>) -> [ChallengeElement] {
        var elements: [ChallengeElement] = []

        // CSP: Hazard damage must be healable
        if constraints.canHeal {
            elements.append(ChallengeElement(
                type: .hazard(damagePerTurn: min(1, constraints.maxHealPerTurn), radius: 2),
                position: HexCoord(q: 1, r: 1),
                properties: [:]
            ))
        }

        // CSP: Total enemy HP must be manageable
        let totalAllowedHP = constraints.maxDamagePerTurn * 8  // ~8 turns of combat
        let enemyCount = min(3, difficulty + 1)
        let hpPerEnemy = max(1, totalAllowedHP / enemyCount)

        for _ in 0..<enemyCount {
            let pos = randomValidPosition(minDist: 2, maxDist: ChallengeAI.hexRange, avoiding: usedPositions)
            usedPositions.insert(pos)
            elements.append(ChallengeElement(
                type: .enemy(hp: hpPerEnemy, damage: enemyDamage(strong: true), behavior: .aggressive),
                position: pos,
                properties: [:]
            ))
        }

        return elements
    }

    private func generateStealthCSP(constraints: ConstraintModel, usedPositions: inout Set<HexCoord>) -> [ChallengeElement] {
        var elements: [ChallengeElement] = []

        // CSP: Enemies must be avoidable or CC-able
        // Place enemies with gaps between them (within 3-hex visible range)
        let positions = [
            HexCoord(q: 0, r: 2),
            HexCoord(q: 1, r: 1),
            HexCoord(q: -1, r: 2)
        ]

        for pos in positions {
            usedPositions.insert(pos)
            elements.append(ChallengeElement(
                type: .enemy(hp: 10, damage: 2, behavior: .defensive),  // Too strong to fight
                position: pos,
                properties: ["patrol": true]
            ))
        }

        // Target must be reachable through gaps or with mobility (within 3-hex range)
        let targetPos = HexCoord(q: 0, r: 3)
        usedPositions.insert(targetPos)
        elements.append(ChallengeElement(
            type: .target(required: true),
            position: targetPos,
            properties: [:]
        ))

        return elements
    }

    private func generateRescueCSP(constraints: ConstraintModel, usedPositions: inout Set<HexCoord>) -> [ChallengeElement] {
        var elements: [ChallengeElement] = []

        let npcPos = randomValidPosition(minDist: 2, maxDist: ChallengeAI.hexRange, avoiding: usedPositions)
        usedPositions.insert(npcPos)

        // CSP: NPC type based on player abilities
        if constraints.canHeal {
            // Injured NPC - healable amount within player's capability
            let healNeeded = min(2, constraints.maxHealPerTurn * 2)
            elements.append(ChallengeElement(
                type: .npc(needsHealing: true, needsRescue: false),
                position: npcPos,
                properties: ["hp": 1, "maxHp": 1 + healNeeded]
            ))
        } else {
            // Rescue target - just need to reach
            elements.append(ChallengeElement(
                type: .npc(needsHealing: false, needsRescue: true),
                position: npcPos,
                properties: [:]
            ))
        }

        // Enemy - must be defeatable
        if constraints.canDealDamage {
            let enemyPos = randomValidPosition(minDist: 2, maxDist: ChallengeAI.hexRange, avoiding: usedPositions)
            usedPositions.insert(enemyPos)
            elements.append(ChallengeElement(
                type: .enemy(hp: min(constraints.maxEnemyHP, 3), damage: enemyDamage(), behavior: .aggressive),
                position: enemyPos,
                properties: [:]
            ))
        }

        return elements
    }

    private func generateTimedCSP(constraints: ConstraintModel, usedPositions: inout Set<HexCoord>) -> [ChallengeElement] {
        var elements: [ChallengeElement] = []

        // CSP: Targets must be reachable within time limit
        let targetCount = min(4, 5)  // ~5 turns worth at 1 hex per turn

        // Arrange targets in reachable pattern
        for i in 0..<targetCount {
            let angle = Double(i) * (2.0 * .pi / Double(targetCount))
            let distance = min(ChallengeAI.hexRange, constraints.maxChallengeDistance)
            let q = Int(round(cos(angle) * Double(distance)))
            let r = Int(round(sin(angle) * Double(distance)))
            let pos = HexCoord(q: q, r: r)

            if !usedPositions.contains(pos) {
                usedPositions.insert(pos)
                elements.append(ChallengeElement(
                    type: .target(required: true),
                    position: pos,
                    properties: ["timed": true]
                ))
            }
        }

        return elements
    }

    // MARK: - Monte Carlo Simulation

    /// Verify challenge solvability by simulating gameplay
    /// Returns (isSolvable, confidence) where confidence is 0.0-1.0
    func verifySolvability(challenge: Challenge, loadout: SpellLoadout) -> (Bool, Double) {
        var successCount = 0

        for _ in 0..<simulationRuns {
            let result = simulateChallenge(challenge: challenge, loadout: loadout)
            if result.succeeded {
                successCount += 1
            }
        }

        let confidence = Double(successCount) / Double(simulationRuns)
        return (confidence >= 0.5, confidence)
    }

    /// Simulate a challenge playthrough with simple AI
    private func simulateChallenge(challenge: Challenge, loadout: SpellLoadout) -> SimulationResult {
        var state = SimulationState(challenge: challenge, loadout: loadout)

        for step in 0..<maxSimulationSteps {
            // Check win/lose conditions
            if state.isVictory {
                return SimulationResult(succeeded: true, steps: step, remainingHP: state.playerHP)
            }
            if state.isDefeat {
                return SimulationResult(succeeded: false, steps: step, remainingHP: 0)
            }

            // Player turn: Choose best action using simple heuristics
            let action = chooseBestAction(state: state, loadout: loadout)
            state = applyAction(action, to: state, loadout: loadout)

            // Enemy turn
            state = simulateEnemyTurn(state: state)
        }

        // Timeout - consider it a failure
        return SimulationResult(succeeded: false, steps: maxSimulationSteps, remainingHP: state.playerHP)
    }

    /// Simulation state for Monte Carlo
    private struct SimulationState {
        var playerPosition: HexCoord = .zero
        var playerHP: Int = 5
        var playerMana: Int = Player.maxMana
        var enemies: [(position: HexCoord, hp: Int, damage: Int, behavior: EnemyBehavior)]
        var targets: Set<HexCoord>
        var npcsToHeal: [(position: HexCoord, currentHP: Int, maxHP: Int)]
        var darknessDispelled: Bool
        var triggersActivated: Bool
        var challengeType: ChallengeType
        var turnsElapsed: Int = 0

        init(challenge: Challenge, loadout: SpellLoadout) {
            self.challengeType = challenge.type
            self.enemies = []
            self.targets = []
            self.npcsToHeal = []
            self.darknessDispelled = true
            self.triggersActivated = true

            for element in challenge.elements {
                switch element.type {
                case .enemy(let hp, let damage, let behavior):
                    enemies.append((element.position, hp, damage, behavior))
                case .invisibleEnemy(let hp, let damage):
                    enemies.append((element.position, hp, damage, .aggressive))
                case .target:
                    targets.insert(element.position)
                case .npc(let needsHealing, _):
                    if needsHealing {
                        let maxHP = element.properties["maxHp"] as? Int ?? 3
                        let currentHP = element.properties["hp"] as? Int ?? 1
                        npcsToHeal.append((element.position, currentHP, maxHP))
                    } else {
                        targets.insert(element.position)  // Rescue target
                    }
                case .darkness:
                    darknessDispelled = false
                case .trigger:
                    triggersActivated = false
                default:
                    break
                }
            }
        }

        var isVictory: Bool {
            switch challengeType {
            case .combat, .survival:
                return enemies.allSatisfy { $0.hp <= 0 }
            case .obstacle, .timed:
                return targets.isEmpty
            case .puzzle:
                return darknessDispelled && triggersActivated && targets.isEmpty
            case .stealth:
                return targets.isEmpty  // Reached goal
            case .rescue:
                return enemies.allSatisfy { $0.hp <= 0 } && npcsToHeal.allSatisfy { $0.currentHP >= $0.maxHP }
            }
        }

        var isDefeat: Bool {
            return playerHP <= 0
        }
    }

    private struct SimulationResult {
        let succeeded: Bool
        let steps: Int
        let remainingHP: Int
    }

    /// Simple AI to choose best action during simulation
    private func chooseBestAction(state: SimulationState, loadout: SpellLoadout) -> SimulationAction {
        // Priority: Attack enemies > Heal NPCs > Reach targets > Move closer

        // Find nearest enemy
        let aliveEnemies = state.enemies.filter { $0.hp > 0 }
        let nearestEnemy = aliveEnemies.min { state.playerPosition.distance(to: $0.position) < state.playerPosition.distance(to: $1.position) }

        // Find best attack spell
        let attackSpells = loadout.spells.filter { $0.isOffensive && $0.manaCost <= state.playerMana }
        let bestAttack = attackSpells.max { $0.rollOffense() < $1.rollOffense() }

        if let enemy = nearestEnemy, let spell = bestAttack {
            let distance = state.playerPosition.distance(to: enemy.position)
            if distance <= spell.range {
                return .attack(target: enemy.position, spellIndex: loadout.spells.firstIndex(of: spell) ?? 0)
            }
        }

        // Heal NPC if possible
        let healSpells = loadout.spells.filter { $0.isDefensive && !$0.isOffensive && $0.manaCost <= state.playerMana }
        if let healSpell = healSpells.first {
            for npc in state.npcsToHeal where npc.currentHP < npc.maxHP {
                let distance = state.playerPosition.distance(to: npc.position)
                if distance <= healSpell.range {
                    return .heal(target: npc.position, spellIndex: loadout.spells.firstIndex(of: healSpell) ?? 0)
                }
            }
        }

        // Move toward nearest target or enemy
        var moveTarget: HexCoord? = nil

        if let target = state.targets.min(by: { state.playerPosition.distance(to: $0) < state.playerPosition.distance(to: $1) }) {
            moveTarget = target
        } else if let enemy = nearestEnemy {
            moveTarget = enemy.position
        }

        if let target = moveTarget {
            // Move one step closer
            let neighbors = state.playerPosition.neighbors()
            let closest = neighbors.min { $0.distance(to: target) < $1.distance(to: target) }
            if let dest = closest {
                return .move(to: dest)
            }
        }

        return .wait
    }

    private enum SimulationAction {
        case move(to: HexCoord)
        case attack(target: HexCoord, spellIndex: Int)
        case heal(target: HexCoord, spellIndex: Int)
        case wait
    }

    private func applyAction(_ action: SimulationAction, to state: SimulationState, loadout: SpellLoadout) -> SimulationState {
        var newState = state
        newState.turnsElapsed += 1

        // Mana regeneration
        newState.playerMana = min(Player.maxMana, newState.playerMana + 1)

        switch action {
        case .move(let dest):
            newState.playerPosition = dest
            // Check if reached a target
            if newState.targets.contains(dest) || newState.playerPosition.distance(to: dest) <= 1 {
                newState.targets.remove(dest)
            }

        case .attack(let target, let spellIndex):
            guard spellIndex < loadout.spells.count else { break }
            let spell = loadout.spells[spellIndex]
            newState.playerMana -= spell.manaCost

            let damage = spell.rollOffense()
            for i in 0..<newState.enemies.count {
                if newState.enemies[i].position == target {
                    newState.enemies[i].hp -= damage
                }
            }

        case .heal(let target, let spellIndex):
            guard spellIndex < loadout.spells.count else { break }
            let spell = loadout.spells[spellIndex]
            newState.playerMana -= spell.manaCost

            let healing = spell.rollDefense()
            for i in 0..<newState.npcsToHeal.count {
                if newState.npcsToHeal[i].position == target {
                    newState.npcsToHeal[i].currentHP = min(
                        newState.npcsToHeal[i].maxHP,
                        newState.npcsToHeal[i].currentHP + healing
                    )
                }
            }

        case .wait:
            break
        }

        return newState
    }

    private func simulateEnemyTurn(state: SimulationState) -> SimulationState {
        var newState = state

        for enemy in state.enemies where enemy.hp > 0 {
            let distance = state.playerPosition.distance(to: enemy.position)
            if enemy.behavior == .boss {
                // Boss: melee bonus at distance 1, area slam at distance ≤ 3
                if distance == 1 {
                    newState.playerHP -= enemy.damage + 1
                } else if distance <= 3 {
                    newState.playerHP -= enemy.damage
                }
            } else {
                // Regular enemies: attack if adjacent
                if distance <= 1 {
                    newState.playerHP -= enemy.damage
                }
            }
        }

        return newState
    }

    // MARK: - Fitness Function

    /// Calculate challenge quality score (0.0 - 1.0)
    /// Good challenges are:
    /// - Solvable but not trivial
    /// - Use multiple player abilities
    /// - Have interesting element combinations
    func calculateFitness(challenge: Challenge, loadout: SpellLoadout, confidence: Double) -> Double {
        var fitness = 0.0

        // Factor 1: Solvability confidence (30%)
        // Sweet spot is 70-90% - not too easy, not too hard
        let solvabilityScore: Double
        if confidence >= 0.7 && confidence <= 0.9 {
            solvabilityScore = 1.0
        } else if confidence > 0.9 {
            solvabilityScore = 0.8  // Too easy
        } else {
            solvabilityScore = confidence  // Scale with difficulty
        }
        fitness += solvabilityScore * 0.3

        // Factor 2: Capability utilization (30%)
        // Challenges that use more of the player's abilities are better
        let playerCaps = loadout.allCapabilities
        let requiredCaps = challenge.requiredCapabilities
        let utilizationRatio = Double(requiredCaps.intersection(playerCaps).count) / Double(max(1, playerCaps.count))
        fitness += utilizationRatio * 0.3

        // Factor 3: Challenge complexity (20%)
        // More elements = more interesting (up to a point)
        let complexityScore = min(1.0, Double(challenge.elements.count) / 5.0)
        fitness += complexityScore * 0.2

        // Factor 4: Element variety (20%)
        // Different element types make challenges more interesting
        var elementTypes: Set<String> = []
        for element in challenge.elements {
            switch element.type {
            case .enemy: elementTypes.insert("enemy")
            case .invisibleEnemy: elementTypes.insert("invisible")
            case .target: elementTypes.insert("target")
            case .npc: elementTypes.insert("npc")
            case .darkness: elementTypes.insert("darkness")
            case .trigger: elementTypes.insert("trigger")
            case .obstacle: elementTypes.insert("obstacle")
            case .hazard: elementTypes.insert("hazard")
            }
        }
        let varietyScore = min(1.0, Double(elementTypes.count) / 3.0)
        fitness += varietyScore * 0.2

        return fitness
    }

    // MARK: - Helper Methods

    private func randomValidPosition(minDist: Int, maxDist: Int, avoiding: Set<HexCoord>) -> HexCoord {
        for _ in 0..<50 {
            let dist = randomSource.nextInt(upperBound: maxDist - minDist + 1) + minDist
            let dir = randomSource.nextInt(upperBound: 6)

            var pos = HexCoord.zero
            for _ in 0..<dist {
                pos = pos.neighbor(dir)
                if randomSource.nextBool() {
                    pos = pos.neighbor((dir + 1) % 6)
                }
            }

            if !avoiding.contains(pos) && pos.distance(to: .zero) <= ChallengeAI.hexRange {
                return pos
            }
        }
        return HexCoord(q: minDist, r: 0)
    }

    private func capabilitiesNeeded(for element: ChallengeElement) -> Set<SpellCapability> {
        switch element.type {
        case .enemy, .invisibleEnemy:
            return [.damage]
        case .darkness:
            return [.illumination]
        case .npc(let needsHealing, _):
            return needsHealing ? [.healing] : []
        case .trigger:
            return []
        case .obstacle(_, let destructible):
            return destructible ? [.damage] : []
        default:
            return []
        }
    }

    private func generateDescription(type: ChallengeType, elements: [ChallengeElement], attempt: Int) -> String {
        // Analyze elements to generate contextual description
        var enemyCount = 0
        var hasInvisible = false
        var hasDarkness = false
        var needsHealing = false
        var hasObstacle = false
        var hasTrigger = false
        var targetCount = 0

        for element in elements {
            switch element.type {
            case .enemy: enemyCount += 1
            case .invisibleEnemy: hasInvisible = true; enemyCount += 1
            case .darkness: hasDarkness = true
            case .npc(let healing, _): needsHealing = healing
            case .obstacle: hasObstacle = true
            case .trigger: hasTrigger = true
            case .target: targetCount += 1
            default: break
            }
        }

        // Generate dynamic description based on elements
        switch type {
        case .combat:
            if enemyCount >= 4 {
                let swarmMessages = [
                    "A swarm of creatures converges on your position!",
                    "You've stumbled into a nest of hostiles!",
                    "Enemies pour in from all directions!",
                    "A horde descends upon you!"
                ]
                var desc = swarmMessages[attempt % swarmMessages.count]
                if hasInvisible { desc += " Something unseen lurks nearby..." }
                if hasDarkness { desc += " Darkness shrouds the area." }
                return desc
            } else if enemyCount > 1 {
                let multiMessages = [
                    "Multiple hostiles block your path!",
                    "Several enemies prepare to attack!",
                    "You're outnumbered, but not outmatched!"
                ]
                var desc = multiMessages[attempt % multiMessages.count]
                if hasInvisible { desc += " Beware the unseen threat." }
                return desc
            } else {
                let singleMessages = [
                    "A dangerous creature bars your way!",
                    "An enemy emerges from the shadows!",
                    "Combat! Prepare yourself!"
                ]
                var desc = singleMessages[attempt % singleMessages.count]
                if hasDarkness { desc += " Darkness complicates matters." }
                return desc
            }

        case .obstacle:
            if hasObstacle {
                let messages = [
                    "The path ahead is blocked by debris!",
                    "Obstacles block your way forward!",
                    "Navigate past the barriers to reach your goal!"
                ]
                return messages[attempt % messages.count]
            } else {
                return "Navigate past the obstacles to reach your goal!"
            }

        case .puzzle:
            if hasDarkness && hasTrigger {
                return "Darkness shrouds ancient mechanisms. Illuminate and activate them to proceed!"
            } else if hasDarkness {
                let messages = [
                    "Impenetrable darkness blocks your path. Bring light to reveal the way!",
                    "You cannot see the exit. Dispel the magical darkness!",
                    "Shadows conceal the path forward. Light the way!"
                ]
                return messages[attempt % messages.count]
            } else if hasTrigger {
                let messages = [
                    "An ancient mechanism controls the way forward. Activate it!",
                    "A locked door bars your path. Find the trigger!",
                    "Magical wards seal this passage. Manipulate the controls!"
                ]
                return messages[attempt % messages.count]
            }
            return "Solve the puzzle to continue!"

        case .survival:
            let messages = [
                "Waves of enemies assault your position! Survive the onslaught!",
                "You're surrounded! Hold your ground until they fall!",
                "Enemies keep coming! Fight and heal to survive!",
                "The horde attacks relentlessly! Endure!"
            ]
            return messages[attempt % messages.count]

        case .stealth:
            let messages = [
                "Powerful sentinels guard this area. Slip past them unseen!",
                "These foes are too strong to fight. Sneak to your goal!",
                "Detection means death. Move carefully!",
                "The guardians are vigilant. Find a path through!"
            ]
            return messages[attempt % messages.count]

        case .rescue:
            let isMale = Bool.random()
            let pronoun = isMale ? "him" : "her"
            if needsHealing {
                let messages = [
                    "A wounded ally lies dying! Heal \(pronoun) before it's too late!",
                    "Someone needs your healing magic! Save \(pronoun)!",
                    "An injured survivor calls for help!"
                ]
                var desc = messages[attempt % messages.count]
                if enemyCount > 0 { desc += " But enemies threaten \(pronoun)!" }
                return desc
            } else {
                let messages = [
                    "A prisoner needs rescue! Reach \(pronoun)!",
                    "Someone is trapped! Free \(pronoun)!",
                    "An ally is cornered! Help \(pronoun) escape!"
                ]
                var desc = messages[attempt % messages.count]
                if enemyCount > 0 { desc += " Defeat the captors!" }
                return desc
            }

        case .timed:
            if targetCount > 3 {
                return "Quick! Touch all \(targetCount) beacons before the portal closes!"
            } else {
                let messages = [
                    "The magic fades! Reach all targets before time runs out!",
                    "Hurry! Activate all anchors before it's too late!",
                    "Race against time! Touch every beacon!"
                ]
                return messages[attempt % messages.count]
            }
        }
    }

    // MARK: - Fallback Challenge

    private func generateFallbackChallenge(type: ChallengeType, loadout: SpellLoadout) -> Challenge {
        // Generate a simple challenge that matches the requested TYPE
        var elements: [ChallengeElement] = []
        var required: Set<SpellCapability> = []
        var description: String

        switch type {
        case .combat, .survival:
            // Boss fallback
            if Self.isBossChallenge {
                let bossPos = HexCoord(q: 2, r: 0)
                elements.append(ChallengeElement(
                    type: .enemy(hp: Self.bossBaseHP, damage: enemyDamage(strong: true), behavior: .boss),
                    position: bossPos,
                    properties: [:]
                ))
                required.insert(.damage)
                description = "A powerful boss blocks your path. Defeat it!"
                break
            }

            // Combat/Survival - spawn enemies
            // Ranged attack players get ranged OR healer enemies (50/50)
            let maxAttackRange = loadout.spells.filter { $0.isOffensive }.map { $0.range }.max() ?? 1
            let hasRangedAttack = maxAttackRange >= 2
            if hasRangedAttack {
                let isMale = Bool.random()
                let pronoun = isMale ? "him" : "her"
                let subject = isMale ? "he" : "she"

                if Bool.random() {
                    elements.append(ChallengeElement(
                        type: .enemy(hp: 1, damage: enemyDamage(), behavior: .ranged),
                        position: HexCoord(q: maxAttackRange, r: 0),
                        properties: [:]
                    ))
                    description = "A distant archer takes aim! Shoot \(pronoun) before \(subject) shoots you!"
                } else {
                    elements.append(ChallengeElement(
                        type: .enemy(hp: 3, damage: enemyDamage(strong: true), behavior: .aggressive),
                        position: HexCoord(q: 2, r: 0),
                        properties: [:]
                    ))
                    elements.append(ChallengeElement(
                        type: .enemy(hp: 2, damage: enemyDamage(), behavior: .healer),
                        position: HexCoord(q: maxAttackRange, r: 0),
                        properties: [:]
                    ))
                    description = "A healer supports an ally! Shoot \(pronoun) from range!"
                }
            } else {
                elements.append(ChallengeElement(
                    type: .enemy(hp: 2, damage: enemyDamage(strong: true), behavior: .aggressive),
                    position: HexCoord(q: 2, r: 0),
                    properties: [:]
                ))
                elements.append(ChallengeElement(
                    type: .enemy(hp: 1, damage: enemyDamage(), behavior: .defensive),
                    position: HexCoord(q: 2, r: 1),
                    properties: [:]
                ))
                description = type == .combat ? "Hostile creatures block your path. Defeat them!" : "Survive the onslaught!"
            }
            required.insert(.damage)

        case .stealth, .timed:
            // Stealth/Timed - need a target to reach
            // Place target at distance 2 (not 3) so player has room to navigate
            elements.append(ChallengeElement(
                type: .target(required: true),
                position: HexCoord(q: 0, r: 2),
                properties: [:]
            ))
            if type == .stealth {
                // Add enemy OFF TO THE SIDE (not blocking direct path)
                // Enemy at (3, 0) - player can walk straight to (0, 2) safely
                // Detection range is 2, so enemy threatens side paths but not direct route
                elements.append(ChallengeElement(
                    type: .enemy(hp: 5, damage: 2, behavior: .defensive),
                    position: HexCoord(q: 3, r: 0),
                    properties: ["patrol": true]
                ))
                description = "Sneak past the guardian to reach the goal!"
            } else {
                description = "Reach the beacon before time runs out!"
            }

        case .obstacle:
            // Obstacle - wall of destructible obstacles + target
            // Target at r=2, wall at r=1 (covers q=-2 to q=2, all within visible range)
            elements.append(ChallengeElement(
                type: .target(required: true),
                position: HexCoord(q: 0, r: 2),
                properties: [:]
            ))
            // Create partial wall at r=1 with gaps to navigate
            for q in -2...2 {
                // Leave some gaps for navigation
                if q == 0 || (loadout.hasCapability(.damage) && q != -1) {
                    elements.append(ChallengeElement(
                        type: .obstacle(blocking: true, destructible: true),
                        position: HexCoord(q: q, r: 1),
                        properties: ["hp": 2]
                    ))
                }
            }
            required.insert(.damage)
            description = "Blast through the barriers to reach safety!"

        case .rescue:
            // Rescue - injured NPC (closer to player at distance 1 for easy targeting)
            let isMale = Bool.random()
            let pronoun = isMale ? "him" : "her"
            elements.append(ChallengeElement(
                type: .npc(needsHealing: true, needsRescue: false),
                position: HexCoord(q: 1, r: 0),
                properties: ["hp": 1, "maxHp": 2]
            ))
            required.insert(.healing)
            description = "An injured traveler needs your aid! Heal \(pronoun)!"

        case .puzzle:
            // Puzzle - darkness + target
            elements.append(ChallengeElement(
                type: .darkness(radius: 2),
                position: HexCoord(q: 1, r: 1),
                properties: [:]
            ))
            elements.append(ChallengeElement(
                type: .target(required: true),
                position: HexCoord(q: 2, r: 2),
                properties: [:]
            ))
            required.insert(.illumination)
            description = "Darkness conceals your destination. Light the way!"
        }

        return Challenge(
            type: type,
            description: description,
            requiredCapabilities: required,
            elements: elements,
            threatLevel: 1
        )
    }
}
