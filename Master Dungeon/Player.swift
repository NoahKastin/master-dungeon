//
//  Player.swift
//  Master Dungeon
//
//  Player entity with HP, mana, position, and spell management.
//

import SpriteKit
import GameplayKit

class Player: GKEntity {
    // MARK: - Constants
    static var maxHP: Int {
        switch GameManager.shared.gameMode {
        case .medium: return 10
        case .hardcore: return 1
        case .normal, .blitz: return 4
        }
    }
    static var maxMana: Int {
        GameManager.shared.gameMode == .medium ? 1 : 2
    }

    // MARK: - State
    private(set) var hp: Int = Player.maxHP
    private(set) var mana: Int = Player.maxMana
    private(set) var position: HexCoord = .zero
    private(set) var loadout: SpellLoadout = SpellLoadout()

    // Active passive spells
    private(set) var activePassives: Set<String> = []

    // Movement
    private(set) var isMoving: Bool = false
    private var movementPath: [HexCoord] = []
    private var movementSpeed: TimeInterval = 0.2  // Time per hex

    // Visual
    weak var sprite: SKNode?

    // Callbacks
    var onPositionChanged: ((HexCoord) -> Void)?
    var onHPChanged: ((Int) -> Void)?
    var onManaChanged: ((Int) -> Void)?
    var onMovementComplete: (() -> Void)?

    // MARK: - Initialization

    override init() {
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setLoadout(_ loadout: SpellLoadout) {
        self.loadout = loadout
        activePassives.removeAll()
    }

    // MARK: - HP Management

    func takeDamage(_ amount: Int) {
        hp = max(0, hp - amount)
        onHPChanged?(hp)
    }

    func heal(_ amount: Int) {
        hp = min(Player.maxHP, hp + amount)
        onHPChanged?(hp)
    }

    var isAlive: Bool { hp > 0 }

    // MARK: - Mana Management

    func spendMana(_ amount: Int) -> Bool {
        guard mana >= amount else { return false }
        mana -= amount
        onManaChanged?(mana)
        return true
    }

    func restoreMana(_ amount: Int) {
        mana = min(Player.maxMana, mana + amount)
        onManaChanged?(mana)
    }

    func canCast(_ spell: Spell) -> Bool {
        if GameManager.shared.gameMode == .blitz { return loadout.spells.contains(spell) }
        return loadout.spells.contains(spell) && mana >= spell.manaCost
    }

    // MARK: - Spell Casting

    func castSpell(_ spell: Spell, at target: HexCoord) -> SpellCastResult {
        guard loadout.spells.contains(spell) else {
            return .failure(.notInLoadout)
        }

        let isBlitz = GameManager.shared.gameMode == .blitz
        if !isBlitz {
            guard mana >= spell.manaCost else {
                return .failure(.insufficientMana)
            }
        }

        let distance = position.distance(to: target)
        guard distance <= spell.range else {
            return .failure(.outOfRange)
        }

        // Spend mana (skip in Blitz — no mana system)
        if !isBlitz {
            mana = max(0, min(Player.maxMana, mana - spell.manaCost))
            onManaChanged?(mana)
        }

        // Handle pure passive toggle (non-offensive, non-defensive passives)
        if spell.isPassive && !spell.isOffensive && !spell.isDefensive {
            if activePassives.contains(spell.id) {
                activePassives.remove(spell.id)
                return .success(effect: .deactivatedPassive)
            } else {
                activePassives.insert(spell.id)
                return .success(effect: .activatedPassive)
            }
        }

        // For passive weapon spells (Flame Blade, Brand, etc.), track the buff
        // but still process the attack
        if spell.isPassive && spell.isOffensive {
            if !activePassives.contains(spell.id) {
                activePassives.insert(spell.id)
            }
        }

        // Calculate effect
        var effect = SpellEffect.none

        if spell.isOffensive {
            let damage = spell.rollOffense()
            effect = .damage(damage)
        } else if spell.isDefensive {
            let healing = spell.rollDefense()
            effect = .healing(healing)
        }

        return .success(effect: effect)
    }

    func isPassiveActive(_ spell: Spell) -> Bool {
        activePassives.contains(spell.id)
    }

    // MARK: - Movement

    func moveTo(_ destination: HexCoord, blocked: Set<HexCoord>, completion: @escaping () -> Void) {
        guard !isMoving else { return }

        guard let path = HexPathfinder.findPath(from: position, to: destination, blocked: blocked) else {
            completion()
            return
        }

        // Remove current position from path
        movementPath = Array(path.dropFirst())

        if movementPath.isEmpty {
            completion()
            return
        }

        isMoving = true
        onMovementComplete = completion
    }

    func teleportTo(_ destination: HexCoord) {
        position = destination
        onPositionChanged?(position)
    }

    // MARK: - Update

    override func update(deltaTime seconds: TimeInterval) {
        super.update(deltaTime: seconds)
        // Mana regeneration disabled - use Pass spell to regain mana
    }

    /// Process movement step (called by scene animation system)
    func processMovementStep() -> HexCoord? {
        guard isMoving, !movementPath.isEmpty else {
            if isMoving {
                isMoving = false
                onMovementComplete?()
                onMovementComplete = nil
            }
            return nil
        }

        let nextPos = movementPath.removeFirst()
        position = nextPos
        onPositionChanged?(position)

        if movementPath.isEmpty {
            isMoving = false
            onMovementComplete?()
            onMovementComplete = nil
        }

        return nextPos
    }
}

// MARK: - Spell Cast Results

enum SpellCastResult {
    case success(effect: SpellEffect)
    case failure(SpellCastError)

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}

enum SpellCastError {
    case notInLoadout
    case insufficientMana
    case outOfRange
    case invalidTarget
}

enum SpellEffect {
    case none
    case damage(Int)
    case healing(Int)
    case activatedPassive
    case deactivatedPassive
    case areaEffect(center: HexCoord, radius: Int, damage: Int)
}
