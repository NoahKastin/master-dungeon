//
//  ChallengeGenerator.swift
//  Master Dungeon
//
//  Dynamic challenge generator that analyzes player spells and creates
//  tailored challenges. Each challenge showcases the player's abilities
//  and threatens 1 HP if not handled properly.
//

import Foundation
import GameplayKit

// MARK: - Challenge Types

/// A challenge the player must overcome
struct Challenge: Identifiable {
    let id = UUID()
    let type: ChallengeType
    let description: String
    let requiredCapabilities: Set<SpellCapability>
    let elements: [ChallengeElement]
    let threatLevel: Int  // Expected HP loss if not handled (usually 1)

    /// Check if a loadout can solve this challenge
    func isSolvableWith(_ loadout: SpellLoadout) -> Bool {
        requiredCapabilities.isSubset(of: loadout.allCapabilities)
    }
}

enum ChallengeType: String, CaseIterable {
    case combat           // Enemies to defeat
    case obstacle         // Physical barrier to overcome
    case puzzle           // Requires specific spell interaction
    case survival         // Endure damage/effects
    case stealth          // Avoid detection
    case rescue           // Save an NPC or object
    case timed            // Complete before time runs out
}

/// Individual elements that make up a challenge
struct ChallengeElement {
    let type: ElementType
    let position: HexCoord
    let properties: [String: Any]

    enum ElementType {
        case enemy(hp: Int, damage: Int, behavior: EnemyBehavior)
        case obstacle(blocking: Bool, destructible: Bool)
        case hazard(damagePerTurn: Int, radius: Int)
        case darkness(radius: Int)
        case target(required: Bool)  // Something to interact with
        case npc(needsHealing: Bool, needsRescue: Bool)
        case trigger(activates: String)  // Triggers another element
        case invisibleEnemy(hp: Int, damage: Int)
    }
}

enum EnemyBehavior {
    case aggressive    // Moves toward player, attacks in range
    case defensive     // Holds position, attacks if approached
    case ranged        // Keeps distance, attacks from range
    case healer        // Stays back, heals other enemies
    case swarm         // Multiple weak enemies, AoE effective
    case boss          // High HP, multiple attacks
}

// MARK: - Challenge Scenarios

/// A template for generating a challenge
struct ChallengeScenario {
    let name: String
    let type: ChallengeType
    let requiredCapabilities: Set<SpellCapability>
    let preferredCapabilities: Set<SpellCapability>  // Optional enhancements
    let descriptionTemplates: [String]
    let minElements: Int
    let maxElements: Int
}

// MARK: - Challenge Generator

class ChallengeGenerator {
    static var hexRange: Int { ChallengeAI.hexRange }
    private let randomSource: GKRandomSource
    private var challengeHistory: [ChallengeType] = []

    // AI system for guaranteed solvability
    private let challengeAI: ChallengeAI

    init(seed: UInt64? = nil) {
        if let seed = seed {
            randomSource = GKMersenneTwisterRandomSource(seed: seed)
            challengeAI = ChallengeAI(seed: seed)
        } else {
            randomSource = GKMersenneTwisterRandomSource()
            challengeAI = ChallengeAI()
        }
    }

    /// Generate a challenge dynamically tailored to the player's spell loadout
    /// Uses AI system (CSP + Monte Carlo) to guarantee solvability
    func generateChallenge(for loadout: SpellLoadout, difficulty: Int = 1) -> Challenge {
        // Analyze the loadout to understand what the player can do
        let analysis = analyzeLoadout(loadout)

        // Select a challenge type that varies from recent history
        let challengeType = selectVariedChallengeType(for: analysis)
        print("CHALLENGE DEBUG: Selected type = \(challengeType), hasDamage = \(analysis.capabilities.contains(.damage))")

        // Try AI-generated challenge first (guaranteed solvable)
        if let aiChallenge = challengeAI.generateSolvableChallenge(for: loadout, type: challengeType, difficulty: difficulty) {
            // Track history for variety
            challengeHistory.append(challengeType)
            if challengeHistory.count > 5 {
                challengeHistory.removeFirst()
            }
            return aiChallenge
        }

        // Fallback to procedural generation (for edge cases)
        let scenario = createScenario(type: challengeType, analysis: analysis, difficulty: difficulty)
        let elements = generateProceduralElements(scenario: scenario, analysis: analysis, difficulty: difficulty)
        let description = generateDescription(scenario: scenario, analysis: analysis)

        // Track history for variety
        challengeHistory.append(challengeType)
        if challengeHistory.count > 5 {
            challengeHistory.removeFirst()
        }

        return Challenge(
            type: challengeType,
            description: description,
            requiredCapabilities: scenario.requiredCapabilities,
            elements: elements,
            threatLevel: 1
        )
    }

    // MARK: - Loadout Analysis

    private struct LoadoutAnalysis {
        let spells: [Spell]
        let capabilities: Set<SpellCapability>

        // Specific spell categories
        var hasMeleeAttack: Bool { spells.contains { $0.isOffensive && $0.range <= 1 } }
        var hasRangedAttack: Bool { spells.contains { $0.isOffensive && $0.range >= 2 } }
        var maxAttackRange: Int { spells.filter { $0.isOffensive }.map { $0.range }.max() ?? 1 }
        var hasAoE: Bool { spells.contains { $0.isAoE } }
        var hasHealing: Bool { capabilities.contains(.healing) }
        var hasIllumination: Bool { capabilities.contains(.illumination) }
        var hasCrowdControl: Bool { capabilities.contains(.crowdControl) }
        var hasInformation: Bool { capabilities.contains(.information) }

        // Strongest damage spell
        var strongestOffense: Spell? {
            spells.filter { $0.isOffensive }.max { $0.rollOffense() < $1.rollOffense() }
        }

        // Most efficient spell (damage per mana)
        var mostEfficient: Spell? {
            spells.filter { $0.isOffensive && $0.manaCost > 0 }
                .max { Double($0.rollOffense()) / Double($0.manaCost) < Double($1.rollOffense()) / Double($1.manaCost) }
        }

        // Total mana in loadout
        var totalMana: Int { spells.reduce(0) { $0 + $1.manaCost } }

        // Average spell range
        var averageRange: Int {
            guard !spells.isEmpty else { return 1 }
            return spells.reduce(0) { $0 + $1.range } / spells.count
        }
    }

    private func analyzeLoadout(_ loadout: SpellLoadout) -> LoadoutAnalysis {
        return LoadoutAnalysis(
            spells: loadout.spells,
            capabilities: loadout.allCapabilities
        )
    }

    // MARK: - Challenge Type Selection

    private func selectVariedChallengeType(for analysis: LoadoutAnalysis) -> ChallengeType {
        var weights: [ChallengeType: Int] = [:]
        let hasDamage = analysis.capabilities.contains(.damage)

        // Combat/Survival REQUIRE damage capability
        if hasDamage {
            if analysis.hasMeleeAttack || analysis.hasRangedAttack {
                weights[.combat, default: 0] += 3
            }
            if analysis.hasAoE {
                weights[.combat, default: 0] += 2  // Swarm combat
            }
            // Survival requires damage AND benefits from healing
            if analysis.hasHealing {
                weights[.survival, default: 0] += 2
            } else {
                weights[.survival, default: 0] += 1  // Harder without healing
            }
        }

        // Obstacle - need damage (skip in hardcore)
        if GameManager.shared.gameMode != .hardcore {
            if hasDamage {
                weights[.obstacle, default: 0] += 3  // Can destroy obstacles
            }
        }

        // Puzzle - need illumination
        if analysis.hasIllumination {
            weights[.puzzle, default: 0] += 3
        }

        // Rescue - need healing
        if analysis.hasHealing {
            weights[.rescue, default: 0] += 3
        }

        // Stealth - benefits from crowd control (excluded in Blitz)
        if GameManager.shared.gameMode != .blitz {
            if analysis.hasCrowdControl {
                weights[.stealth, default: 0] += 3
            } else {
                weights[.stealth, default: 0] += 1  // Can still sneak around
            }
        }

        // Timed challenges are handled via stealth (stealth has a timer)

        // Ensure at least one challenge type is possible
        // If no weights set, add rescue if healing, otherwise timed/stealth (always winnable)
        if weights.isEmpty || weights.values.reduce(0, +) == 0 {
            if analysis.hasHealing {
                weights[.rescue] = 3
            }
            if GameManager.shared.gameMode == .blitz {
                weights[.obstacle, default: 0] += 3
            } else {
                weights[.stealth, default: 0] += 3  // Can always sneak (with timer)
            }
        }

        // Reduce weight for recently used types (variety)
        for recentType in challengeHistory {
            weights[recentType, default: 0] = max(0, (weights[recentType] ?? 0) - 2)
        }

        // Weighted random selection
        let totalWeight = weights.values.reduce(0, +)
        let fallback: ChallengeType = GameManager.shared.gameMode == .blitz ? .obstacle : .stealth
        guard totalWeight > 0 else {
            return analysis.hasHealing ? .rescue : fallback  // Safe fallback
        }

        var roll = randomSource.nextInt(upperBound: totalWeight)

        for (type, weight) in weights.sorted(by: { $0.value > $1.value }) {
            roll -= weight
            if roll < 0 {
                return type
            }
        }

        return analysis.hasHealing ? .rescue : fallback  // Safe fallback
    }

    // MARK: - Scenario Creation

    private func createScenario(type: ChallengeType, analysis: LoadoutAnalysis, difficulty: Int) -> ChallengeScenario {
        switch type {
        case .combat:
            return createCombatScenario(analysis: analysis, difficulty: difficulty)
        case .obstacle:
            return createObstacleScenario(analysis: analysis)
        case .puzzle:
            return createPuzzleScenario(analysis: analysis)
        case .survival:
            return createSurvivalScenario(analysis: analysis, difficulty: difficulty)
        case .stealth:
            return createStealthScenario(analysis: analysis)
        case .rescue:
            return createRescueScenario(analysis: analysis)
        case .timed:
            return createTimedScenario(analysis: analysis, difficulty: difficulty)
        }
    }

    private func createCombatScenario(analysis: LoadoutAnalysis, difficulty: Int) -> ChallengeScenario {
        var descriptions: [String] = []
        let required: Set<SpellCapability> = [.damage]
        var preferred: Set<SpellCapability> = []
        var minElem = 1
        var maxElem = 3

        if analysis.hasAoE {
            descriptions = [
                "A horde of creatures surrounds you!",
                "Swarm incoming! They're everywhere!",
                "Multiple enemies converge on your position!",
                "You've stumbled into a nest of hostiles!"
            ]
            minElem = 3 + difficulty
            maxElem = 5 + difficulty
            preferred.insert(.areaEffect)
        } else if analysis.hasRangedAttack {
            descriptions = [
                "A defensive enemy holds the high ground.",
                "A creature lurks at a distance, watching you.",
                "Ranged threat detected ahead.",
                "An enemy waits behind fortifications."
            ]
            preferred.insert(.ranged)
        } else if analysis.hasMeleeAttack {
            descriptions = [
                "An aggressive creature charges toward you!",
                "Combat! Prepare for close quarters!",
                "A beast rushes at you with fury!",
                "Enemy approaching rapidly!"
            ]
        } else {
            descriptions = [
                "A hostile creature blocks your path.",
                "You encounter a dangerous foe.",
                "An enemy stands before you.",
                "Threat detected. Prepare for battle."
            ]
        }

        if analysis.hasInformation {
            descriptions.append("Something lurks unseen nearby...")
            preferred.insert(.information)
        }

        return ChallengeScenario(
            name: "Combat",
            type: .combat,
            requiredCapabilities: required,
            preferredCapabilities: preferred,
            descriptionTemplates: descriptions,
            minElements: minElem,
            maxElements: maxElem
        )
    }

    private func createObstacleScenario(analysis: LoadoutAnalysis) -> ChallengeScenario {
        var descriptions: [String]
        let required: Set<SpellCapability> = [.damage]

        if analysis.capabilities.contains(.damage) {
            descriptions = [
                "A barrier blocks your way. Find a path or destroy it!",
                "The path ahead is blocked by debris.",
                "Obstacles litter the area. Navigate or clear them!",
                "Multiple barriers stand between you and your goal."
            ]
        } else {
            descriptions = [
                "Barriers block your path. Find a way through!",
                "Obstacles stand between you and your goal.",
                "Navigate the hazards ahead.",
                "Clear the path to safety."
            ]
        }

        return ChallengeScenario(
            name: "Obstacle Course",
            type: .obstacle,
            requiredCapabilities: required,
            preferredCapabilities: [.damage],
            descriptionTemplates: descriptions,
            minElements: 3,
            maxElements: 6
        )
    }

    private func createPuzzleScenario(analysis: LoadoutAnalysis) -> ChallengeScenario {
        var descriptions: [String] = []
        var required: Set<SpellCapability> = []

        if analysis.hasIllumination {
            descriptions.append("Darkness shrouds the area. Bring light to reveal the path!")
            required.insert(.illumination)
        }
        if analysis.hasInformation {
            descriptions.append("Hidden secrets lie nearby. Use your insight to find them!")
        }

        if descriptions.isEmpty {
            descriptions = ["A mysterious puzzle blocks your progress."]
        }

        return ChallengeScenario(
            name: "Puzzle",
            type: .puzzle,
            requiredCapabilities: required,
            preferredCapabilities: [.information],
            descriptionTemplates: descriptions,
            minElements: 2,
            maxElements: 4
        )
    }

    private func createSurvivalScenario(analysis: LoadoutAnalysis, difficulty: Int) -> ChallengeScenario {
        let descriptions = [
            "Survive the onslaught! Enemies keep coming!",
            "Endure the assault until help arrives!",
            "Hold your ground against waves of enemies!",
            "You're surrounded! Fight to survive!"
        ]

        return ChallengeScenario(
            name: "Survival",
            type: .survival,
            requiredCapabilities: [.damage, .healing],
            preferredCapabilities: [.crowdControl],
            descriptionTemplates: descriptions,
            minElements: 2 + difficulty,
            maxElements: 4 + difficulty
        )
    }

    private func createStealthScenario(analysis: LoadoutAnalysis) -> ChallengeScenario {
        let descriptions = [
            "Powerful guardians patrol the area. Avoid or disable them!",
            "Slip past the sentries to reach your goal.",
            "The enemies are too strong to fight. Find another way!",
            "Stealth is key. Don't let them see you!"
        ]

        return ChallengeScenario(
            name: "Stealth",
            type: .stealth,
            requiredCapabilities: [],
            preferredCapabilities: [.crowdControl],
            descriptionTemplates: descriptions,
            minElements: 3,
            maxElements: 5
        )
    }

    private func createRescueScenario(analysis: LoadoutAnalysis) -> ChallengeScenario {
        var descriptions: [String]
        var required: Set<SpellCapability> = []

        if analysis.hasHealing {
            let isMale = Bool.random()
            let pronoun = isMale ? "him" : "her"
            descriptions = [
                "An injured ally needs your healing magic! Save \(pronoun)!",
                "Save the wounded \(isMale ? "man" : "woman") before it's too late!",
                "A dying \(isMale ? "villager" : "villager") calls for help! Heal \(pronoun)!"
            ]
            required.insert(.healing)
        } else {
            let isMale = Bool.random()
            let pronoun = isMale ? "him" : "her"
            descriptions = [
                "A prisoner is trapped! Free \(pronoun)!",
                "Rescue the captive from the enemy!",
                "An ally is cornered! Help \(pronoun) escape!"
            ]
        }

        return ChallengeScenario(
            name: "Rescue",
            type: .rescue,
            requiredCapabilities: required,
            preferredCapabilities: [.damage],
            descriptionTemplates: descriptions,
            minElements: 2,
            maxElements: 4
        )
    }

    private func createTimedScenario(analysis: LoadoutAnalysis, difficulty: Int) -> ChallengeScenario {
        let descriptions = [
            "Hit all targets before time runs out!",
            "Quick! Activate all beacons!",
            "Race against time to reach all objectives!",
            "The portal is closing! Touch all anchors!"
        ]

        return ChallengeScenario(
            name: "Timed Challenge",
            type: .timed,
            requiredCapabilities: [],
            preferredCapabilities: [.ranged, .areaEffect],
            descriptionTemplates: descriptions,
            minElements: 3 + difficulty,
            maxElements: 5 + difficulty
        )
    }

    // MARK: - Procedural Element Generation

    private func generateProceduralElements(scenario: ChallengeScenario, analysis: LoadoutAnalysis, difficulty: Int) -> [ChallengeElement] {
        var elements: [ChallengeElement] = []
        var usedPositions: Set<HexCoord> = [.zero]  // Player starts at 0,0

        let elementCount = randomSource.nextInt(upperBound: scenario.maxElements - scenario.minElements + 1) + scenario.minElements

        switch scenario.type {
        case .combat:
            elements = generateCombatElements(count: elementCount, analysis: analysis, difficulty: difficulty, usedPositions: &usedPositions)
        case .obstacle:
            elements = generateObstacleElements(count: elementCount, analysis: analysis, usedPositions: &usedPositions)
        case .puzzle:
            elements = generatePuzzleElements(count: elementCount, analysis: analysis, usedPositions: &usedPositions)
        case .survival:
            elements = generateSurvivalElements(count: elementCount, analysis: analysis, difficulty: difficulty, usedPositions: &usedPositions)
        case .stealth:
            elements = generateStealthElements(count: elementCount, analysis: analysis, usedPositions: &usedPositions)
        case .rescue:
            elements = generateRescueElements(count: elementCount, analysis: analysis, usedPositions: &usedPositions)
        case .timed:
            elements = generateTimedElements(count: elementCount, analysis: analysis, usedPositions: &usedPositions)
        }

        return elements
    }

    private func randomPosition(minDistance: Int, maxDistance: Int, avoiding: Set<HexCoord>) -> HexCoord {
        for _ in 0..<50 {  // Max attempts
            let distance = randomSource.nextInt(upperBound: maxDistance - minDistance + 1) + minDistance
            let direction = randomSource.nextInt(upperBound: 6)

            // Generate position at roughly the right distance
            var pos = HexCoord.zero
            for _ in 0..<distance {
                pos = pos.neighbor(direction)
                // Add some variation
                if randomSource.nextBool() {
                    pos = pos.neighbor((direction + 1) % 6)
                }
            }

            if !avoiding.contains(pos) && pos.distance(to: .zero) <= Self.hexRange {
                return pos
            }
        }

        // Fallback to simple position
        return HexCoord(q: minDistance, r: 0)
    }

    /// Enemy damage for the current mode. Medium uses d1-d3 weighted low; others use 1.
    private func enemyDamage(strong: Bool = false) -> Int {
        guard GameManager.shared.gameMode == .medium else { return 1 }
        if strong {
            // Strong enemies: 2 or 3 (weighted toward 2)
            return randomSource.nextInt(upperBound: 3) < 2 ? 2 : 3
        }
        // Regular enemies: 1 or 2 (weighted toward 1)
        return randomSource.nextInt(upperBound: 3) < 2 ? 1 : 2
    }

    private func generateCombatElements(count: Int, analysis: LoadoutAnalysis, difficulty: Int, usedPositions: inout Set<HexCoord>) -> [ChallengeElement] {
        var elements: [ChallengeElement] = []

        // Ranged attack players get ranged OR healer enemies (50/50)
        if analysis.hasRangedAttack {
            if randomSource.nextBool() {
                let rangeForEnemy = analysis.maxAttackRange
                let rangedPos = randomPosition(minDistance: rangeForEnemy, maxDistance: rangeForEnemy, avoiding: usedPositions)
                usedPositions.insert(rangedPos)
                elements.append(ChallengeElement(
                    type: .enemy(hp: 1, damage: enemyDamage(), behavior: .ranged),
                    position: rangedPos,
                    properties: [:]
                ))
            } else {
                let frontPos = randomPosition(minDistance: 2, maxDistance: 2, avoiding: usedPositions)
                usedPositions.insert(frontPos)
                elements.append(ChallengeElement(
                    type: .enemy(hp: 3 + difficulty, damage: enemyDamage(strong: true), behavior: .aggressive),
                    position: frontPos,
                    properties: [:]
                ))

                let rangeForEnemy = analysis.maxAttackRange
                let healerPos = randomPosition(minDistance: rangeForEnemy, maxDistance: rangeForEnemy, avoiding: usedPositions)
                usedPositions.insert(healerPos)
                elements.append(ChallengeElement(
                    type: .enemy(hp: 2, damage: enemyDamage(), behavior: .healer),
                    position: healerPos,
                    properties: [:]
                ))
            }
            return elements
        }

        if analysis.hasAoE {
            // Swarm: multiple weak enemies
            for _ in 0..<count {
                let pos = randomPosition(minDistance: 2, maxDistance: Self.hexRange, avoiding: usedPositions)
                usedPositions.insert(pos)
                elements.append(ChallengeElement(
                    type: .enemy(hp: 1, damage: enemyDamage(), behavior: .swarm),
                    position: pos,
                    properties: [:]
                ))
            }
        } else if analysis.hasRangedAttack {
            // Defensive enemy at range
            let rangeForEnemy = analysis.maxAttackRange
            let pos = randomPosition(minDistance: rangeForEnemy, maxDistance: rangeForEnemy, avoiding: usedPositions)
            usedPositions.insert(pos)
            elements.append(ChallengeElement(
                type: .enemy(hp: 2 + difficulty, damage: enemyDamage(strong: true), behavior: .defensive),
                position: pos,
                properties: [:]
            ))
        } else {
            // Aggressive enemy for melee
            let pos = randomPosition(minDistance: 2, maxDistance: Self.hexRange, avoiding: usedPositions)
            usedPositions.insert(pos)
            elements.append(ChallengeElement(
                type: .enemy(hp: 2 + difficulty, damage: enemyDamage(strong: true), behavior: .aggressive),
                position: pos,
                properties: [:]
            ))
        }

        // Add invisible enemy if player can detect
        if analysis.hasInformation && randomSource.nextBool() {
            let pos = randomPosition(minDistance: 2, maxDistance: Self.hexRange, avoiding: usedPositions)
            usedPositions.insert(pos)
            elements.append(ChallengeElement(
                type: .invisibleEnemy(hp: 2, damage: enemyDamage()),
                position: pos,
                properties: [:]
            ))
        }

        // Add darkness if player has illumination, with a hidden enemy inside
        if analysis.hasIllumination && randomSource.nextBool() {
            let darknessPos = randomPosition(minDistance: 1, maxDistance: Self.hexRange - 1, avoiding: usedPositions)
            elements.append(ChallengeElement(
                type: .darkness(radius: 2),
                position: darknessPos,
                properties: [:]
            ))

            // Move an existing enemy into the darkness zone instead of adding a new one
            let darknessHexes = darknessPos.hexesInRange(2).filter { !usedPositions.contains($0) && $0 != .zero && $0.distance(to: .zero) <= Self.hexRange }
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

    private func generateObstacleElements(count: Int, analysis: LoadoutAnalysis, usedPositions: inout Set<HexCoord>) -> [ChallengeElement] {
        var elements: [ChallengeElement] = []

        // Determine if we should fully block the goal
        let hasDamage = analysis.capabilities.contains(.damage)

        // 50% chance to fully block when player can destroy obstacles
        let fullyBlock = hasDamage && randomSource.nextBool()
        print("OBSTACLE DEBUG: hasDamage=\(hasDamage), fullyBlock=\(fullyBlock)")

        if fullyBlock {
            // Create a complete wall at r=1 to block access to target at r=2
            // At r=1, we can cover q=-2 to q=2 (all within 3-hex visible range)
            let targetPos = HexCoord(q: 0, r: 2)
            usedPositions.insert(targetPos)
            elements.append(ChallengeElement(
                type: .target(required: true),
                position: targetPos,
                properties: [:]
            ))

            // Complete wall at r=1 (covers all bypass routes)
            for q in -2...2 {
                let pos = HexCoord(q: q, r: 1)
                usedPositions.insert(pos)
                if hasDamage {
                    elements.append(ChallengeElement(
                        type: .obstacle(blocking: true, destructible: true),
                        position: pos,
                        properties: ["hp": 2]
                    ))
                } else {
                    elements.append(ChallengeElement(
                        type: .obstacle(blocking: true, destructible: false),
                        position: pos,
                        properties: [:]
                    ))
                }
            }
        } else {
            // Partial obstacles with gaps - standard obstacle course
            for i in -1...1 {
                let pos = HexCoord(q: i, r: 2)
                usedPositions.insert(pos)

                if hasDamage && randomSource.nextBool() {
                    elements.append(ChallengeElement(
                        type: .obstacle(blocking: true, destructible: true),
                        position: pos,
                        properties: ["hp": 2]
                    ))
                } else {
                    // Leave gap for player to navigate through
                    // Only add obstacle 50% of the time to create paths
                    if randomSource.nextBool() {
                        elements.append(ChallengeElement(
                            type: .obstacle(blocking: true, destructible: false),
                            position: pos,
                            properties: [:]
                        ))
                    }
                }
            }

            // Target at random position
            let targetPos = randomPosition(minDistance: Self.hexRange, maxDistance: Self.hexRange, avoiding: usedPositions)
            usedPositions.insert(targetPos)
            elements.append(ChallengeElement(
                type: .target(required: true),
                position: targetPos,
                properties: [:]
            ))
        }

        return elements
    }

    private func generatePuzzleElements(count: Int, analysis: LoadoutAnalysis, usedPositions: inout Set<HexCoord>) -> [ChallengeElement] {
        var elements: [ChallengeElement] = []

        if analysis.hasIllumination {
            let darknessPos = randomPosition(minDistance: 1, maxDistance: 2, avoiding: usedPositions)
            elements.append(ChallengeElement(
                type: .darkness(radius: 3),
                position: darknessPos,
                properties: [:]
            ))
        }

        // Hidden target
        let targetPos = randomPosition(minDistance: Self.hexRange, maxDistance: Self.hexRange, avoiding: usedPositions)
        usedPositions.insert(targetPos)
        elements.append(ChallengeElement(
            type: .target(required: true),
            position: targetPos,
            properties: [:]
        ))

        return elements
    }

    private func generateSurvivalElements(count: Int, analysis: LoadoutAnalysis, difficulty: Int, usedPositions: inout Set<HexCoord>) -> [ChallengeElement] {
        var elements: [ChallengeElement] = []

        // Add hazard if player has healing
        if analysis.hasHealing {
            let hazardPos = HexCoord(q: 1, r: 1)
            elements.append(ChallengeElement(
                type: .hazard(damagePerTurn: 1, radius: 2),
                position: hazardPos,
                properties: [:]
            ))
        }

        // Multiple enemies
        for _ in 0..<count {
            let pos = randomPosition(minDistance: 2, maxDistance: Self.hexRange, avoiding: usedPositions)
            usedPositions.insert(pos)
            elements.append(ChallengeElement(
                type: .enemy(hp: 2 + difficulty, damage: enemyDamage(strong: true), behavior: .aggressive),
                position: pos,
                properties: [:]
            ))
        }

        return elements
    }

    private func generateStealthElements(count: Int, analysis: LoadoutAnalysis, usedPositions: inout Set<HexCoord>) -> [ChallengeElement] {
        var elements: [ChallengeElement] = []

        // Powerful patrolling enemies
        for i in 0..<min(3, count) {
            let pos = HexCoord(q: i * 2, r: 1)
            usedPositions.insert(pos)
            elements.append(ChallengeElement(
                type: .enemy(hp: 10, damage: enemyDamage(strong: true), behavior: .defensive),
                position: pos,
                properties: ["patrol": true]
            ))
        }

        // Target to reach
        let targetPos = randomPosition(minDistance: Self.hexRange, maxDistance: Self.hexRange, avoiding: usedPositions)
        usedPositions.insert(targetPos)
        elements.append(ChallengeElement(
            type: .target(required: true),
            position: targetPos,
            properties: [:]
        ))

        return elements
    }

    private func generateRescueElements(count: Int, analysis: LoadoutAnalysis, usedPositions: inout Set<HexCoord>) -> [ChallengeElement] {
        var elements: [ChallengeElement] = []

        // NPC to rescue
        let npcPos = randomPosition(minDistance: 2, maxDistance: Self.hexRange, avoiding: usedPositions)
        usedPositions.insert(npcPos)

        if analysis.hasHealing {
            elements.append(ChallengeElement(
                type: .npc(needsHealing: true, needsRescue: false),
                position: npcPos,
                properties: ["hp": 1, "maxHp": 3]
            ))
        } else {
            elements.append(ChallengeElement(
                type: .npc(needsHealing: false, needsRescue: true),
                position: npcPos,
                properties: [:]
            ))
        }

        // Enemy threatening NPC
        let enemyPos = randomPosition(minDistance: 2, maxDistance: Self.hexRange, avoiding: usedPositions)
        usedPositions.insert(enemyPos)
        elements.append(ChallengeElement(
            type: .enemy(hp: 2, damage: enemyDamage(), behavior: .aggressive),
            position: enemyPos,
            properties: ["targetingNpc": true]
        ))

        return elements
    }

    private func generateTimedElements(count: Int, analysis: LoadoutAnalysis, usedPositions: inout Set<HexCoord>) -> [ChallengeElement] {
        var elements: [ChallengeElement] = []

        // Multiple targets arranged in a circle
        for i in 0..<count {
            let angle = Double(i) * (2.0 * .pi / Double(count))
            let distance = Self.hexRange
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

    // MARK: - Description Generation

    private func generateDescription(scenario: ChallengeScenario, analysis: LoadoutAnalysis) -> String {
        let templates = scenario.descriptionTemplates
        let index = randomSource.nextInt(upperBound: templates.count)
        return templates[index]
    }

    // MARK: - Multiplayer Support

    /// Generate challenges for multiplayer where each player has different spells
    func generateMultiplayerChallenges(loadouts: [SpellLoadout]) -> [Challenge] {
        var challenges: [Challenge] = []

        for (index, loadout) in loadouts.enumerated() {
            var challenge = generateChallenge(for: loadout)
            // Modify description for multiplayer
            let multiplayerDesc = "Player \(index + 1): " + challenge.description
            challenge = Challenge(
                type: challenge.type,
                description: multiplayerDesc,
                requiredCapabilities: challenge.requiredCapabilities,
                elements: challenge.elements,
                threatLevel: challenge.threatLevel
            )
            challenges.append(challenge)
        }

        return challenges
    }
}
