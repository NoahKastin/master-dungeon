//
//  Enemy.swift
//  Master Dungeon
//
//  Enemy entities that challenge the player.
//

import SpriteKit
import GameplayKit

class Enemy: GKEntity {
    // MARK: - Properties
    let id = UUID()
    private(set) var hp: Int
    private(set) var maxHP: Int
    let damage: Int
    let behavior: EnemyBehavior
    private(set) var position: HexCoord

    // Visual
    weak var sprite: SKNode?

    // Merge State
    private(set) var isMerged: Bool = false
    private(set) var mergeCount: Int = 1

    // AI State
    private(set) var isStunned: Bool = false
    private var stunTurnsRemaining: Int = 0

    // Callbacks
    var onPositionChanged: ((HexCoord) -> Void)?
    var onHPChanged: ((Int) -> Void)?
    var onDeath: (() -> Void)?

    // MARK: - Initialization

    init(hp: Int, damage: Int, behavior: EnemyBehavior, position: HexCoord) {
        self.hp = hp
        self.maxHP = hp
        self.damage = damage
        self.behavior = behavior
        self.position = position
        super.init()
    }

    init(hp: Int, maxHP: Int, damage: Int, behavior: EnemyBehavior, position: HexCoord, isMerged: Bool, mergeCount: Int) {
        self.hp = hp
        self.maxHP = maxHP
        self.damage = damage
        self.behavior = behavior
        self.position = position
        self.isMerged = isMerged
        self.mergeCount = mergeCount
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Combat

    func takeDamage(_ amount: Int) {
        hp = max(0, hp - amount)
        onHPChanged?(hp)

        if hp <= 0 {
            onDeath?()
        }
    }

    func heal(_ amount: Int) {
        hp = min(maxHP, hp + amount)
        onHPChanged?(hp)
    }

    var isAlive: Bool { hp > 0 }

    func stun(turns: Int) {
        isStunned = true
        stunTurnsRemaining = turns
    }

    // MARK: - AI

    /// Decide and execute action for this turn
    func takeTurn(playerPosition: HexCoord, blocked: Set<HexCoord>) -> EnemyAction {
        // Check if stunned
        if isStunned {
            stunTurnsRemaining -= 1
            if stunTurnsRemaining <= 0 {
                isStunned = false
            }
            return .stunned
        }

        let distanceToPlayer = position.distance(to: playerPosition)

        switch behavior {
        case .aggressive:
            return aggressiveBehavior(playerPosition: playerPosition, distance: distanceToPlayer, blocked: blocked)

        case .defensive:
            return defensiveBehavior(playerPosition: playerPosition, distance: distanceToPlayer, blocked: blocked)

        case .ranged:
            return rangedBehavior(playerPosition: playerPosition, distance: distanceToPlayer, blocked: blocked)

        case .swarm:
            return swarmBehavior(playerPosition: playerPosition, distance: distanceToPlayer, blocked: blocked)

        case .boss:
            return bossBehavior(playerPosition: playerPosition, distance: distanceToPlayer, blocked: blocked)
        }
    }

    private func aggressiveBehavior(playerPosition: HexCoord, distance: Int, blocked: Set<HexCoord>) -> EnemyAction {
        // If adjacent, attack
        if distance == 1 {
            return .attack(target: playerPosition, damage: damage)
        }

        // Otherwise, move toward player
        if let path = HexPathfinder.findPath(from: position, to: playerPosition, blocked: blocked),
           path.count > 1 {
            let nextPos = path[1]
            moveTo(nextPos)
            return .move(to: nextPos)
        }

        return .wait
    }

    private func defensiveBehavior(playerPosition: HexCoord, distance: Int, blocked: Set<HexCoord>) -> EnemyAction {
        // Attack if player comes within range 2
        if distance <= 2 {
            if distance == 1 {
                return .attack(target: playerPosition, damage: damage)
            }
            // Move to attack
            if let path = HexPathfinder.findPath(from: position, to: playerPosition, blocked: blocked),
               path.count > 1 {
                let nextPos = path[1]
                moveTo(nextPos)
                return .move(to: nextPos)
            }
        }

        // Otherwise hold position
        return .wait
    }

    private func rangedBehavior(playerPosition: HexCoord, distance: Int, blocked: Set<HexCoord>) -> EnemyAction {
        let preferredRange = 3

        // Attack from range if possible
        if distance <= 4 && distance >= 2 {
            return .attack(target: playerPosition, damage: damage)
        }

        // If too close, try to retreat
        if distance < preferredRange {
            let retreatDir = findRetreatDirection(from: playerPosition, blocked: blocked)
            if let newPos = retreatDir {
                moveTo(newPos)
                return .move(to: newPos)
            }
        }

        // If too far, approach
        if distance > 4 {
            if let path = HexPathfinder.findPath(from: position, to: playerPosition, blocked: blocked),
               path.count > 1 {
                let nextPos = path[1]
                moveTo(nextPos)
                return .move(to: nextPos)
            }
        }

        return .wait
    }

    private func swarmBehavior(playerPosition: HexCoord, distance: Int, blocked: Set<HexCoord>) -> EnemyAction {
        // Swarm enemies are simple - just rush the player
        if distance == 1 {
            return .attack(target: playerPosition, damage: damage)
        }

        if let path = HexPathfinder.findPath(from: position, to: playerPosition, blocked: blocked),
           path.count > 1 {
            let nextPos = path[1]
            moveTo(nextPos)
            return .move(to: nextPos)
        }

        return .wait
    }

    private func bossBehavior(playerPosition: HexCoord, distance: Int, blocked: Set<HexCoord>) -> EnemyAction {
        // Boss has special attack patterns
        if distance == 1 {
            // Melee attack with bonus damage
            return .attack(target: playerPosition, damage: damage + 1)
        }

        if distance <= 3 {
            // Special area attack
            return .specialAttack(type: .areaSlam, center: position, radius: 1, damage: damage)
        }

        // Chase player
        if let path = HexPathfinder.findPath(from: position, to: playerPosition, blocked: blocked),
           path.count > 1 {
            let nextPos = path[1]
            moveTo(nextPos)
            return .move(to: nextPos)
        }

        return .wait
    }

    private func findRetreatDirection(from threatPos: HexCoord, blocked: Set<HexCoord>) -> HexCoord? {
        let neighbors = position.neighbors()
        var bestNeighbor: HexCoord?
        var bestDistance = position.distance(to: threatPos)

        for neighbor in neighbors {
            guard !blocked.contains(neighbor) else { continue }
            let dist = neighbor.distance(to: threatPos)
            if dist > bestDistance {
                bestDistance = dist
                bestNeighbor = neighbor
            }
        }

        return bestNeighbor
    }

    // MARK: - Movement

    func moveTo(_ coord: HexCoord) {
        position = coord
        onPositionChanged?(position)
    }

    func teleportTo(_ coord: HexCoord) {
        position = coord
        onPositionChanged?(position)
    }

    // MARK: - Merge Support

    static func behaviorPriority(_ behavior: EnemyBehavior) -> Int {
        switch behavior {
        case .boss: return 5
        case .aggressive: return 4
        case .ranged: return 3
        case .swarm: return 2
        case .defensive: return 1
        }
    }

    static func merge(_ enemies: [Enemy], at position: HexCoord) -> Enemy? {
        guard enemies.count >= 2 else { return nil }

        let totalHP = enemies.reduce(0) { $0 + $1.hp }
        let totalMaxHP = enemies.reduce(0) { $0 + $1.maxHP }
        let maxDamage = enemies.map { $0.damage }.max() ?? 1
        let dominantBehavior = enemies
            .map { $0.behavior }
            .max { behaviorPriority($0) < behaviorPriority($1) } ?? .aggressive

        return Enemy(
            hp: totalHP,
            maxHP: totalMaxHP,
            damage: maxDamage,
            behavior: dominantBehavior,
            position: position,
            isMerged: true,
            mergeCount: enemies.reduce(0) { $0 + $1.mergeCount }
        )
    }
}

// MARK: - Enemy Actions

enum EnemyAction {
    case wait
    case move(to: HexCoord)
    case attack(target: HexCoord, damage: Int)
    case specialAttack(type: SpecialAttackType, center: HexCoord, radius: Int, damage: Int)
    case stunned

    enum SpecialAttackType {
        case areaSlam    // Damages all hexes around boss
        case charge      // Rush in a line
        case summon      // Create minions
    }
}

// MARK: - Enemy Factory

struct EnemyFactory {
    static func createEnemy(from element: ChallengeElement, at position: HexCoord) -> Enemy? {
        switch element.type {
        case .enemy(let hp, let damage, let behavior):
            return Enemy(hp: hp, damage: damage, behavior: behavior, position: position)

        case .invisibleEnemy(let hp, let damage):
            let enemy = Enemy(hp: hp, damage: damage, behavior: .aggressive, position: position)
            // Mark as invisible (visual handling elsewhere)
            return enemy

        default:
            return nil
        }
    }

    static func createSwarm(count: Int, around center: HexCoord, hp: Int = 1, damage: Int = 1) -> [Enemy] {
        var enemies: [Enemy] = []
        let positions = center.hexesInRange(2).shuffled().prefix(count)

        for pos in positions {
            let enemy = Enemy(hp: hp, damage: damage, behavior: .swarm, position: pos)
            enemies.append(enemy)
        }

        return enemies
    }
}
