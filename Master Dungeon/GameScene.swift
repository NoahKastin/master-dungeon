//
//  GameScene.swift
//  Master Dungeon
//
//  Main game scene with hex grid, player, and combat.
//

import SpriteKit
import GameplayKit

// MARK: - Interactive Element

/// Trackable interactive element in a challenge
struct InteractiveElement: Identifiable {
    let id = UUID()
    var position: HexCoord
    var type: InteractiveType
    var isCompleted: Bool = false

    enum InteractiveType {
        case target                          // Must be reached/touched
        case npc(currentHP: Int, maxHP: Int) // Must be healed to full
        case trigger(activatesId: String)    // Must be activated
        case obstacle(id: String, hp: Int)   // Destructible obstacle
        case darkness(dispelled: Bool)       // Must be illuminated
    }
}

class GameScene: SKScene {

    // MARK: - Constants
    static let visibleRange = 3  // Hexes visible in each direction
    private var hexSize: CGFloat = 40.0  // Calculated dynamically based on screen size

    // MARK: - Entities
    var entities = [GKEntity]()
    var graphs = [String: GKGraph]()

    private var player: Player!
    private var hexLayout: HexLayout!
    private var challengeGenerator: ChallengeGenerator!

    // MARK: - Visual Layers
    private var gridLayer: SKNode!
    private var entityLayer: SKNode!
    private var uiLayer: SKNode!
    private var effectLayer: SKNode!

    // MARK: - Hex Grid
    private var hexSprites: [HexCoord: HexSprite] = [:]
    private var blockedHexes: Set<HexCoord> = []

    // MARK: - Challenge Elements
    private var challengeSprites: [SKNode: HexCoord] = [:]  // Sprite -> World Position
    private var activeEnemies: [Enemy] = []
    private var enemySprites: [UUID: SKNode] = [:]

    // Interactive element tracking
    private var interactiveElements: [UUID: InteractiveElement] = [:]
    private var interactiveSprites: [UUID: SKNode] = [:]
    private var challengeTimer: TimeInterval = 0
    private var challengeTimeLimit: TimeInterval = 0
    private var playerDetected: Bool = false
    private var slainEnemyPositions: Set<HexCoord> = []

    // MARK: - Player Visual
    private var playerSprite: SKShapeNode!

    // MARK: - UI Elements
    private var manaBar: ManaBar?
    private var hpDisplay: HPDisplay?
    private var spellBar: SpellBar?
    private var objectiveLabel: SKLabelNode?
    private var backButton: SKNode?
    private var isGameOver: Bool = false

    // MARK: - State
    private var selectedSpell: Spell?
    private var highlightedHexes: [HexCoord] = []
    private var currentChallenge: Challenge?

    private var lastUpdateTime: TimeInterval = 0
    private var movementTimer: TimeInterval = 0
    private let movementInterval: TimeInterval = 0.15

    // MARK: - Scene Lifecycle

    override func sceneDidLoad() {
        lastUpdateTime = 0
    }

    override func didMove(to view: SKView) {
        setupScene()
        setupPlayer()
        setupUI()
        generateNewChallenge()
    }

    // MARK: - Setup

    private func setupScene() {
        backgroundColor = SKColor(white: 0.05, alpha: 1.0)

        // Create layers
        gridLayer = SKNode()
        gridLayer.zPosition = 0
        addChild(gridLayer)

        entityLayer = SKNode()
        entityLayer.zPosition = 10
        addChild(entityLayer)

        effectLayer = SKNode()
        effectLayer.zPosition = 20
        addChild(effectLayer)

        uiLayer = SKNode()
        uiLayer.zPosition = 100
        addChild(uiLayer)

        // Calculate hex size to fit in portrait mode
        // For flat-top hexes, width = 2 * size, height = sqrt(3) * size
        // Grid spans (2 * visibleRange + 1) hexes
        let gridDiameter = CGFloat(2 * GameScene.visibleRange + 1)
        let availableWidth = size.width - 40  // Leave some margin
        let availableHeight = size.height - 300  // Leave room for UI

        // For flat-top hexes: horizontal spacing = 1.5 * hexSize, vertical spacing = sqrt(3) * hexSize
        let maxHexSizeForWidth = availableWidth / (gridDiameter * 1.5)
        let maxHexSizeForHeight = availableHeight / (gridDiameter * sqrt(3.0))
        hexSize = min(maxHexSizeForWidth, maxHexSizeForHeight, 50.0)  // Cap at 50 for larger screens

        // Setup hex layout centered on screen (using flat-top orientation)
        hexLayout = HexLayout(hexSize: hexSize, origin: CGPoint(x: size.width / 2, y: size.height / 2), flatTop: true)

        // Challenge generator
        challengeGenerator = ChallengeGenerator()

        // Create visible hex grid
        createHexGrid()
    }

    private func createHexGrid() {
        let range = GameScene.visibleRange

        for q in -range...range {
            for r in max(-range, -q - range)...min(range, -q + range) {
                let localCoord = HexCoord(q: q, r: r)
                let hexSprite = HexSprite(localCoord: localCoord, layout: hexLayout)
                // Position is already set in HexSprite init based on localCoord
                gridLayer.addChild(hexSprite)
                hexSprites[localCoord] = hexSprite
            }
        }
        // Note: updateGridPosition() is called from setupPlayer() after player is initialized
    }

    private func setupPlayer() {
        player = Player()
        entities.append(player)

        // Create player visual
        playerSprite = SKShapeNode(circleOfRadius: hexSize * 0.4)
        playerSprite.fillColor = SKColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1.0)
        playerSprite.strokeColor = SKColor.white
        playerSprite.lineWidth = 2.0
        playerSprite.zPosition = 5
        entityLayer.addChild(playerSprite)

        player.sprite = playerSprite

        // Setup callbacks
        player.onPositionChanged = { [weak self] _ in
            self?.updateGridPosition()
        }

        player.onManaChanged = { [weak self] mana in
            self?.manaBar?.setMana(mana)
        }

        player.onHPChanged = { [weak self] hp in
            self?.hpDisplay?.setHP(hp)
        }

        // Position player sprite at center
        playerSprite.position = hexLayout.hexToScreen(.zero)

        // Setup player loadout from GameManager
        setupPlayerLoadout()

        // Now that player is initialized, update grid position
        updateGridPosition()
    }

    private func setupPlayerLoadout() {
        let loadout = GameManager.shared.currentLoadout

        // If no loadout selected (direct scene launch for testing), use defaults
        if loadout.spells.isEmpty {
            var testLoadout = SpellLoadout()
            if let magicMissile = SpellData.spell(byId: "magic-missile") {
                _ = testLoadout.addSpell(magicMissile)
            }
            if let cureWounds = SpellData.spell(byId: "cure-wounds") {
                _ = testLoadout.addSpell(cureWounds)
            }
            if let burningHands = SpellData.spell(byId: "burning-hands") {
                _ = testLoadout.addSpell(burningHands)
            }
            player.setLoadout(testLoadout)
        } else {
            player.setLoadout(loadout)
        }
    }

    private func setupUI() {
        let rawSafeArea = view?.safeAreaInsets ?? .zero
        // Use fallback values for Dynamic Island/notch iPhones when not yet available
        let safeTop = rawSafeArea.top > 0 ? rawSafeArea.top : 59
        let safeBottom = rawSafeArea.bottom > 0 ? rawSafeArea.bottom : 34

        // HP display (top left)
        let hp = HPDisplay()
        hp.position = CGPoint(x: 30, y: size.height - safeTop - 40)
        uiLayer.addChild(hp)
        hpDisplay = hp

        // Mana display (top center, between HP and back button)
        let mana = ManaDisplay()
        mana.position = CGPoint(x: size.width / 2, y: size.height - safeTop - 40)
        uiLayer.addChild(mana)
        manaBar = mana

        // Spell bar (bottom center) - only create if we have spells
        let spells = player.loadout.spells
        if !spells.isEmpty {
            let bar = SpellBar(spells: spells, slotSize: 60)
            bar.position = CGPoint(x: size.width / 2, y: safeBottom + 50)
            bar.onSpellSelected = { [weak self] spell in
                self?.selectSpell(spell)
            }
            uiLayer.addChild(bar)
            spellBar = bar
        }

        // Objective label (top center, below safe area) - supports multi-line wrapping
        let objective = SKLabelNode(fontNamed: "Cochin-Bold")
        objective.fontSize = 16
        objective.fontColor = SKColor(white: 0.9, alpha: 1.0)
        objective.position = CGPoint(x: size.width / 2, y: size.height - safeTop - 70)
        objective.horizontalAlignmentMode = .center
        objective.verticalAlignmentMode = .top
        objective.numberOfLines = 0  // Unlimited lines
        objective.preferredMaxLayoutWidth = size.width - 40  // Wrap with 20pt padding on each side
        objective.lineBreakMode = .byWordWrapping
        uiLayer.addChild(objective)
        objectiveLabel = objective

        // Back button (top right)
        let backContainer = SKNode()
        backContainer.position = CGPoint(x: size.width - 50, y: size.height - safeTop - 40)
        backContainer.zPosition = 100

        let backBg = SKShapeNode(rectOf: CGSize(width: 70, height: 30), cornerRadius: 8)
        backBg.fillColor = SKColor(white: 0.2, alpha: 0.8)
        backBg.strokeColor = SKColor(white: 0.4, alpha: 1.0)
        backBg.lineWidth = 1
        backContainer.addChild(backBg)

        let backLabel = SKLabelNode(fontNamed: "Cochin")
        backLabel.text = "← Back"
        backLabel.fontSize = 14
        backLabel.fontColor = .white
        backLabel.verticalAlignmentMode = .center
        backContainer.addChild(backLabel)

        uiLayer.addChild(backContainer)
        backButton = backContainer
    }

    // MARK: - Grid Management

    private func updateGridPosition() {
        // With local coordinates, layers stay at origin
        // Hex sprites are already positioned in screen space relative to player
        gridLayer.position = .zero
        entityLayer.position = .zero

        // Player sprite always at screen center (local coord 0,0)
        playerSprite.position = hexLayout.hexToScreen(.zero)

        // Update all enemy sprite positions relative to player
        for (id, sprite) in enemySprites {
            if let enemy = activeEnemies.first(where: { $0.id == id }) {
                let localCoord = enemy.position - player.position
                sprite.position = hexLayout.hexToScreen(localCoord)
            }
        }

        // Update all challenge sprite positions relative to player
        for (sprite, worldCoord) in challengeSprites {
            let localCoord = worldCoord - player.position
            sprite.position = hexLayout.hexToScreen(localCoord)
        }

        // Update hex visuals based on blocked state
        for (localCoord, sprite) in hexSprites {
            let worldCoord = localCoord + player.position
            sprite.isBlocked = blockedHexes.contains(worldCoord)
            sprite.updateAppearance()
        }
    }

    // MARK: - Spell Selection

    private func selectSpell(_ spell: Spell?) {
        // Clear previous highlights
        clearHighlights()

        selectedSpell = spell

        guard let spell = spell else { return }

        // For 0-range spells, auto-cast immediately at player's position
        if spell.range == 0 {
            let result = player.castSpell(spell, at: player.position)

            switch result {
            case .success(let effect):
                applySpellEffect(spell: spell, at: player.position, effect: effect)
                showSpellEffect(spell: spell, at: player.position, effect: effect)

                if !spell.isPassive {
                    selectedSpell = nil
                    spellBar?.deselectAll()
                }

            case .failure(let error):
                showCastError(error)
            }
            return
        }

        // Highlight valid target hexes
        let range = spell.range
        let targetHexes = player.position.hexesInRange(range)

        for coord in targetHexes {
            let localCoord = coord - player.position
            if let hexSprite = hexSprites[localCoord] {
                hexSprite.isHighlighted = true
                highlightedHexes.append(localCoord)
            }
        }
    }

    private func clearHighlights() {
        for coord in highlightedHexes {
            hexSprites[coord]?.isHighlighted = false
        }
        highlightedHexes.removeAll()
    }

    // MARK: - Challenge

    private func generateNewChallenge() {
        currentChallenge = challengeGenerator.generateChallenge(for: player.loadout)
        objectiveLabel?.text = currentChallenge?.description ?? "Explore!"

        // Clear old challenge sprites
        for (sprite, _) in challengeSprites {
            sprite.removeFromParent()
        }
        challengeSprites.removeAll()

        // Clear old interactive elements
        for (_, sprite) in interactiveSprites {
            sprite.removeFromParent()
        }
        interactiveElements.removeAll()
        interactiveSprites.removeAll()

        // Clear old enemies
        for enemy in activeEnemies {
            enemySprites[enemy.id]?.removeFromParent()
        }
        activeEnemies.removeAll()
        enemySprites.removeAll()
        slainEnemyPositions.removeAll()

        // Reset challenge state
        blockedHexes.removeAll()
        playerDetected = false
        challengeTimer = 0
        challengeTimeLimit = 0
        challengeHadEnemies = false  // Reset for new challenge

        if let challenge = currentChallenge {
            // Set up timed challenge timer
            if challenge.type == .timed {
                challengeTimeLimit = 15.0  // 15 second timer
            }

            for element in challenge.elements {
                // Challenge element positions are relative to player, convert to world coords
                let worldPosition = element.position + player.position

                if case .obstacle(let blocking, _) = element.type, blocking {
                    blockedHexes.insert(worldPosition)
                }

                // Create actual enemy entities for enemy elements
                if let enemy = EnemyFactory.createEnemy(from: element, at: worldPosition) {
                    print("ENEMY DEBUG: Spawning enemy at \(worldPosition), hp=\(enemy.hp)")
                    spawnEnemy(enemy)
                } else {
                    // Create interactive element tracking
                    if let interactive = createInteractiveElement(from: element, at: worldPosition) {
                        interactiveElements[interactive.id] = interactive
                        if case .target = interactive.type {
                            print("TARGET SPAWN DEBUG: Created target at \(worldPosition)")
                        }
                    }
                    // Render non-enemy elements visually
                    renderChallengeElementAt(element, worldPosition: worldPosition)
                }
            }
        }

        updateGridPosition()
    }

    private func createInteractiveElement(from element: ChallengeElement, at position: HexCoord) -> InteractiveElement? {
        switch element.type {
        case .target:
            return InteractiveElement(position: position, type: .target)

        case .npc(let needsHealing, _):
            if needsHealing {
                let currentHP = element.properties["hp"] as? Int ?? 1
                let maxHP = element.properties["maxHp"] as? Int ?? 3
                print("NPC SPAWN DEBUG: Creating NPC at \(position) with hp=\(currentHP), maxHp=\(maxHP), properties=\(element.properties)")
                return InteractiveElement(position: position, type: .npc(currentHP: currentHP, maxHP: maxHP))
            }
            return InteractiveElement(position: position, type: .target)  // Rescue target

        case .trigger(let activates):
            return InteractiveElement(position: position, type: .trigger(activatesId: activates))

        case .darkness:
            return InteractiveElement(position: position, type: .darkness(dispelled: false))

        case .obstacle(_, let destructible):
            if destructible {
                let hp = element.properties["hp"] as? Int ?? 3
                let id = element.properties["id"] as? String ?? UUID().uuidString
                return InteractiveElement(position: position, type: .obstacle(id: id, hp: hp))
            }
            return nil

        default:
            return nil
        }
    }

    private func spawnEnemy(_ enemy: Enemy) {
        activeEnemies.append(enemy)
        entities.append(enemy)
        challengeHadEnemies = true  // Mark that this challenge has enemies

        // Create visual sprite
        let isStealth = currentChallenge?.type == .stealth
        let sprite = createEnemySprite(hp: enemy.hp, behavior: enemy.behavior, isStealth: isStealth)
        // Position using local coordinates (relative to player)
        let localCoord = enemy.position - player.position
        sprite.position = hexLayout.hexToScreen(localCoord)
        sprite.zPosition = 4
        entityLayer.addChild(sprite)
        enemySprites[enemy.id] = sprite
        enemy.sprite = sprite

        // Setup callbacks
        enemy.onPositionChanged = { [weak self, weak enemy] newPos in
            guard let enemy = enemy else { return }
            self?.updateEnemyPosition(enemy)
        }

        enemy.onHPChanged = { [weak self, weak enemy] newHP in
            guard let enemy = enemy else { return }
            self?.updateEnemyHP(enemy, hp: newHP)
        }

        enemy.onDeath = { [weak self, weak enemy] in
            guard let enemy = enemy else { return }
            self?.handleEnemyDeath(enemy)
        }
    }

    private func updateEnemyPosition(_ enemy: Enemy) {
        guard let sprite = enemySprites[enemy.id] else { return }
        // Position using local coordinates (relative to player)
        let localCoord = enemy.position - player.position
        let targetPos = hexLayout.hexToScreen(localCoord)
        let move = SKAction.move(to: targetPos, duration: 0.2)
        move.timingMode = .easeInEaseOut
        sprite.run(move)
    }

    private func updateEnemyHP(_ enemy: Enemy, hp: Int) {
        guard let sprite = enemySprites[enemy.id] else { return }
        // Update HP label in sprite (sprite is already an SKNode container)
        if let hpLabel = sprite.children.compactMap({ $0 as? SKLabelNode }).first {
            // Stealth enemies keep their ∞ label
            if currentChallenge?.type == .stealth {
                return
            }
            hpLabel.text = enemy.isMerged ? "+\(hp)" : "\(hp)"
        }
    }

    private func handleEnemyDeath(_ enemy: Enemy) {
        guard let sprite = enemySprites[enemy.id] else { return }

        // Track slain enemy position for Create Undead
        slainEnemyPositions.insert(enemy.position)

        // Death animation
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        let scale = SKAction.scale(to: 0.5, duration: 0.3)
        let group = SKAction.group([fadeOut, scale])
        let remove = SKAction.removeFromParent()

        sprite.run(SKAction.sequence([group, remove]))

        // Remove from tracking
        enemySprites.removeValue(forKey: enemy.id)
        activeEnemies.removeAll { $0.id == enemy.id }
        entities.removeAll { ($0 as? Enemy)?.id == enemy.id }

        // Check if all enemies defeated
        checkChallengeCompletion()
    }

    private func enemyAt(_ coord: HexCoord) -> Enemy? {
        return activeEnemies.first { $0.position == coord && $0.isAlive }
    }

    private func renderChallengeElementAt(_ element: ChallengeElement, worldPosition: HexCoord) {
        // Convert world coordinate to local (relative to player), then to screen
        let localCoord = worldPosition - player.position
        let screenPos = hexLayout.hexToScreen(localCoord)
        let sprite: SKNode

        switch element.type {
        case .enemy, .invisibleEnemy:
            // Enemies are handled by spawnEnemy, not here
            return

        case .obstacle(_, let destructible):
            sprite = createObstacleSprite(destructible: destructible)

        case .hazard(let damage, _):
            sprite = createHazardSprite(damage: damage)

        case .darkness(let radius):
            sprite = createDarknessSprite(radius: radius)

        case .target:
            sprite = createTargetSprite()

        case .npc(let needsHealing, _):
            sprite = createNPCSprite(injured: needsHealing)

        case .trigger:
            sprite = createTriggerSprite()
        }

        sprite.position = screenPos
        sprite.zPosition = 3
        entityLayer.addChild(sprite)
        challengeSprites[sprite] = worldPosition

        // Link sprite to interactive element for animations
        for (id, interactiveElement) in interactiveElements {
            if interactiveElement.position == worldPosition {
                interactiveSprites[id] = sprite
                break
            }
        }
    }

    private func createEnemySprite(hp: Int, behavior: EnemyBehavior, isStealth: Bool = false) -> SKNode {
        let container = SKNode()

        // Enemy body - red triangle
        let size = hexSize * 0.35
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: size))
        path.addLine(to: CGPoint(x: -size * 0.866, y: -size * 0.5))
        path.addLine(to: CGPoint(x: size * 0.866, y: -size * 0.5))
        path.closeSubpath()

        let body = SKShapeNode(path: path)
        let fillColor: SKColor
        let strokeColor: SKColor
        if isStealth {
            fillColor = SKColor(red: 0.85, green: 0.65, blue: 0.1, alpha: 1.0)  // Gold for stealth
            strokeColor = SKColor(red: 0.6, green: 0.45, blue: 0.05, alpha: 1.0)
        } else {
            switch behavior {
            case .boss:
                fillColor = SKColor(red: 0.6, green: 0.1, blue: 0.1, alpha: 1.0)
                strokeColor = SKColor(red: 0.5, green: 0.1, blue: 0.1, alpha: 1.0)
            case .ranged:
                fillColor = SKColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 1.0)  // Blue for ranged
                strokeColor = SKColor(red: 0.1, green: 0.4, blue: 0.6, alpha: 1.0)
            case .healer:
                fillColor = SKColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 1.0)  // Green for healer
                strokeColor = SKColor(red: 0.1, green: 0.5, blue: 0.2, alpha: 1.0)
            default:
                fillColor = SKColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0)
                strokeColor = SKColor(red: 0.5, green: 0.1, blue: 0.1, alpha: 1.0)
            }
        }
        body.fillColor = fillColor
        body.strokeColor = strokeColor
        body.lineWidth = 2
        container.addChild(body)

        // HP indicator
        let hpLabel = SKLabelNode(fontNamed: "Cochin-Bold")
        hpLabel.text = isStealth ? "∞" : "\(hp)"
        hpLabel.fontSize = 12
        hpLabel.fontColor = .white
        hpLabel.verticalAlignmentMode = .center
        hpLabel.position = CGPoint(x: 0, y: -2)
        container.addChild(hpLabel)

        return container
    }

    private func createMergedEnemySprite(hp: Int, behavior: EnemyBehavior) -> SKNode {
        let container = SKNode()

        let size = hexSize * 0.45  // Larger than normal
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: size))
        path.addLine(to: CGPoint(x: -size * 0.866, y: -size * 0.5))
        path.addLine(to: CGPoint(x: size * 0.866, y: -size * 0.5))
        path.closeSubpath()

        let body = SKShapeNode(path: path)
        body.fillColor = behavior == .boss
            ? SKColor(red: 0.5, green: 0.1, blue: 0.5, alpha: 1.0)
            : SKColor(red: 0.7, green: 0.2, blue: 0.7, alpha: 1.0)
        body.strokeColor = SKColor(red: 0.4, green: 0.1, blue: 0.4, alpha: 1.0)
        body.lineWidth = 3
        container.addChild(body)

        let hpLabel = SKLabelNode(fontNamed: "Cochin-Bold")
        hpLabel.text = "+\(hp)"
        hpLabel.fontSize = 12
        hpLabel.fontColor = .white
        hpLabel.verticalAlignmentMode = .center
        hpLabel.position = CGPoint(x: 0, y: -2)
        hpLabel.name = "hpLabel"
        container.addChild(hpLabel)

        return container
    }

    private func createObstacleSprite(destructible: Bool) -> SKNode {
        let size = hexSize * 0.6
        let obstacle = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: 4)
        obstacle.fillColor = destructible ? SKColor(red: 0.5, green: 0.3, blue: 0.1, alpha: 1.0) : SKColor(white: 0.4, alpha: 1.0)
        obstacle.strokeColor = SKColor(white: 0.2, alpha: 1.0)
        obstacle.lineWidth = 2
        return obstacle
    }

    private func createHazardSprite(damage: Int) -> SKNode {
        let container = SKNode()
        let size = hexSize * 0.5

        // Pulsing hazard circle
        let hazard = SKShapeNode(circleOfRadius: size)
        hazard.fillColor = SKColor(red: 0.8, green: 0.4, blue: 0.0, alpha: 0.5)
        hazard.strokeColor = SKColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)
        hazard.lineWidth = 2
        container.addChild(hazard)

        // Pulse animation
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.2, duration: 0.5),
            SKAction.scale(to: 1.0, duration: 0.5)
        ])
        hazard.run(SKAction.repeatForever(pulse))

        return container
    }

    private func createDarknessSprite(radius: Int) -> SKNode {
        let size = hexSize * CGFloat(radius) * 1.5
        let darkness = SKShapeNode(circleOfRadius: size)
        darkness.fillColor = SKColor(white: 0.0, alpha: 0.7)
        darkness.strokeColor = SKColor(white: 0.1, alpha: 0.5)
        darkness.lineWidth = 2
        return darkness
    }

    private func createTargetSprite() -> SKNode {
        let container = SKNode()
        let size = hexSize * 0.3

        // Target rings
        for i in 0..<3 {
            let ring = SKShapeNode(circleOfRadius: size - CGFloat(i) * 6)
            ring.fillColor = i % 2 == 0 ? SKColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 0.8) : .clear
            ring.strokeColor = SKColor(red: 0.8, green: 0.6, blue: 0.0, alpha: 1.0)
            ring.lineWidth = 1
            container.addChild(ring)
        }

        return container
    }

    private func createNPCSprite(injured: Bool) -> SKNode {
        let container = SKNode()
        let size = hexSize * 0.35

        // NPC body - green circle
        let body = SKShapeNode(circleOfRadius: size)
        body.fillColor = injured ? SKColor(red: 0.4, green: 0.6, blue: 0.3, alpha: 1.0) : SKColor(red: 0.3, green: 0.8, blue: 0.4, alpha: 1.0)
        body.strokeColor = SKColor(red: 0.2, green: 0.5, blue: 0.2, alpha: 1.0)
        body.lineWidth = 2
        container.addChild(body)

        // Injured indicator
        if injured {
            let cross = SKLabelNode(fontNamed: "Cochin-Bold")
            cross.text = "+"
            cross.fontSize = 16
            cross.fontColor = .white
            cross.verticalAlignmentMode = .center
            container.addChild(cross)
        }

        return container
    }

    private func createTriggerSprite() -> SKNode {
        let size = hexSize * 0.25
        let trigger = SKShapeNode(rectOf: CGSize(width: size * 2, height: size), cornerRadius: 2)
        trigger.fillColor = SKColor(red: 0.6, green: 0.6, blue: 0.2, alpha: 1.0)
        trigger.strokeColor = SKColor(red: 0.4, green: 0.4, blue: 0.1, alpha: 1.0)
        trigger.lineWidth = 2
        return trigger
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }

        // If game over, any tap returns to spell selection
        if isGameOver {
            returnToSpellSelection()
            return
        }

        let sceneLocation = touch.location(in: self)

        // Check if touch is on back button
        if let back = backButton {
            let backLocation = touch.location(in: back)
            let backBounds = CGRect(x: -40, y: -20, width: 80, height: 40)
            if backBounds.contains(backLocation) {
                returnToSpellSelection()
                return
            }
        }

        // Check if touch is on UI (spell bar)
        if let bar = spellBar {
            // Convert touch to spellBar's local coordinate system
            let barLocation = touch.location(in: bar)
            if bar.contains(barLocation) {
                bar.handleTouch(at: barLocation)
                return
            }
        }

        // Convert touch to world hex coordinate
        // Use scene coordinates and calculate offset from screen center
        let offsetFromCenter = CGPoint(
            x: sceneLocation.x - size.width / 2,
            y: sceneLocation.y - size.height / 2
        )
        // Convert offset to local hex (relative to player at center)
        let pointForConversion = CGPoint(
            x: hexLayout.origin.x + offsetFromCenter.x,
            y: hexLayout.origin.y + offsetFromCenter.y
        )
        let localHexCoord = hexLayout.screenToHex(pointForConversion)
        let worldCoord = localHexCoord + player.position

        handleHexTap(worldCoord)
    }

    private func returnToSpellSelection() {
        let spellScene = SpellSelectionScene(size: size)
        spellScene.scaleMode = scaleMode
        let transition = SKTransition.fade(withDuration: 0.5)
        view?.presentScene(spellScene, transition: transition)
    }

    private func handleHexTap(_ coord: HexCoord) {
        if let spell = selectedSpell {
            // Cast selected spell at this hex
            let result = player.castSpell(spell, at: coord)

            switch result {
            case .success(let effect):
                // Apply actual game effects based on spell type
                applySpellEffect(spell: spell, at: coord, effect: effect)
                showSpellEffect(spell: spell, at: coord, effect: effect)

                // Deselect after casting (unless it's a passive)
                if !spell.isPassive {
                    selectSpell(nil)
                    spellBar?.deselectAll()
                }

            case .failure(let error):
                showCastError(error)
            }
        } else {
            // Move to this hex (check if not blocked by enemy)
            let enemyPositions = Set(activeEnemies.filter { $0.isAlive }.map { $0.position })
            let allBlocked = blockedHexes.union(enemyPositions)

            player.moveTo(coord, blocked: allBlocked) { [weak self] in
                guard let self = self else { return }
                // Check if player reached any targets
                self.checkInteractionsAtPosition(coord)
                self.checkChallengeCompletion()
            }
        }
    }

    private func applySpellEffect(spell: Spell, at coord: HexCoord, effect: SpellEffect) {
        // Handle pure movement spells (teleport to target) - only if not also offensive
        if spell.affectsMovement && !spell.isOffensive && coord != player.position {
            // Check if destination is valid (not blocked, not occupied by enemy)
            let enemyPositions = Set(activeEnemies.filter { $0.isAlive }.map { $0.position })
            if !blockedHexes.contains(coord) && !enemyPositions.contains(coord) {
                player.teleportTo(coord)
                showStatusText("Teleported!", at: CGPoint(x: size.width / 2, y: size.height / 2), color: .cyan)
            }
            return
        }

        var damageDealt = 0

        // Handle damage spells (including passive weapon spells like Flame Blade, Brand)
        if spell.isOffensive {
            if spell.isAoE {
                // Area of effect - damage all enemies in radius
                let radius = max(1, spell.range / 2)
                let affectedHexes = coord.hexesInRange(radius)

                for hex in affectedHexes {
                    if let enemy = enemyAt(hex) {
                        let damage = spell.rollOffense()
                        enemy.takeDamage(damage)
                        damageDealt += damage
                        let screenPos = worldToScreen(hex)
                        showDamageNumber(damage, at: screenPos)
                        showSpellFlash(color: .orange, at: screenPos)
                    }
                }
            } else {
                // Single target
                if let enemy = enemyAt(coord) {
                    if case .damage(let amount) = effect {
                        enemy.takeDamage(amount)
                        damageDealt = amount
                    } else {
                        // Fallback: roll offense if effect wasn't damage (for passive weapon spells)
                        let damage = spell.rollOffense()
                        enemy.takeDamage(damage)
                        damageDealt = damage
                        let screenPos = worldToScreen(coord)
                        showDamageNumber(damage, at: screenPos)
                        showSpellFlash(color: .red, at: screenPos)
                    }
                }
            }
        }

        // Handle healing spells (heal player or NPCs)
        // For spells like Vampiric Touch that are both offensive AND defensive,
        // heal based on damage dealt or defense roll
        if spell.isDefensive {
            if spell.isOffensive && damageDealt > 0 {
                // Life steal: heal for portion of damage dealt (like Vampiric Touch)
                let healing = spell.rollDefense()
                player.heal(healing)
                let playerScreenPos = CGPoint(x: size.width / 2, y: size.height / 2)
                showHealingNumber(healing, at: playerScreenPos)
            } else if !spell.isOffensive {
                // Pure healing spell - check for NPCs at target location first
                if let healAmount = healNPCAt(coord, amount: spell.rollDefense()) {
                    let screenPos = worldToScreen(coord)
                    showHealingNumber(healAmount, at: screenPos)
                    showStatusText("Healed!", at: screenPos, color: .green)
                } else {
                    // No NPC - heal player
                    if case .healing(let amount) = effect {
                        player.heal(amount)
                    }
                }
            }
        }

        // Handle crowd control
        if spell.causesParalysis {
            if let enemy = enemyAt(coord) {
                enemy.stun(turns: 2)
                let screenPos = worldToScreen(coord)
                showStatusText("Stunned!", at: screenPos, color: .yellow)
            }
        }

        // Handle summoning spells (Create Undead, etc.)
        if spell.affectsMovement && spell.exchangesKnowledge && spell.isDefensive {
            // Create Undead requires a corpse (slain enemy)
            if slainEnemyPositions.contains(coord) {
                spawnSummon(at: coord, spell: spell)
                slainEnemyPositions.remove(coord)  // Consume the corpse
            } else {
                // No corpse at target location
                let screenPos = worldToScreen(coord)
                showStatusText("No corpse!", at: screenPos, color: .gray)
            }
        }

        // Handle object-affecting spells (triggers, moveable obstacles)
        if spell.affectsObjects {
            if activateTriggerAt(coord) {
                let screenPos = worldToScreen(coord)
                showSpellFlash(color: .purple, at: screenPos)
                showStatusText("Activated!", at: screenPos, color: .purple)
            } else {
                let screenPos = worldToScreen(coord)
                showSpellFlash(color: .purple, at: screenPos)
            }
        }

        // Handle illumination spells (dispel darkness)
        if spell.producesLight {
            if dispelDarknessAt(coord) {
                let screenPos = worldToScreen(coord)
                showSpellFlash(color: .yellow, at: screenPos)
                showStatusText("Light!", at: screenPos, color: .yellow)
            }
        }

        // Handle damage to destructible obstacles
        if spell.isOffensive && damageDealt == 0 {
            // No enemy was hit - check for destructible obstacles
            if damageObstacleAt(coord, damage: spell.rollOffense()) {
                let screenPos = worldToScreen(coord)
                showSpellFlash(color: .orange, at: screenPos)
            }
        }

        // Check for challenge completion after spell effects
        checkChallengeCompletion()
    }

    private func spawnSummon(at coord: HexCoord, spell: Spell) {
        // Create a visual indicator for the summon
        let summonSprite = SKShapeNode(circleOfRadius: hexSize * 0.3)
        summonSprite.fillColor = SKColor(red: 0.5, green: 0.8, blue: 0.5, alpha: 0.8)
        summonSprite.strokeColor = SKColor(red: 0.3, green: 0.6, blue: 0.3, alpha: 1.0)
        summonSprite.lineWidth = 2
        // Convert world coordinate to local, then to screen
        let localCoord = coord - player.position
        summonSprite.position = hexLayout.hexToScreen(localCoord)
        summonSprite.zPosition = 4
        entityLayer.addChild(summonSprite)
        challengeSprites[summonSprite] = coord  // Track world position

        // Add the summon position to blocked hexes (enemies can't move through)
        blockedHexes.insert(coord)

        let screenPos = worldToScreen(coord)
        showStatusText("Summoned!", at: screenPos, color: .green)
    }

    // MARK: - Interactive Element Handling

    private func checkInteractionsAtPosition(_ position: HexCoord) {
        // Check for targets and other elements at or adjacent to player
        for (id, var element) in interactiveElements {
            let distance = position.distance(to: element.position)
            if distance <= 1 {  // On or adjacent to element
                switch element.type {
                case .target:
                    if !element.isCompleted {
                        element.isCompleted = true
                        interactiveElements[id] = element
                        markInteractiveCompleted(id: id, message: "Target!")
                    }
                default:
                    break
                }
            }
        }

        // Check for stealth detection
        if currentChallenge?.type == .stealth {
            for enemy in activeEnemies where enemy.isAlive {
                if position.distance(to: enemy.position) <= 2 {
                    playerDetected = true
                    showStatusText("Detected!", at: worldToScreen(enemy.position), color: .red)
                }
            }
        }
    }

    private func healNPCAt(_ position: HexCoord, amount: Int) -> Int? {
        print("HEAL DEBUG: Trying to heal at \(position), amount=\(amount)")
        for (id, var element) in interactiveElements {
            print("HEAL DEBUG:   Checking element at \(element.position), type=\(element.type)")
            if element.position == position {
                if case .npc(var currentHP, let maxHP) = element.type {
                    let healAmount = min(amount, maxHP - currentHP)
                    print("HEAL DEBUG:   Found NPC! currentHP=\(currentHP), maxHP=\(maxHP), healAmount=\(healAmount)")
                    if healAmount > 0 {
                        currentHP += healAmount
                        element.type = .npc(currentHP: currentHP, maxHP: maxHP)
                        interactiveElements[id] = element

                        // Visual feedback
                        if currentHP >= maxHP {
                            print("HEAL DEBUG:   NPC fully healed!")
                            markInteractiveCompleted(id: id, message: "Rescued!")
                        }
                        return healAmount
                    }
                }
            }
        }
        print("HEAL DEBUG: No NPC found at position")
        return nil
    }

    private func activateTriggerAt(_ position: HexCoord) -> Bool {
        for (id, var element) in interactiveElements {
            if element.position == position {
                if case .trigger(let activatesId) = element.type {
                    if !element.isCompleted {
                        element.isCompleted = true
                        interactiveElements[id] = element

                        // Find and activate the linked element
                        activateLinkedElement(id: activatesId)
                        markInteractiveCompleted(id: id, message: "Triggered!")
                        return true
                    }
                }
            }
        }
        return false
    }

    private func activateLinkedElement(id linkedId: String) {
        // Remove blocking obstacle with matching ID
        for (id, element) in interactiveElements {
            if case .obstacle(let obstId, _) = element.type, obstId == linkedId {
                // Remove the obstacle from blocked hexes
                blockedHexes.remove(element.position)

                // Remove visual
                if let sprite = interactiveSprites[id] {
                    let fadeOut = SKAction.sequence([
                        SKAction.fadeOut(withDuration: 0.3),
                        SKAction.removeFromParent()
                    ])
                    sprite.run(fadeOut)
                }
                interactiveElements.removeValue(forKey: id)
                showStatusText("Door opened!", at: worldToScreen(element.position), color: .cyan)
            }
        }
    }

    private func dispelDarknessAt(_ position: HexCoord) -> Bool {
        for (id, var element) in interactiveElements {
            // Dispel darkness within range of the spell
            if position.distance(to: element.position) <= 3 {
                if case .darkness(let dispelled) = element.type, !dispelled {
                    element.type = .darkness(dispelled: true)
                    element.isCompleted = true
                    interactiveElements[id] = element

                    // Remove visual
                    if let sprite = interactiveSprites[id] {
                        let fadeOut = SKAction.sequence([
                            SKAction.fadeOut(withDuration: 0.5),
                            SKAction.removeFromParent()
                        ])
                        sprite.run(fadeOut)
                    }
                    return true
                }
            }
        }
        return false
    }

    private func damageObstacleAt(_ position: HexCoord, damage: Int) -> Bool {
        for (id, var element) in interactiveElements {
            if element.position == position {
                if case .obstacle(let obstId, var hp) = element.type {
                    hp -= damage
                    if hp <= 0 {
                        // Obstacle destroyed
                        blockedHexes.remove(position)
                        interactiveElements.removeValue(forKey: id)
                        if let sprite = interactiveSprites[id] {
                            let destroy = SKAction.sequence([
                                SKAction.scale(to: 1.3, duration: 0.1),
                                SKAction.fadeOut(withDuration: 0.2),
                                SKAction.removeFromParent()
                            ])
                            sprite.run(destroy)
                        }
                        showStatusText("Destroyed!", at: worldToScreen(position), color: .orange)
                    } else {
                        element.type = .obstacle(id: obstId, hp: hp)
                        interactiveElements[id] = element
                        showDamageNumber(damage, at: worldToScreen(position))
                    }
                    return true
                }
            }
        }
        return false
    }

    private func markInteractiveCompleted(id: UUID, message: String) {
        if let element = interactiveElements[id], let sprite = interactiveSprites[id] {
            let screenPos = worldToScreen(element.position)
            showStatusText(message, at: screenPos, color: .yellow)

            let flash = SKAction.sequence([
                SKAction.scale(to: 1.3, duration: 0.1),
                SKAction.scale(to: 1.0, duration: 0.1),
                SKAction.fadeAlpha(to: 0.5, duration: 0.2)
            ])
            sprite.run(flash)
        }
    }

    private func worldToScreen(_ worldCoord: HexCoord) -> CGPoint {
        // Convert world coordinate to local (relative to player), then to screen
        let localCoord = worldCoord - player.position
        return hexLayout.hexToScreen(localCoord)
    }

    private func showSpellEffect(spell: Spell, at coord: HexCoord, effect: SpellEffect) {
        let worldScreenPos = worldToScreen(coord)

        switch effect {
        case .damage(let amount):
            // Only show if not AoE (AoE shows its own numbers in applySpellEffect)
            if !spell.isAoE {
                showDamageNumber(amount, at: worldScreenPos)
            }
            showSpellFlash(color: .red, at: worldScreenPos)

        case .healing(let amount):
            // Show healing at player position
            let playerScreenPos = CGPoint(x: size.width / 2, y: size.height / 2)
            showHealingNumber(amount, at: playerScreenPos)
            showSpellFlash(color: .green, at: playerScreenPos)

        case .activatedPassive:
            let playerScreenPos = CGPoint(x: size.width / 2, y: size.height / 2)
            showStatusText("Activated!", at: playerScreenPos, color: .cyan)

        case .deactivatedPassive:
            let playerScreenPos = CGPoint(x: size.width / 2, y: size.height / 2)
            showStatusText("Deactivated", at: playerScreenPos, color: .gray)

        case .areaEffect(let center, let radius, _):
            let affectedHexes = center.hexesInRange(radius)
            for hex in affectedHexes {
                showSpellFlash(color: .orange, at: worldToScreen(hex))
            }

        default:
            showSpellFlash(color: .white, at: worldScreenPos)
        }

        // Trigger enemy turns after casting a non-passive spell
        if !spell.isPassive {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.processEnemyTurns()
            }
        }
    }

    private func showDamageNumber(_ damage: Int, at position: CGPoint) {
        let label = SKLabelNode(fontNamed: "Cochin-Bold")
        label.text = "-\(damage)"
        label.fontSize = 24
        label.fontColor = .red
        label.position = position
        label.zPosition = 50
        effectLayer.addChild(label)

        let moveUp = SKAction.moveBy(x: 0, y: 50, duration: 0.8)
        let fadeOut = SKAction.fadeOut(withDuration: 0.8)
        let group = SKAction.group([moveUp, fadeOut])
        let remove = SKAction.removeFromParent()

        label.run(SKAction.sequence([group, remove]))
    }

    private func showHealingNumber(_ healing: Int, at position: CGPoint) {
        let label = SKLabelNode(fontNamed: "Cochin-Bold")
        label.text = "+\(healing)"
        label.fontSize = 24
        label.fontColor = .green
        label.position = position
        label.zPosition = 50
        effectLayer.addChild(label)

        let moveUp = SKAction.moveBy(x: 0, y: 50, duration: 0.8)
        let fadeOut = SKAction.fadeOut(withDuration: 0.8)
        let group = SKAction.group([moveUp, fadeOut])
        let remove = SKAction.removeFromParent()

        label.run(SKAction.sequence([group, remove]))
    }

    private func showSpellFlash(color: SKColor, at position: CGPoint) {
        let flash = SKShapeNode(circleOfRadius: 20)
        flash.fillColor = color
        flash.strokeColor = .clear
        flash.alpha = 0.8
        flash.position = position
        flash.zPosition = 45
        effectLayer.addChild(flash)

        let scale = SKAction.scale(to: 2.0, duration: 0.3)
        let fade = SKAction.fadeOut(withDuration: 0.3)
        let group = SKAction.group([scale, fade])
        let remove = SKAction.removeFromParent()

        flash.run(SKAction.sequence([group, remove]))
    }

    private func showStatusText(_ text: String, at position: CGPoint, color: SKColor) {
        let label = SKLabelNode(fontNamed: "Cochin")
        label.text = text
        label.fontSize = 16
        label.fontColor = color
        label.position = position
        label.zPosition = 50
        effectLayer.addChild(label)

        let moveUp = SKAction.moveBy(x: 0, y: 30, duration: 0.6)
        let fadeOut = SKAction.fadeOut(withDuration: 0.6)
        let group = SKAction.group([moveUp, fadeOut])
        let remove = SKAction.removeFromParent()

        label.run(SKAction.sequence([group, remove]))
    }

    private func showCastError(_ error: SpellCastError) {
        let message: String
        switch error {
        case .insufficientMana:
            message = "Not enough mana!"
        case .outOfRange:
            message = "Out of range!"
        case .notInLoadout:
            message = "Spell not available!"
        case .invalidTarget:
            message = "Invalid target!"
        }

        let label = SKLabelNode(fontNamed: "Cochin-Bold")
        label.text = message
        label.fontSize = 20
        label.fontColor = .red
        label.position = CGPoint(x: size.width / 2, y: size.height / 2 + 100)
        label.zPosition = 100
        uiLayer.addChild(label)

        let wait = SKAction.wait(forDuration: 1.0)
        let fadeOut = SKAction.fadeOut(withDuration: 0.5)
        let remove = SKAction.removeFromParent()

        label.run(SKAction.sequence([wait, fadeOut, remove]))
    }

    private var challengeCompleted: Bool = false
    private var challengeHadEnemies: Bool = false  // Track if enemies were spawned for this challenge

    private func checkChallengeCompletion() {
        guard let challenge = currentChallenge, !challengeCompleted else { return }

        var isComplete = false

        switch challenge.type {
        case .combat:
            // Combat challenges complete when all enemies are defeated
            // Use challengeHadEnemies flag since dead enemies are removed from activeEnemies
            let aliveEnemies = activeEnemies.filter { $0.isAlive }
            print("COMBAT DEBUG: activeEnemies=\(activeEnemies.count), aliveEnemies=\(aliveEnemies.count), hadEnemies=\(challengeHadEnemies)")
            isComplete = challengeHadEnemies && aliveEnemies.isEmpty

        case .survival:
            // Survival challenges complete when all enemies are defeated
            // (player must survive the onslaught)
            let aliveEnemies = activeEnemies.filter { $0.isAlive }
            isComplete = challengeHadEnemies && aliveEnemies.isEmpty

        case .obstacle:
            // Obstacle challenges complete when player reaches all target elements
            isComplete = checkAllTargetsReached()

        case .stealth:
            // Stealth challenges complete when player reaches target without detection
            // Fail if player was detected — lose 1 HP and advance
            if playerDetected {
                showStatusText("Detected!", at: CGPoint(x: size.width / 2, y: size.height / 2), color: .red)
                player.takeDamage(1)
                challengeCompleted = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    self?.challengeCompleted = false
                    self?.generateNewChallenge()
                }
                return
            } else {
                isComplete = checkAllTargetsReached()
            }

        case .rescue:
            // Rescue challenges complete when all NPCs are healed/saved
            isComplete = checkAllNPCsRescued()

        case .timed:
            // Timed challenges fail if time runs out
            if challengeTimeLimit > 0 && challengeTimer >= challengeTimeLimit {
                showStatusText("Time's up!", at: CGPoint(x: size.width / 2, y: size.height / 2), color: .red)
                player.takeDamage(1)  // Penalty for failure
                challengeCompleted = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    self?.challengeCompleted = false
                    self?.generateNewChallenge()
                }
                return
            }
            isComplete = checkAllTargetsReached()

        case .puzzle:
            // Puzzles complete when all darkness is dispelled and all triggers activated
            isComplete = checkPuzzleSolved()
        }

        if isComplete {
            challengeCompleted = true
            objectiveLabel?.text = "Victory!"

            let wait = SKAction.wait(forDuration: 1.5)
            let generate = SKAction.run { [weak self] in
                self?.challengeCompleted = false
                self?.generateNewChallenge()
            }
            run(SKAction.sequence([wait, generate]))
        }
    }

    private func checkAllTargetsReached() -> Bool {
        var targetCount = 0
        for (_, element) in interactiveElements {
            if case .target = element.type {
                targetCount += 1
                // Check if player is on or adjacent to target
                if player.position == element.position || player.position.distance(to: element.position) <= 1 {
                    continue  // Target reached
                }
                print("TARGET DEBUG: Target at \(element.position), player at \(player.position), distance=\(player.position.distance(to: element.position))")
                return false  // Target not reached
            }
        }
        print("TARGET DEBUG: Total targets=\(targetCount), all reached=\(targetCount > 0)")
        // Only complete if there was at least one target
        return targetCount > 0
    }

    private func checkAllNPCsRescued() -> Bool {
        print("RESCUE DEBUG: Checking all NPCs rescued")
        for (_, element) in interactiveElements {
            if case .npc(let currentHP, let maxHP) = element.type {
                print("RESCUE DEBUG:   NPC at \(element.position): \(currentHP)/\(maxHP)")
                if currentHP < maxHP {
                    print("RESCUE DEBUG:   -> Not healed, returning false")
                    return false  // NPC not fully healed
                }
            }
            if case .target = element.type, !element.isCompleted {
                print("RESCUE DEBUG:   -> Target not completed, returning false")
                return false  // Rescue target not reached
            }
        }
        // Also check if there are still enemies threatening NPCs
        let aliveEnemies = activeEnemies.filter { $0.isAlive }
        print("RESCUE DEBUG:   Alive enemies=\(aliveEnemies.count)")
        print("RESCUE DEBUG:   -> Returning \(aliveEnemies.isEmpty)")
        return aliveEnemies.isEmpty
    }

    private func checkPuzzleSolved() -> Bool {
        for (_, element) in interactiveElements {
            switch element.type {
            case .darkness(let dispelled):
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

    private func markTargetReached(at position: HexCoord) {
        for (id, var element) in interactiveElements {
            if element.position == position {
                element.isCompleted = true
                interactiveElements[id] = element

                // Visual feedback
                if let sprite = interactiveSprites[id] {
                    let flash = SKAction.sequence([
                        SKAction.scale(to: 1.3, duration: 0.1),
                        SKAction.scale(to: 0, duration: 0.2),
                        SKAction.removeFromParent()
                    ])
                    sprite.run(flash)
                }

                showStatusText("Target!", at: worldToScreen(position), color: .yellow)
            }
        }
    }

    private func processEnemyTurns() {
        // Don't include player position in blocked - enemies need to path toward player
        // Only block other enemy positions and obstacles
        let enemyPositions = Set(activeEnemies.filter { $0.isAlive }.map { $0.position })
        let pathBlocked = blockedHexes.union(enemyPositions)

        for enemy in activeEnemies where enemy.isAlive {
            // Recalculate blocked for each enemy (exclude self)
            let blockedForThisEnemy = pathBlocked.subtracting([enemy.position])
            let action = enemy.takeTurn(playerPosition: player.position, blocked: blockedForThisEnemy)

            switch action {
            case .attack(_, let damage):
                // Enemy attacks player
                player.takeDamage(damage)
                checkPlayerDeath()
                let screenPos = CGPoint(x: size.width / 2, y: size.height / 2)
                showDamageNumber(damage, at: screenPos)
                showSpellFlash(color: .red, at: screenPos)

            case .move:
                // Movement already happened in takeTurn via enemy.moveTo
                // The onPositionChanged callback updates the sprite position
                break

            case .specialAttack(let type, let center, let radius, let damage):
                // Handle special attacks
                if type == .areaSlam {
                    let affectedHexes = center.hexesInRange(radius)
                    if affectedHexes.contains(player.position) {
                        player.takeDamage(damage)
                        checkPlayerDeath()
                        let screenPos = CGPoint(x: size.width / 2, y: size.height / 2)
                        showDamageNumber(damage, at: screenPos)
                    }
                }

            case .healAlly(let amount, let range):
                // Find most damaged ally within range
                let allies = activeEnemies.filter { ally in
                    ally.id != enemy.id &&
                    ally.isAlive &&
                    ally.hp < ally.maxHP &&
                    enemy.position.distance(to: ally.position) <= range
                }
                if let target = allies.min(by: { $0.hp < $1.hp }) {
                    target.heal(amount)
                    let screenPos = worldToScreen(target.position)
                    showHealingNumber(amount, at: screenPos)
                    showSpellFlash(color: .green, at: screenPos)
                }

            case .stunned:
                // Enemy is stunned, show indicator
                if let sprite = enemySprites[enemy.id] {
                    let worldPos = CGPoint(x: sprite.position.x + entityLayer.position.x,
                                          y: sprite.position.y + entityLayer.position.y)
                    showStatusText("...", at: worldPos, color: .gray)
                }

            case .wait:
                break
            }
        }

        checkAndMergeEnemies()
    }

    private func checkAndMergeEnemies() {
        var enemiesByPosition: [HexCoord: [Enemy]] = [:]
        for enemy in activeEnemies where enemy.isAlive {
            enemiesByPosition[enemy.position, default: []].append(enemy)
        }

        for (position, enemies) in enemiesByPosition where enemies.count >= 2 {
            performMerge(enemies: enemies, at: position)
        }
    }

    private func performMerge(enemies: [Enemy], at position: HexCoord) {
        guard let mergedEnemy = Enemy.merge(enemies, at: position) else { return }

        // Remove old enemies
        for enemy in enemies {
            if let sprite = enemySprites[enemy.id] {
                sprite.removeFromParent()
            }
            enemySprites.removeValue(forKey: enemy.id)
            activeEnemies.removeAll { $0.id == enemy.id }
            entities.removeAll { ($0 as? Enemy)?.id == enemy.id }
        }

        // Spawn merged enemy
        spawnMergedEnemy(mergedEnemy)
    }

    private func spawnMergedEnemy(_ enemy: Enemy) {
        activeEnemies.append(enemy)
        entities.append(enemy)

        let sprite = createMergedEnemySprite(hp: enemy.hp, behavior: enemy.behavior)
        let localCoord = enemy.position - player.position
        sprite.position = hexLayout.hexToScreen(localCoord)
        sprite.zPosition = 4
        entityLayer.addChild(sprite)
        enemySprites[enemy.id] = sprite
        enemy.sprite = sprite

        // Setup callbacks
        enemy.onPositionChanged = { [weak self, weak enemy] _ in
            guard let enemy = enemy else { return }
            self?.updateEnemyPosition(enemy)
        }
        enemy.onHPChanged = { [weak self, weak enemy] newHP in
            guard let enemy = enemy else { return }
            self?.updateEnemyHP(enemy, hp: newHP)
        }
        enemy.onDeath = { [weak self, weak enemy] in
            guard let enemy = enemy else { return }
            self?.handleEnemyDeath(enemy)
        }
    }

    private func checkPlayerDeath() {
        if !player.isAlive {
            showGameOver()
        }
    }

    private func showGameOver() {
        isGameOver = true

        // Show game over overlay
        let overlay = SKShapeNode(rectOf: size)
        overlay.fillColor = SKColor(white: 0.0, alpha: 0.7)
        overlay.strokeColor = .clear
        overlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.zPosition = 200
        addChild(overlay)

        let gameOverLabel = SKLabelNode(fontNamed: "Cochin-Bold")
        gameOverLabel.text = "Game Over"
        gameOverLabel.fontSize = 36
        gameOverLabel.fontColor = .red
        gameOverLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 40)
        gameOverLabel.zPosition = 201
        addChild(gameOverLabel)

        let restartLabel = SKLabelNode(fontNamed: "Cochin")
        restartLabel.text = "Tap to return to spell selection"
        restartLabel.fontSize = 18
        restartLabel.fontColor = .white
        restartLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 20)
        restartLabel.zPosition = 201
        addChild(restartLabel)
    }

    // MARK: - Update Loop

    private var enemyTurnTimer: TimeInterval = 0
    private let enemyTurnInterval: TimeInterval = 1.0
    private var playerWasMoving: Bool = false

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
        }

        let dt = currentTime - lastUpdateTime

        // Update entities
        for entity in entities {
            entity.update(deltaTime: dt)
        }

        // Process player movement animation
        movementTimer += dt
        if movementTimer >= movementInterval {
            movementTimer = 0
            if let _ = player.processMovementStep() {
                // Position updates happen via onPositionChanged callback
                // which calls updateGridPosition()
            }
        }

        // Track when player stops moving to trigger enemy turns
        if playerWasMoving && !player.isMoving {
            playerWasMoving = false
            // Give enemies a turn after player moves
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.processEnemyTurns()
            }
        }
        if player.isMoving {
            playerWasMoving = true
        }

        // Update spell bar (for mana costs, etc.)
        spellBar?.updateSpellStates(currentMana: player.mana)

        // Update challenge timer for timed challenges
        if currentChallenge?.type == .timed && challengeTimeLimit > 0 && !challengeCompleted {
            challengeTimer += dt
            let remaining = max(0, challengeTimeLimit - challengeTimer)
            objectiveLabel?.text = String(format: "Time: %.1fs", remaining)
            checkChallengeCompletion()
        }

        lastUpdateTime = currentTime
    }
}
