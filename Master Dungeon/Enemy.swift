//
//  Enemy.swift
//  Master Dungeon
//
//  Enemy entities that challenge the player.
//

#if canImport(SpriteKit)
import SpriteKit
#endif
#if canImport(GameplayKit)
import GameplayKit
typealias EnemyBase = GKEntity
#else
class EnemyBase {}
#endif

class Enemy: EnemyBase {
    // MARK: - Properties
    let id = UUID()
    private(set) var hp: Int
    private(set) var maxHP: Int
    let damage: Int
    let behavior: EnemyBehavior
    private(set) var position: HexCoord

    // Visual
    #if canImport(SpriteKit)
    weak var sprite: SKNode?
    #endif

    // Merge State
    private(set) var isMerged: Bool = false
    private(set) var mergeCount: Int = 1

    // AI State
    private(set) var isStunned: Bool = false
    private var stunTurnsRemaining: Int = 0
    private var turnsSinceLastSummon: Int = 0

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

    #if canImport(GameplayKit)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    #endif

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

        case .healer:
            return healerBehavior(playerPosition: playerPosition, distance: distanceToPlayer, blocked: blocked)

        case .boss:
            return bossBehavior(playerPosition: playerPosition, distance: distanceToPlayer, blocked: blocked)

        case .summoner:
            return summonerBehavior(playerPosition: playerPosition, distance: distanceToPlayer, blocked: blocked)
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
        if distance <= 3 && distance >= 2 {
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
        if distance > 3 {
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

    private func healerBehavior(playerPosition: HexCoord, distance: Int, blocked: Set<HexCoord>) -> EnemyAction {
        let preferredRange = 4
        let healRange = 3

        // Priority 1: Try to heal allies (GameScene will find the target)
        // Healers heal for their damage value
        if distance >= 2 {
            return .healAlly(amount: damage, range: healRange)
        }

        // Priority 2: If player is too close, retreat
        if distance < preferredRange {
            let retreatDir = findRetreatDirection(from: playerPosition, blocked: blocked)
            if let newPos = retreatDir {
                moveTo(newPos)
                return .move(to: newPos)
            }
        }

        // Priority 3: Weak attack if cornered
        if distance == 1 {
            return .attack(target: playerPosition, damage: max(1, damage / 2))
        }

        // Default: try to heal
        return .healAlly(amount: damage, range: healRange)
    }

    private func summonerBehavior(playerPosition: HexCoord, distance: Int, blocked: Set<HexCoord>) -> EnemyAction {
        turnsSinceLastSummon += 1

        // Cornered — weak attack
        if distance == 1 {
            return .attack(target: playerPosition, damage: damage)
        }

        // Summon every 2 turns on an adjacent empty hex
        if turnsSinceLastSummon >= 2 {
            let candidates = position.neighbors().filter { !blocked.contains($0) && $0 != playerPosition }
            if let summonPos = candidates.randomElement() {
                turnsSinceLastSummon = 0
                return .specialAttack(type: .summon, center: summonPos, radius: 0, damage: 1)
            }
        }

        // Retreat if player too close
        if distance < 2 {
            if let newPos = findRetreatDirection(from: playerPosition, blocked: blocked) {
                moveTo(newPos)
                return .move(to: newPos)
            }
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

    // MARK: - Merge Support

    static func behaviorPriority(_ behavior: EnemyBehavior) -> Int {
        switch behavior {
        case .boss: return 7
        case .aggressive: return 6
        case .ranged: return 5
        case .healer: return 4
        case .summoner: return 3
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

        let merged = Enemy(
            hp: totalHP,
            maxHP: totalMaxHP,
            damage: maxDamage,
            behavior: dominantBehavior,
            position: position,
            isMerged: true,
            mergeCount: enemies.reduce(0) { $0 + $1.mergeCount }
        )

        // Preserve stun state: use the longest remaining stun from any source enemy
        let maxStun = enemies.filter { $0.isStunned }.map { $0.stunTurnsRemaining }.max() ?? 0
        if maxStun > 0 {
            merged.stun(turns: maxStun)
        }

        return merged
    }
}

// MARK: - Enemy Actions

enum EnemyAction {
    case wait
    case move(to: HexCoord)
    case attack(target: HexCoord, damage: Int)
    case specialAttack(type: SpecialAttackType, center: HexCoord, radius: Int, damage: Int)
    case healAlly(amount: Int, range: Int)  // Healer heals nearby ally
    case stunned

    enum SpecialAttackType {
        case areaSlam    // Damages all hexes around boss
        case summon      // Create minions
    }
}

// MARK: - Enemy Factory

struct EnemyFactory {
    /// Blitz spells deal 2-4x more damage, so enemies need proportionally more HP
    private static var hpMultiplier: Int {
        GameManager.shared.gameMode == .blitz ? 2 : 1
    }

    static func createEnemy(from element: ChallengeElement, at position: HexCoord) -> Enemy? {
        switch element.type {
        case .enemy(let hp, let damage, let behavior):
            return Enemy(hp: hp * hpMultiplier, damage: damage, behavior: behavior, position: position)

        case .invisibleEnemy(let hp, let damage):
            let enemy = Enemy(hp: hp * hpMultiplier, damage: damage, behavior: .aggressive, position: position)
            // Mark as invisible (visual handling elsewhere)
            return enemy

        default:
            return nil
        }
    }

}
