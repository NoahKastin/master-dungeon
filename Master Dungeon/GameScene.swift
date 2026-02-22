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
        case darkness(radius: Int, dispelled: Bool)  // Must be illuminated
    }
}

class GameScene: SKScene {

    // MARK: - Constants
    static var visibleRange: Int {
        switch GameManager.shared.gameMode {
        case .easy: return 1
        case .medium: return 2
        case .rainbow: return RainbowConfig.visibleRange
        case .team: return 3
        default: return 3
        }
    }
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

    // MARK: - Player Visual
    private var playerSprite: SKShapeNode!

    // MARK: - UI Elements
    private var manaBar: ManaBar?
    private var hpDisplay: HPDisplay?
    private var spellBar: SpellBar?
    private var objectiveLabel: SKLabelNode?
    private var scoreLabel: SKLabelNode?
    private var backButton: SKNode?
    private var isGameOver: Bool = false

    // MARK: - Blitz Timer
    private var blitzTimer: TimeInterval = 0
    private var blitzTimerLabel: SKLabelNode?
    private var isBlitz: Bool { GameManager.shared.gameMode == .blitz }

    // MARK: - Rainbow Mode
    private var isRainbow: Bool { GameManager.shared.gameMode == .rainbow }

    // MARK: - Team Mode
    private var isTeam: Bool { GameManager.shared.gameMode == .team }

    // Player colors
    static let teamColors: [SKColor] = [
        SKColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1.0),  // Blue
        SKColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0),  // Red
        SKColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1.0),  // Green
        SKColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0),  // Gold
    ]

    // Challenge offsets: each player's challenge spawns at a different compass point
    static let teamChallengeOffsets: [HexCoord] = [
        HexCoord(q:  0, r: -4),  // Player 0: north
        HexCoord(q:  4, r:  0),  // Player 1: east
        HexCoord(q:  0, r:  4),  // Player 2: south
        HexCoord(q: -4, r:  0),  // Player 3: west
    ]

    struct TeamMemberState {
        let index: Int
        let color: SKColor
        var hp: Int
        var mana: Int
        var worldPosition: HexCoord
        var isDowned: Bool
        var loadout: SpellLoadout
        var challengeCompleted: Bool
        var challengeDescription: String  // For per-player objective label
        var sprite: SKShapeNode?
        var arrowNode: SKNode?
    }

    private var teamMembers: [TeamMemberState] = []
    private var activeTeamIndex: Int = 0
    private var teamActedThisRound: Set<Int> = []
    private var teamChallengeHadEnemies: [Int: Bool] = [:]  // Per-player enemy tracking
    private var isActingThisTurn: Bool = false               // Blocks double-actions
    private var teamTurnOverlay: SKNode?
    private var endTurnButton: SKNode?
    private var teamStatusLabel: SKLabelNode?
    private var lavaColumn: Int = Int.min
    private var turnsSinceLavaAdvance: Int = 0
    private var nextZoneColumn: Int = 0
    private var droppedPotions: [HexCoord: PotionColor] = [:]
    private var potionSprites: [HexCoord: SKNode] = [:]
    private var potionBar: PotionBar?
    private var selectedPotion: PotionColor?
    private var zonesCleared: Int = 0
    private var rainbowZoneHadEnemies: Bool = false

    // MARK: - State
    private var selectedSpell: Spell?
    private var highlightedHexes: [HexCoord] = []
    private var currentChallenge: Challenge?

    private var lastUpdateTime: TimeInterval = 0
    private var movementTimer: TimeInterval = 0
    private let movementInterval: TimeInterval = 0.15

    // MARK: - Long-press Spell Tooltip
    private var spellBarTouchPoint: CGPoint?
    private var longPressWork: DispatchWorkItem?
    private var spellTooltip: SKNode?

    // MARK: - Scene Lifecycle

    override func sceneDidLoad() {
        lastUpdateTime = 0
    }

    override func didMove(to view: SKView) {
        setupScene()
        setupPlayer()
        setupUI()

        if isRainbow {
            setupRainbow()
        } else if isTeam {
            setupTeamPlayers()
            generateTeamChallenges()
            showTeamTurnOverlay(for: 0)
        } else {
            generateNewChallenge()
        }
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

        // HP display (top left) — replaced by blitz timer in Blitz mode
        if isBlitz {
            blitzTimer = BlitzConfig.startTime
            let timerLabel = SKLabelNode(fontNamed: "Cochin-Bold")
            timerLabel.fontSize = 22
            timerLabel.fontColor = SKColor(red: 0.2, green: 0.95, blue: 0.8, alpha: 1.0)
            timerLabel.horizontalAlignmentMode = .left
            timerLabel.verticalAlignmentMode = .center
            timerLabel.position = CGPoint(x: 16, y: size.height - safeTop - 40)
            timerLabel.zPosition = 100
            timerLabel.text = String(format: "%.1fs", blitzTimer)
            uiLayer.addChild(timerLabel)
            blitzTimerLabel = timerLabel
        } else {
            let hp = HPDisplay()
            hp.position = CGPoint(x: 30, y: size.height - safeTop - 40)
            uiLayer.addChild(hp)
            hpDisplay = hp
        }

        // Mana display (top center, between HP and back button) — hidden in modes without mana
        if GameManager.shared.gameMode.hasMana {
            let mana = ManaDisplay()
            mana.position = CGPoint(x: size.width / 2, y: size.height - safeTop - 40)
            uiLayer.addChild(mana)
            manaBar = mana
        }

        // Bottom bar — PotionBar in rainbow, SpellBar otherwise
        // Team mode: spell bar is built per-player in loadTeamPlayerState (loadout changes each turn)
        if isRainbow {
            let bar = PotionBar()
            bar.position = CGPoint(x: size.width / 2, y: safeBottom + 50)
            bar.onPotionSelected = { [weak self] color in
                self?.selectPotion(color)
            }
            uiLayer.addChild(bar)
            potionBar = bar
        } else if !isTeam {
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
        }

        // Objective label (top center, below safe area) - supports multi-line wrapping
        let objective = SKLabelNode(fontNamed: "Cochin-Bold")
        objective.fontSize = 16
        objective.fontColor = SKColor(white: 0.9, alpha: 1.0)
        objective.position = CGPoint(x: size.width / 2, y: size.height - safeTop - 70)
        objective.horizontalAlignmentMode = .center
        objective.verticalAlignmentMode = .top
        // Team mode: 1 line only — objective sits just above ally HP status label
        objective.numberOfLines = isTeam ? 1 : 0
        objective.preferredMaxLayoutWidth = size.width - 40  // Wrap with 20pt padding on each side
        objective.lineBreakMode = isTeam ? .byTruncatingTail : .byWordWrapping
        uiLayer.addChild(objective)
        objectiveLabel = objective

        // Score counter (top right, left of back button)
        let score = SKLabelNode(fontNamed: "Cochin-Bold")
        score.fontSize = 18
        score.fontColor = SKColor(red: 0.9, green: 0.85, blue: 0.5, alpha: 1.0)
        score.horizontalAlignmentMode = .right
        score.verticalAlignmentMode = .center
        score.position = CGPoint(x: size.width - 95, y: size.height - safeTop - 40)
        score.zPosition = 100
        score.text = "Score: 0"
        uiLayer.addChild(score)
        scoreLabel = score

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

        // Update hex visuals based on blocked/lava state
        for (localCoord, sprite) in hexSprites {
            let worldCoord = localCoord + player.position
            sprite.isBlocked = blockedHexes.contains(worldCoord)
            if isRainbow {
                sprite.isLava = worldCoord.q <= lavaColumn
                sprite.lavaColumnIndex = worldCoord.q
            }
            sprite.updateAppearance()
        }

        // Update potion sprite positions relative to player
        if isRainbow {
            for (worldPos, sprite) in potionSprites {
                let localCoord = worldPos - player.position
                sprite.position = hexLayout.hexToScreen(localCoord)
            }
        }

        // Update non-active player sprites as the active player moves
        if isTeam {
            updateNonActivePlayerSprites()
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
                isActingThisTurn = isTeam
                applySpellEffect(spell: spell, at: player.position, effect: effect)
                showSpellEffect(spell: spell, at: player.position, effect: effect)

                // Always deselect after casting (passive spells like Blur still end input state)
                selectedSpell = nil
                spellBar?.deselectAll()

            case .failure(let error):
                showCastError(error)
            }
            return
        }

        // Highlight valid target hexes in spell color
        let range = spell.range
        var targetHexes = player.position.hexesInRange(range)

        // Easy mode: AoE spells cannot target the player's own hex
        if GameManager.shared.gameMode == .easy && spell.isAoE {
            targetHexes.removeAll { $0 == player.position }
        }

        let color = SpellSlot.spellColor(for: spell).withAlphaComponent(0.6)

        for coord in targetHexes {
            let localCoord = coord - player.position
            if let hexSprite = hexSprites[localCoord] {
                hexSprite.highlightColor = color
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
        let difficulty = 1 + GameManager.shared.challengesCompleted / ChallengeAI.bossInterval
        currentChallenge = challengeGenerator.generateChallenge(for: player.loadout, difficulty: difficulty)
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

        // Reset challenge state
        blockedHexes.removeAll()
        playerDetected = false
        challengeTimer = 0
        challengeTimeLimit = 0
        challengeHadEnemies = false  // Reset for new challenge

        if let challenge = currentChallenge {
            // Set up timed challenge timer (stealth and light-only puzzle challenges have a timer)
            let isLightOnlyPuzzle = challenge.type == .puzzle
                && challenge.requiredCapabilities == [.illumination]
            if !isTeam && (challenge.type == .timed || challenge.type == .stealth || isLightOnlyPuzzle) {
                switch GameManager.shared.gameMode {
                case .easy: challengeTimeLimit = 20.0
                case .medium: challengeTimeLimit = 15.0
                case .hardcore: challengeTimeLimit = 5.0
                default: challengeTimeLimit = 10.0
                }
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

            // Update enemy visibility now that all darkness zones are registered
            for enemy in activeEnemies {
                updateEnemyDarknessVisibility(enemy)
            }
        }

        updateGridPosition()
    }

    // MARK: - Team Mode

    // Log of events that happened to each player since their last turn (shown in turn overlay)
    private var teamTurnLog: [Int: [String]] = [:]  // playerIndex: [event strings]

    private func appendTeamLog(for playerIndex: Int, _ message: String) {
        teamTurnLog[playerIndex, default: []].append(message)
    }

    private func setupTeamPlayers() {
        let count = GameManager.shared.teamPlayerCount
        let loadouts = GameManager.shared.playerLoadouts
        teamMembers = []

        for i in 0..<count {
            let color = GameScene.teamColors[i % GameScene.teamColors.count]
            let loadout = loadouts[i] ?? SpellLoadout()
            // Stagger starting positions so players aren't on top of each other
            let startOffsets: [HexCoord] = [.zero, HexCoord(q: 0, r: -1), HexCoord(q: 1, r: 0), HexCoord(q: -1, r: 0)]
            let startPos = startOffsets[i % startOffsets.count]
            let state = TeamMemberState(
                index: i,
                color: color,
                hp: Player.maxHP,
                mana: Player.maxMana,
                worldPosition: startPos,
                isDowned: false,
                loadout: loadout,
                challengeCompleted: false,
                challengeDescription: "",
                sprite: nil,
                arrowNode: nil
            )
            teamMembers.append(state)
        }

        // Configure the existing player object for player 0
        player.setLoadout(teamMembers[0].loadout)
        playerSprite.fillColor = teamMembers[0].color
        activeTeamIndex = 0
        GameManager.shared.activePlayerIndex = 0

        // Create non-active player sprites for ALL players (shown when that player isn't the active one)
        for i in 0..<count {
            let color = teamMembers[i].color
            let sprite = SKShapeNode(circleOfRadius: hexSize * 0.3)
            sprite.fillColor = color.withAlphaComponent(0.5)
            sprite.strokeColor = color
            sprite.lineWidth = 1.5
            sprite.zPosition = 4
            sprite.isHidden = true  // All start hidden; shown for non-active players
            entityLayer.addChild(sprite)
            teamMembers[i].sprite = sprite

            let numLabel = SKLabelNode(fontNamed: "Cochin-Bold")
            numLabel.text = "\(i + 1)"
            numLabel.fontSize = hexSize * 0.3
            numLabel.fontColor = .white
            numLabel.verticalAlignmentMode = .center
            numLabel.zPosition = 5
            sprite.addChild(numLabel)

            // Create offscreen arrow for each player
            let arrow = makeOffscreenArrow(color: color, playerIndex: i)
            arrow.isHidden = true
            uiLayer.addChild(arrow)
            teamMembers[i].arrowNode = arrow
        }

        // Setup team-specific UI
        setupTeamUI()
    }

    private func makeOffscreenArrow(color: SKColor, playerIndex: Int) -> SKNode {
        let container = SKNode()
        container.zPosition = 150

        // Triangle arrow
        let path = CGMutablePath()
        let s: CGFloat = 14
        path.move(to: CGPoint(x: 0, y: s))
        path.addLine(to: CGPoint(x: -s * 0.65, y: -s * 0.5))
        path.addLine(to: CGPoint(x:  s * 0.65, y: -s * 0.5))
        path.closeSubpath()
        let arrow = SKShapeNode(path: path)
        arrow.fillColor = color
        arrow.strokeColor = .white
        arrow.lineWidth = 1.5
        container.addChild(arrow)

        // Label: "P2: 10"
        let lbl = SKLabelNode(fontNamed: "Cochin-Bold")
        lbl.name = "arrowLabel"
        lbl.fontSize = 10
        lbl.fontColor = .white
        lbl.verticalAlignmentMode = .top
        lbl.horizontalAlignmentMode = .center
        lbl.position = CGPoint(x: 0, y: -s * 0.5 - 2)
        container.addChild(lbl)

        return container
    }

    private func setupTeamUI() {
        let rawSafeArea = view?.safeAreaInsets ?? .zero
        let safeBottom = rawSafeArea.bottom > 0 ? rawSafeArea.bottom : 34

        // End Turn button (bottom right)
        let btnW: CGFloat = 90
        let btnH: CGFloat = 40
        let btn = SKNode()
        btn.position = CGPoint(x: size.width - btnW / 2 - 10, y: safeBottom + 110)
        btn.zPosition = 105
        btn.name = "endTurnButton"

        let btnBg = SKShapeNode(rectOf: CGSize(width: btnW, height: btnH), cornerRadius: 10)
        btnBg.fillColor = SKColor(white: 0.25, alpha: 0.95)
        btnBg.strokeColor = teamMembers[0].color
        btnBg.lineWidth = 2
        btnBg.name = "endTurnButton"
        btn.addChild(btnBg)

        let btnLabel = SKLabelNode(fontNamed: "Cochin-Bold")
        btnLabel.text = "End Turn"
        btnLabel.fontSize = 13
        btnLabel.fontColor = .white
        btnLabel.verticalAlignmentMode = .center
        btnLabel.name = "endTurnButton"
        btn.addChild(btnLabel)

        uiLayer.addChild(btn)
        endTurnButton = btn

        // Team status label (below objective)
        let rawSafeTop = view?.safeAreaInsets.top ?? 0
        let safeTop = rawSafeTop > 0 ? rawSafeTop : 59

        let statusLbl = SKLabelNode(fontNamed: "Cochin")
        statusLbl.fontSize = 12
        statusLbl.fontColor = SKColor(white: 0.75, alpha: 1.0)
        statusLbl.position = CGPoint(x: size.width / 2, y: size.height - safeTop - 110)
        statusLbl.horizontalAlignmentMode = .center
        statusLbl.zPosition = 100
        uiLayer.addChild(statusLbl)
        teamStatusLabel = statusLbl
        updateTeamStatusLabel()
    }

    private func updateTeamStatusLabel() {
        guard isTeam else { return }
        let parts = teamMembers.map { m -> String in
            let prefix = m.isDowned ? "💀" : "P\(m.index + 1)"
            return "\(prefix):\(m.index == activeTeamIndex ? player.hp : m.hp)"
        }
        teamStatusLabel?.text = parts.joined(separator: " | ")
    }

    private func generateTeamChallenges() {
        let difficulty = 1 + GameManager.shared.challengesCompleted / ChallengeAI.bossInterval

        // Clear all old enemies and challenge elements
        for enemy in activeEnemies { enemySprites[enemy.id]?.removeFromParent() }
        activeEnemies.removeAll()
        enemySprites.removeAll()
        for (_, sprite) in interactiveSprites { sprite.removeFromParent() }
        interactiveElements.removeAll()
        interactiveSprites.removeAll()
        for (sprite, _) in challengeSprites { sprite.removeFromParent() }
        challengeSprites.removeAll()
        blockedHexes.removeAll()
        playerDetected = false
        challengeTimer = 0
        challengeTimeLimit = 0
        challengeCompleted = false
        challengeHadEnemies = false
        teamChallengeHadEnemies.removeAll()
        teamActedThisRound.removeAll()
        teamTurnLog.removeAll()

        // Reset per-player challenge completion flags
        for i in 0..<teamMembers.count {
            teamMembers[i].challengeCompleted = false
        }

        // Collect current world positions of all players so enemies don't spawn on them
        let playerWorldPositions = Set(teamMembers.enumerated().map { idx, m -> HexCoord in
            idx == activeTeamIndex ? player.position : m.worldPosition
        })

        // Generate one challenge per player, all challenges spawn from (0,0)
        // but with compass-point offsets
        for i in 0..<teamMembers.count {
            let loadout = teamMembers[i].loadout
            let challenge = challengeGenerator.generateChallenge(for: loadout, difficulty: difficulty)

            // challengeHadEnemies tracks whether ANY challenge has enemies
            let offset = GameScene.teamChallengeOffsets[i % GameScene.teamChallengeOffsets.count]

            for element in challenge.elements {
                let worldPosition = element.position + offset  // Offset from (0,0)

                if case .obstacle(let blocking, _) = element.type, blocking {
                    blockedHexes.insert(worldPosition)
                }

                if let enemy = EnemyFactory.createEnemy(from: element, at: worldPosition) {
                    // Never spawn an enemy on top of a player
                    guard !playerWorldPositions.contains(worldPosition) else { continue }
                    enemy.teamOwnerIndex = i
                    spawnEnemy(enemy)
                    challengeHadEnemies = true
                    teamChallengeHadEnemies[i] = true
                } else {
                    if let interactive = createInteractiveElement(from: element, at: worldPosition) {
                        interactiveElements[interactive.id] = interactive
                    }
                    renderChallengeElementAt(element, worldPosition: worldPosition)
                }
            }

            // Store challenge description for per-player objective label
            teamMembers[i].challengeDescription = challenge.description

            // Update objective for active player's challenge
            if i == activeTeamIndex {
                objectiveLabel?.text = challenge.description
            }
        }

        // Post-load darkness visibility pass
        for enemy in activeEnemies { updateEnemyDarknessVisibility(enemy) }

        // Store challenges per player (for per-player objective label updates)
        updateGridPosition()
    }

    private func markActivePlayerActed() {
        guard isTeam else { return }

        // If all challenges already complete, the round-clear flow handles the next step
        if challengeCompleted { return }

        // Save active player's current state before advancing
        teamMembers[activeTeamIndex].hp = player.hp
        teamMembers[activeTeamIndex].mana = player.mana
        teamMembers[activeTeamIndex].worldPosition = player.position

        teamActedThisRound.insert(activeTeamIndex)
        let nonDownedIndices = teamMembers.filter { !$0.isDowned }.map { $0.index }

        if Set(nonDownedIndices).isSubset(of: teamActedThisRound) {
            // All players have acted — enemies take their combined turn
            teamActedThisRound.removeAll()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                self.processTeamEnemyTurns()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                    self?.startNextTeamRound()
                }
            }
        } else {
            advanceTeamTurn()
        }
    }

    private func advanceTeamTurn() {
        guard isTeam else { return }

        // Find next non-downed, not-yet-acted player
        let count = teamMembers.count
        var nextIndex = (activeTeamIndex + 1) % count
        var loopCount = 0
        while (teamMembers[nextIndex].isDowned || teamActedThisRound.contains(nextIndex)) && loopCount < count {
            nextIndex = (nextIndex + 1) % count
            loopCount += 1
        }

        // Show turn overlay for next player
        showTeamTurnOverlay(for: nextIndex)
    }

    private func startNextTeamRound() {
        guard isTeam else { return }

        // Re-save active player's state after enemy turns (combat may have changed HP/mana)
        teamMembers[activeTeamIndex].hp = player.hp
        teamMembers[activeTeamIndex].mana = player.mana

        checkTeamChallengeCompletion()

        // Find first non-downed player for the new round
        guard let firstPlayer = teamMembers.first(where: { !$0.isDowned }) else {
            showGameOver()
            return
        }
        showTeamTurnOverlay(for: firstPlayer.index)
    }

    private func showTeamTurnOverlay(for playerIndex: Int) {
        guard isTeam, playerIndex < teamMembers.count else { return }

        // Remove any existing overlay
        teamTurnOverlay?.removeFromParent()
        teamTurnOverlay = nil

        let member = teamMembers[playerIndex]
        let hp = playerIndex == activeTeamIndex ? player.hp : member.hp
        let mana = playerIndex == activeTeamIndex ? player.mana : member.mana

        let overlay = SKNode()
        overlay.zPosition = 400
        overlay.name = "teamTurnOverlay_\(playerIndex)"

        // Dark overlay background
        let bg = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height))
        bg.fillColor = member.color.withAlphaComponent(0.3)
        bg.strokeColor = .clear
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.addChild(bg)

        // Panel
        let panelW = min(size.width - 60, 320)
        let panelH: CGFloat = 200
        let panel = SKShapeNode(rectOf: CGSize(width: panelW, height: panelH), cornerRadius: 16)
        panel.fillColor = SKColor(white: 0.12, alpha: 0.98)
        panel.strokeColor = member.color
        panel.lineWidth = 3
        panel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 20)
        overlay.addChild(panel)

        // Player number
        let titleLbl = SKLabelNode(fontNamed: "Cochin-Bold")
        titleLbl.text = "Player \(playerIndex + 1)'s Turn"
        titleLbl.fontSize = 26
        titleLbl.fontColor = member.color
        titleLbl.verticalAlignmentMode = .center
        titleLbl.position = CGPoint(x: size.width / 2, y: panel.position.y + 60)
        overlay.addChild(titleLbl)

        // HP and Mana
        let statsLbl = SKLabelNode(fontNamed: "Cochin")
        statsLbl.text = "HP: \(hp)/\(Player.maxHP)  ·  Mana: \(mana)/\(Player.maxMana)"
        statsLbl.fontSize = 16
        statsLbl.fontColor = SKColor(white: 0.85, alpha: 1.0)
        statsLbl.verticalAlignmentMode = .center
        statsLbl.position = CGPoint(x: size.width / 2, y: panel.position.y + 20)
        overlay.addChild(statsLbl)

        // What happened since last turn
        let log = teamTurnLog[playerIndex] ?? []
        let logHeaderLbl = SKLabelNode(fontNamed: "Cochin-Bold")
        logHeaderLbl.text = log.isEmpty ? "Nothing new since your last turn." : "Since your last turn:"
        logHeaderLbl.fontSize = 12
        logHeaderLbl.fontColor = SKColor(white: 0.6, alpha: 1.0)
        logHeaderLbl.verticalAlignmentMode = .center
        logHeaderLbl.position = CGPoint(x: size.width / 2, y: panel.position.y - 10)
        overlay.addChild(logHeaderLbl)

        if !log.isEmpty {
            let logText = log.suffix(3).joined(separator: "\n")
            let logLbl = SKLabelNode(fontNamed: "Cochin")
            logLbl.text = logText
            logLbl.fontSize = 11
            logLbl.fontColor = SKColor(white: 0.7, alpha: 1.0)
            logLbl.numberOfLines = 0
            logLbl.preferredMaxLayoutWidth = panelW - 30
            logLbl.lineBreakMode = .byWordWrapping
            logLbl.verticalAlignmentMode = .top
            logLbl.horizontalAlignmentMode = .center
            logLbl.position = CGPoint(x: size.width / 2, y: panel.position.y - 28)
            overlay.addChild(logLbl)
        }

        // Clear this player's log now that they've seen it
        teamTurnLog[playerIndex] = []

        // "Tap to play" hint
        let hintLbl = SKLabelNode(fontNamed: "Cochin")
        hintLbl.text = "Tap to Play"
        hintLbl.fontSize = 14
        hintLbl.fontColor = SKColor(white: 0.55, alpha: 1.0)
        hintLbl.verticalAlignmentMode = .center
        hintLbl.position = CGPoint(x: size.width / 2, y: panel.position.y - 82)
        overlay.addChild(hintLbl)

        addChild(overlay)
        teamTurnOverlay = overlay
        overlay.alpha = 0
        overlay.run(SKAction.fadeIn(withDuration: 0.2))

        // Store pending player index for when overlay is dismissed
        overlay.userData = NSMutableDictionary()
        overlay.userData?["playerIndex"] = playerIndex
    }

    private func dismissTeamTurnOverlay() {
        guard let overlay = teamTurnOverlay,
              let playerIndex = overlay.userData?["playerIndex"] as? Int
        else { return }

        teamTurnOverlay = nil
        overlay.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.15),
            SKAction.removeFromParent()
        ]))

        loadTeamPlayerState(playerIndex)
    }

    private func loadTeamPlayerState(_ index: Int) {
        guard isTeam, index < teamMembers.count else { return }

        let member = teamMembers[index]
        activeTeamIndex = index
        GameManager.shared.activePlayerIndex = index
        isActingThisTurn = false

        // Clear any targeting overlay from the previous player's turn
        clearHighlights()
        selectedSpell = nil
        spellBar?.deselectAll()

        player.teleportTo(member.worldPosition)
        player.setHP(member.isDowned ? 0 : member.hp)
        player.setMana(member.mana)
        player.setLoadout(member.loadout)

        // Update player sprite color
        playerSprite.fillColor = member.color
        playerSprite.strokeColor = member.isDowned
            ? SKColor(white: 0.4, alpha: 1.0) : SKColor.white
        playerSprite.alpha = member.isDowned ? 0.4 : 1.0

        // Update spell bar
        if let bar = spellBar {
            bar.removeFromParent()
            spellBar = nil
        }
        if !member.isDowned {
            let rawSafeArea = view?.safeAreaInsets ?? .zero
            let safeBottom = rawSafeArea.bottom > 0 ? rawSafeArea.bottom : 34
            let spells = member.loadout.spells
            if !spells.isEmpty {
                let bar = SpellBar(spells: spells, slotSize: 60)
                bar.position = CGPoint(x: size.width / 2, y: safeBottom + 50)
                bar.onSpellSelected = { [weak self] spell in self?.selectSpell(spell) }
                uiLayer.addChild(bar)
                spellBar = bar
            }
        }

        // Update End Turn button stroke color
        if let btn = endTurnButton?.children.first(where: { $0 is SKShapeNode }) as? SKShapeNode {
            btn.strokeColor = member.color
        }

        hpDisplay?.setHP(player.hp)
        manaBar?.setMana(player.mana)

        // Update objective label for this player's challenge
        let desc = teamMembers[index].challengeDescription
        if teamMembers[index].challengeCompleted {
            objectiveLabel?.text = "✓ " + desc
        } else {
            objectiveLabel?.text = desc
        }

        updateGridPosition()  // also calls updateNonActivePlayerSprites()
        updateTeamStatusLabel()
        refreshEnemyStunVisuals()
    }

    private func updateNonActivePlayerSprites() {
        guard isTeam, activeTeamIndex < teamMembers.count else { return }

        // Always hide the active player's secondary sprite/arrow — they use the main playerSprite
        teamMembers[activeTeamIndex].sprite?.isHidden = true
        teamMembers[activeTeamIndex].arrowNode?.isHidden = true

        for i in 0..<teamMembers.count where i != activeTeamIndex {
            let member = teamMembers[i]
            let worldPos = member.worldPosition
            let localCoord = worldPos - player.position
            let dist = worldPos.distance(to: player.position)

            if let sprite = member.sprite {
                if dist <= GameScene.visibleRange {
                    sprite.isHidden = false
                    sprite.position = hexLayout.hexToScreen(localCoord)
                    sprite.alpha = member.isDowned ? 0.25 : 0.7
                } else {
                    sprite.isHidden = true
                }
            }

            // Update arrow
            updateOffscreenArrow(for: i)
        }
    }

    private func updateOffscreenArrow(for playerIndex: Int) {
        guard playerIndex < teamMembers.count else { return }
        let member = teamMembers[playerIndex]
        guard let arrow = member.arrowNode else { return }

        let worldPos = member.worldPosition
        let dist = worldPos.distance(to: player.position)

        if dist > GameScene.visibleRange {
            arrow.isHidden = false

            // Direction from active player to this player in screen space
            let localCoord = worldPos - player.position
            let targetScreen = hexLayout.hexToScreen(localCoord)
            let dx = targetScreen.x - hexLayout.origin.x + size.width / 2
            let dy = targetScreen.y - hexLayout.origin.y + size.height / 2
            let angle = atan2(dy - size.height / 2, dx - size.width / 2)

            // Place at screen edge
            let margin: CGFloat = 28
            let edgeX = size.width / 2 + cos(angle) * (size.width / 2 - margin)
            let edgeY = size.height / 2 + sin(angle) * (size.height / 2 - margin)
            arrow.position = CGPoint(x: edgeX, y: edgeY)
            arrow.zRotation = angle - .pi / 2  // Triangle points toward player

            // Update label
            let hp = playerIndex == activeTeamIndex ? player.hp : member.hp
            if let lbl = arrow.childNode(withName: "arrowLabel") as? SKLabelNode {
                lbl.text = "P\(playerIndex + 1):\(hp)"
            }
        } else {
            arrow.isHidden = true
        }
    }

    private func handleEndTurn() {
        guard isTeam, !isActingThisTurn else { return }
        isActingThisTurn = true
        selectSpell(nil)
        spellBar?.deselectAll()
        markActivePlayerActed()
    }

    private func checkTeamChallengeCompletion() {
        guard isTeam, !challengeCompleted else { return }

        // Check if active player's challenge enemies are all dead
        let activePlayerEnemies = activeEnemies.filter { $0.isAlive && $0.teamOwnerIndex == activeTeamIndex }

        // Check if all enemies for this player have been defeated
        let hadEnemies = teamChallengeHadEnemies[activeTeamIndex] == true
        let allDefeated = activePlayerEnemies.isEmpty
        if hadEnemies && allDefeated && !teamMembers[activeTeamIndex].challengeCompleted {
            teamMembers[activeTeamIndex].challengeCompleted = true
            let memberColor = teamMembers[activeTeamIndex].color
            showStatusText("P\(activeTeamIndex + 1) done!", at: CGPoint(x: size.width / 2, y: size.height / 2 + 40), color: memberColor)
        }

        // Non-combat (puzzle): complete when all interactive elements in this player's area are solved
        if !hadEnemies && !teamMembers[activeTeamIndex].challengeCompleted {
            if checkTeamPuzzleSolved(for: activeTeamIndex) {
                teamMembers[activeTeamIndex].challengeCompleted = true
                let memberColor = teamMembers[activeTeamIndex].color
                showStatusText("P\(activeTeamIndex + 1) done!", at: CGPoint(x: size.width / 2, y: size.height / 2 + 40), color: memberColor)
            }
        }

        // Check if ALL non-downed players have completed their challenges
        let allDone = teamMembers.allSatisfy { $0.challengeCompleted || $0.isDowned }
        if allDone {
            challengeCompleted = true
            GameManager.shared.completeChallenge()
            scoreLabel?.text = "Score: \(GameManager.shared.challengesCompleted)"
            showStatusText("Round Clear!", at: CGPoint(x: size.width / 2, y: size.height / 2 + 60), color: .yellow)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self = self else { return }
                self.challengeCompleted = false
                self.generateTeamChallenges()
                self.showTeamTurnOverlay(for: self.activeTeamIndex)
            }
        }
    }

    /// Check if a non-combat (puzzle) challenge is solved for the given team player.
    /// Filters interactive elements to only those within that player's challenge area.
    private func checkTeamPuzzleSolved(for playerIndex: Int) -> Bool {
        let offset = GameScene.teamChallengeOffsets[playerIndex % GameScene.teamChallengeOffsets.count]
        let area = interactiveElements.values.filter {
            $0.position.distance(to: offset) <= ChallengeAI.hexRange + 1
        }
        guard !area.isEmpty else { return false }
        for element in area {
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

    private func processTeamEnemyTurns() {
        guard isTeam else { return }

        let enemyPositions = Set(activeEnemies.filter { $0.isAlive }.map { $0.position })
        // Downed players block enemy movement so enemies can't stack on them
        let downedPositions = Set(teamMembers.filter { $0.isDowned }.map { m -> HexCoord in
            m.index == activeTeamIndex ? player.position : m.worldPosition
        })
        let pathBlocked = blockedHexes.union(enemyPositions).union(downedPositions)

        for enemy in activeEnemies where enemy.isAlive {
            let blockedForThisEnemy = pathBlocked.subtracting([enemy.position])

            // Find nearest non-downed team member
            let nonDownedMembers = teamMembers.filter { !$0.isDowned }
            let targetPosition: HexCoord
            if let nearest = nonDownedMembers.min(by: {
                enemy.position.distance(to: $0.index == activeTeamIndex ? player.position : $0.worldPosition) <
                enemy.position.distance(to: $1.index == activeTeamIndex ? player.position : $1.worldPosition)
            }) {
                targetPosition = nearest.index == activeTeamIndex ? player.position : nearest.worldPosition
            } else {
                targetPosition = player.position
            }

            let action = enemy.takeTurn(playerPosition: targetPosition, blocked: blockedForThisEnemy)

            switch action {
            case .attack(let at, let damage):
                // Find which team member is at the attacked hex
                applyTeamEnemyDamage(at: at, damage: damage)

            case .move:
                break

            case .specialAttack(let type, let center, let radius, let damage):
                if type == .areaSlam {
                    let affected = center.hexesInRange(radius)
                    for hex in affected {
                        applyTeamEnemyDamage(at: hex, damage: damage)
                    }
                } else if type == .summon {
                    let minion = Enemy(hp: 1, damage: damage, behavior: .aggressive, position: center)
                    minion.teamOwnerIndex = enemy.teamOwnerIndex
                    spawnEnemy(minion)
                    let minionLocal = center - player.position
                    let minionScreen = hexLayout.hexToScreen(minionLocal)
                    let worldPos = CGPoint(x: minionScreen.x + entityLayer.position.x,
                                          y: minionScreen.y + entityLayer.position.y)
                    showStatusText("Summoned!", at: worldPos, color: SKColor(red: 0.15, green: 0.55, blue: 0.4, alpha: 1.0))
                }

            case .healAlly(let amount, let range):
                let allies = activeEnemies.filter { ally in
                    ally.id != enemy.id && ally.isAlive && ally.hp < ally.maxHP &&
                    enemy.position.distance(to: ally.position) <= range
                }
                if let target = allies.min(by: { $0.hp < $1.hp }) {
                    target.heal(amount)
                    let screenPos = worldToScreen(target.position)
                    showHealingNumber(amount, at: screenPos)
                }

            case .stunned, .wait:
                break
            }
        }

        checkAndMergeEnemies()

        // Log the enemy round for all non-downed players so their next turn overlay shows something
        for i in 0..<teamMembers.count where !teamMembers[i].isDowned {
            appendTeamLog(for: i, "⚔️ Enemies took their turns.")
        }

        checkTeamChallengeCompletion()
    }

    private func applyTeamEnemyDamage(at hex: HexCoord, damage: Int) {
        // Find which team member is at this hex
        for i in 0..<teamMembers.count {
            let memberPos = i == activeTeamIndex ? player.position : teamMembers[i].worldPosition
            if memberPos == hex {
                if i == activeTeamIndex {
                    player.takeDamage(damage)
                    let screenPos = CGPoint(x: size.width / 2, y: size.height / 2)
                    showDamageNumber(damage, at: screenPos)
                    showSpellFlash(color: .red, at: screenPos)
                    appendTeamLog(for: i, "Took \(damage) damage from an enemy.")
                    if !player.isAlive {
                        downTeamPlayer(i)
                    }
                } else {
                    teamMembers[i].hp = max(0, teamMembers[i].hp - damage)
                    appendTeamLog(for: i, "Took \(damage) damage from an enemy.")
                    if teamMembers[i].hp <= 0 {
                        downTeamPlayer(i)
                    }
                    updateTeamStatusLabel()
                }
                return
            }
        }
        // No team member at that hex — no damage to apply
    }

    private func downTeamPlayer(_ index: Int) {
        teamMembers[index].isDowned = true
        appendTeamLog(for: index, "⚠️ You were downed! Need healing to recover.")

        if index == activeTeamIndex {
            // Show downed indicator on active player sprite
            playerSprite.alpha = 0.4
            playerSprite.strokeColor = SKColor(white: 0.4, alpha: 1.0)
            showStatusText("Downed!", at: CGPoint(x: size.width / 2, y: size.height / 2), color: .red)
        } else {
            // Dim non-active sprite
            teamMembers[index].sprite?.alpha = 0.25
        }

        updateTeamStatusLabel()

        // Check if all players are downed
        if teamMembers.allSatisfy({ $0.isDowned }) {
            showGameOver()
        }
    }

    /// Attempt to revive a downed team member at the given world hex
    /// Returns true and the heal amount if a downed member was revived
    @discardableResult
    private func reviveDownedTeamMember(at hex: HexCoord, healing: Int) -> Bool {
        for i in 0..<teamMembers.count {
            let memberPos = i == activeTeamIndex ? player.position : teamMembers[i].worldPosition
            guard memberPos == hex, teamMembers[i].isDowned else { continue }

            let reviveHP = max(1, healing)
            teamMembers[i].isDowned = false
            teamMembers[i].hp = reviveHP
            // Clear stale "downed" message so it doesn't show alongside the revival notice
            teamTurnLog[i] = []
            appendTeamLog(for: i, "Revived with \(reviveHP) HP!")

            if i == activeTeamIndex {
                player.setHP(reviveHP)
                playerSprite.alpha = 1.0
                playerSprite.strokeColor = .white
            } else {
                teamMembers[i].sprite?.alpha = 0.7
            }

            let screenPos: CGPoint
            if i == activeTeamIndex {
                screenPos = CGPoint(x: size.width / 2, y: size.height / 2)
            } else {
                let localCoord = teamMembers[i].worldPosition - player.position
                screenPos = hexLayout.hexToScreen(localCoord)
            }
            showStatusText("Revived!", at: screenPos, color: .green)
            updateTeamStatusLabel()
            return true
        }
        return false
    }

    /// Heal a living (non-downed) non-active team member at the given world hex.
    /// Returns true if a team member was healed.
    @discardableResult
    private func healLivingTeamMember(at hex: HexCoord, healing: Int) -> Bool {
        for i in 0..<teamMembers.count where i != activeTeamIndex {
            let memberPos = teamMembers[i].worldPosition
            guard memberPos == hex, !teamMembers[i].isDowned else { continue }

            let newHP = min(teamMembers[i].hp + healing, Player.maxHP)
            let healed = newHP - teamMembers[i].hp
            teamMembers[i].hp = newHP
            appendTeamLog(for: i, "P\(activeTeamIndex + 1) healed you for \(healed) HP!")

            teamMembers[i].sprite?.alpha = 0.7
            updateTeamStatusLabel()
            return true
        }
        return false
    }

    // MARK: - Rainbow Mode

    private func setupRainbow() {
        lavaColumn = player.position.q - GameScene.visibleRange + 1
        nextZoneColumn = player.position.q + RainbowConfig.zoneSpacing
        zonesCleared = 0
        turnsSinceLavaAdvance = 0
        objectiveLabel?.text = "Outrun the lava!"
        scoreLabel?.text = "Zones: 0"
        updateGridPosition()
    }

    private func rainbowAfterPlayerAction() {
        guard isRainbow else { return }

        turnsSinceLavaAdvance += 1
        if turnsSinceLavaAdvance >= RainbowConfig.lavaAdvanceInterval {
            advanceLava()
            turnsSinceLavaAdvance = 0
        }

        // Check if player entered lava
        if player.position.q <= lavaColumn {
            showGameOver()
            return
        }

        // Check potion collection
        if let color = droppedPotions[player.position] {
            player.collectPotion(color.rawValue)
            droppedPotions.removeValue(forKey: player.position)
            potionSprites[player.position]?.removeFromParent()
            potionSprites.removeValue(forKey: player.position)
            potionBar?.updateCounts(from: player)
            showStatusText("+1 \(color.rawValue.capitalized)", at: CGPoint(x: size.width / 2, y: size.height / 2), color: .green)
        }

        // Check zone completion — enemies are removed from activeEnemies on death,
        // so we use rainbowZoneHadEnemies to detect the transition from "had enemies" to "all cleared"
        if rainbowZoneHadEnemies && activeEnemies.isEmpty {
            rainbowZoneHadEnemies = false
            zonesCleared += 1
            scoreLabel?.text = "Zones: \(zonesCleared)"
            let dropPos = player.position  // Drop near player
            let color = PotionColor.random()
            droppedPotions[dropPos] = color
            renderPotionDrop(at: dropPos, color: color)
            potionBar?.updateCounts(from: player)
            showStatusText("Zone cleared!", at: CGPoint(x: size.width / 2, y: size.height / 2 + 30), color: .yellow)
            objectiveLabel?.text = "Collect the potion!"
        }

        // Generate new zone if approaching
        if player.position.q >= nextZoneColumn - 1 && activeEnemies.isEmpty {
            generateRainbowZone()
        }

        updateGridPosition()
    }

    private func advanceLava() {
        lavaColumn += 1

        // Kill enemies caught in lava
        for enemy in activeEnemies where enemy.isAlive {
            if enemy.position.q <= lavaColumn {
                enemy.takeDamage(enemy.hp)  // Kill instantly
                enemySprites[enemy.id]?.removeFromParent()
                enemySprites.removeValue(forKey: enemy.id)
                let screenPos = worldToScreen(enemy.position)
                showStatusText("Consumed!", at: screenPos, color: .orange)
            }
        }
        activeEnemies.removeAll { !$0.isAlive }

        // Destroy potions in lava
        for (pos, _) in droppedPotions where pos.q <= lavaColumn {
            potionSprites[pos]?.removeFromParent()
            potionSprites.removeValue(forKey: pos)
            droppedPotions.removeValue(forKey: pos)
        }

        // Check if player is caught
        if player.position.q <= lavaColumn {
            showGameOver()
            return
        }

        showStatusText("Lava advances!", at: CGPoint(x: size.width / 2, y: size.height / 2 - 30), color: .red)
        updateGridPosition()
    }

    private func generateRainbowZone() {
        // Clear old enemies
        for enemy in activeEnemies {
            enemySprites[enemy.id]?.removeFromParent()
        }
        activeEnemies.removeAll()
        enemySprites.removeAll()
        blockedHexes.removeAll()

        // Generate 1-2 enemies near the zone center
        let zoneCenter = HexCoord(q: nextZoneColumn, r: 0)
        let enemyCount = zonesCleared < 3 ? 1 : Int.random(in: 1...2)
        let neighbors = zoneCenter.neighbors()

        for i in 0..<enemyCount {
            let pos = i < neighbors.count ? neighbors[i] : zoneCenter
            let hp = max(1, 1 + zonesCleared / 2)
            let enemy = Enemy(hp: hp, damage: 1, behavior: .aggressive, position: pos)
            spawnEnemy(enemy)
        }

        nextZoneColumn += RainbowConfig.zoneSpacing
        rainbowZoneHadEnemies = true
        objectiveLabel?.text = "Defeat the enemies!"
        updateGridPosition()
    }

    private func selectPotion(_ color: PotionColor?) {
        // Clear existing highlights
        clearHighlights()
        selectedSpell = nil
        selectedPotion = nil

        guard let color = color else { return }

        // Must have this potion in inventory
        guard player.potionCount(for: color.rawValue) > 0 else { return }

        // Potions are instant self-cast AoE — apply immediately at player position
        let spell = color.spell
        player.usePotion(color.rawValue)
        potionBar?.updateCounts(from: player)

        // Build the right effect for applySpellEffect
        let effect: SpellEffect
        if spell.isOffensive {
            effect = .damage(spell.rollOffense())
        } else if spell.isDefensive {
            effect = .healing(spell.rollDefense())
        } else {
            effect = .none
        }
        applySpellEffect(spell: spell, at: player.position, effect: effect)
        showSpellEffect(spell: spell, at: player.position, effect: effect)

        potionBar?.deselectAll()

        // Trigger enemy turns after using a potion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.processEnemyTurns()
        }
    }

    private func renderPotionDrop(at worldPos: HexCoord, color: PotionColor) {
        let localCoord = worldPos - player.position
        let screenPos = hexLayout.hexToScreen(localCoord)
        let radius = hexSize * 0.25

        let container: SKNode
        if color == .rainbow {
            container = PotionSlotNode.makeRainbowCircle(radius: radius)
        } else {
            let circle = SKShapeNode(circleOfRadius: radius)
            circle.fillColor = PotionSlotNode.potionSKColor(for: color)
            circle.strokeColor = .white
            circle.lineWidth = 1
            container = circle
        }
        container.zPosition = 3
        container.position = screenPos
        entityLayer.addChild(container)
        potionSprites[worldPos] = container

        // Pulse animation
        let pulse = SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 1.2, duration: 0.5),
            SKAction.scale(to: 1.0, duration: 0.5)
        ]))
        container.run(pulse)
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

        case .darkness(let radius):
            return InteractiveElement(position: position, type: .darkness(radius: radius, dispelled: false))

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

        // Stealth guards are truly unkillable on iOS
        if currentChallenge?.type == .stealth {
            enemy.isInvulnerable = true
        }

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

        // Hide enemies spawned inside darkness
        updateEnemyDarknessVisibility(enemy)

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

        // Reveal/hide based on darkness
        updateEnemyDarknessVisibility(enemy)
    }

    private func updateEnemyHP(_ enemy: Enemy, hp: Int) {
        guard let sprite = enemySprites[enemy.id] else { return }
        // Update HP label in sprite (sprite is already an SKNode container)
        if let hpLabel = sprite.children.compactMap({ $0 as? SKLabelNode }).first {
            // Stealth enemies keep their ∞ label
            if currentChallenge?.type == .stealth {
                return
            }
            hpLabel.text = "\(hp)"
        }
    }

    /// Sync stun indicator nodes on all active enemy sprites.
    /// Call after loading team player state or applying stun so all players see paralysis.
    private func refreshEnemyStunVisuals() {
        for enemy in activeEnemies where enemy.isAlive {
            guard let sprite = enemySprites[enemy.id] else { continue }
            // Remove any existing stun indicator
            sprite.childNode(withName: "stunIndicator")?.removeFromParent()
            if enemy.isStunned {
                let indicator = SKLabelNode(fontNamed: "Cochin-Bold")
                indicator.name = "stunIndicator"
                indicator.text = "⚡"
                indicator.fontSize = 10
                indicator.verticalAlignmentMode = .center
                indicator.position = CGPoint(x: hexSize * 0.3, y: hexSize * 0.3)
                indicator.zPosition = 6
                sprite.addChild(indicator)
            }
        }
    }

    private func handleEnemyDeath(_ enemy: Enemy) {
        guard let sprite = enemySprites[enemy.id] else { return }

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

        // In team mode, log cross-player kills so the other player sees activity
        if isTeam && enemy.teamOwnerIndex != activeTeamIndex && !teamMembers[enemy.teamOwnerIndex].isDowned {
            appendTeamLog(for: enemy.teamOwnerIndex, "P\(activeTeamIndex + 1) eliminated an enemy from your challenge!")
        }

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
            let hp = destructible ? (element.properties["hp"] as? Int ?? 3) : 0
            sprite = createObstacleSprite(destructible: destructible, hp: hp)

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

        // Enemy body - red triangle (summoner is larger)
        let size = (behavior == .summoner) ? hexSize * 0.42 : hexSize * 0.35
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
            case .summoner:
                fillColor = SKColor(red: 0.15, green: 0.55, blue: 0.4, alpha: 1.0)  // Dark mint for summoner
                strokeColor = SKColor(red: 0.1, green: 0.35, blue: 0.25, alpha: 1.0)
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

    private func createObstacleSprite(destructible: Bool, hp: Int = 0) -> SKNode {
        let container = SKNode()
        let size = hexSize * 0.6
        let obstacle = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: 4)
        obstacle.fillColor = destructible ? SKColor(red: 0.5, green: 0.3, blue: 0.1, alpha: 1.0) : SKColor(white: 0.4, alpha: 1.0)
        obstacle.strokeColor = SKColor(white: 0.2, alpha: 1.0)
        obstacle.lineWidth = 2
        container.addChild(obstacle)

        if destructible && hp > 0 {
            let hpLabel = SKLabelNode(fontNamed: "Cochin-Bold")
            hpLabel.text = "\(hp)"
            hpLabel.fontSize = hexSize * 0.3
            hpLabel.fontColor = .white
            hpLabel.verticalAlignmentMode = .center
            hpLabel.horizontalAlignmentMode = .center
            hpLabel.zPosition = 1
            hpLabel.name = "hpLabel"
            container.addChild(hpLabel)
        }

        return container
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
        let size = hexSize * 0.35

        // Checkered flag
        let flagWidth = size * 2
        let flagHeight = size * 1.5
        let cols = 4
        let rows = 3
        let cellW = flagWidth / CGFloat(cols)
        let cellH = flagHeight / CGFloat(rows)

        for row in 0..<rows {
            for col in 0..<cols {
                let cell = SKShapeNode(rectOf: CGSize(width: cellW, height: cellH))
                cell.position = CGPoint(
                    x: -flagWidth / 2 + cellW * (CGFloat(col) + 0.5),
                    y: -flagHeight / 2 + cellH * (CGFloat(row) + 0.5)
                )
                cell.fillColor = (row + col) % 2 == 0 ? .white : .black
                cell.strokeColor = .clear
                cell.lineWidth = 0
                cell.alpha = 0.85
                container.addChild(cell)
            }
        }

        // Border around the flag
        let border = SKShapeNode(rectOf: CGSize(width: flagWidth, height: flagHeight))
        border.fillColor = .clear
        border.strokeColor = SKColor(white: 0.7, alpha: 0.9)
        border.lineWidth = 1
        container.addChild(border)

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

        // If game over, any tap returns to spell selection (or menu for rainbow)
        if isGameOver {
            if isRainbow {
                returnToMainMenu()
            } else {
                returnToSpellSelection()
            }
            return
        }

        let sceneLocation = touch.location(in: self)

        // If team turn overlay is showing, tap dismisses it
        if isTeam && teamTurnOverlay != nil {
            dismissTeamTurnOverlay()
            return
        }

        // Check if touch is on End Turn button (team mode)
        if isTeam, let btn = endTurnButton {
            let btnLocation = touch.location(in: btn)
            if CGRect(x: -60, y: -22, width: 120, height: 44).contains(btnLocation) {
                handleEndTurn()
                return
            }
        }

        // Check if touch is on back button
        if let back = backButton {
            let backLocation = touch.location(in: back)
            let backBounds = CGRect(x: -40, y: -20, width: 80, height: 40)
            if backBounds.contains(backLocation) {
                if isRainbow {
                    returnToMainMenu()
                } else {
                    returnToSpellSelection()
                }
                return
            }
        }

        // Check if touch is on UI (potion bar in rainbow, spell bar otherwise)
        if let bar = potionBar {
            let barLocation = touch.location(in: bar)
            if bar.contains(barLocation) {
                bar.handleTouch(at: barLocation)
                return
            }
        }
        if let bar = spellBar {
            let barLocation = touch.location(in: bar)
            if bar.contains(barLocation) {
                spellBarTouchPoint = barLocation
                let work = DispatchWorkItem { [weak self] in
                    guard let self = self else { return }
                    if let spell = self.spellBar?.spellAt(point: barLocation) {
                        self.showSpellTooltip(spell)
                    }
                    self.spellBarTouchPoint = nil
                }
                longPressWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
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

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Cancel any pending long-press
        longPressWork?.cancel()
        longPressWork = nil

        // If tooltip is showing, dismiss it
        if spellTooltip != nil {
            dismissSpellTooltip()
            spellBarTouchPoint = nil
            return
        }

        // If we had a pending spell bar tap (finger lifted before long-press fired), handle as normal tap
        if let point = spellBarTouchPoint {
            spellBar?.handleTouch(at: point)
            spellBarTouchPoint = nil
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        longPressWork?.cancel()
        longPressWork = nil
        dismissSpellTooltip()
        spellBarTouchPoint = nil
    }

    private func returnToMainMenu() {
        let menuScene = MainMenuScene(size: size)
        menuScene.scaleMode = scaleMode
        let transition = SKTransition.fade(withDuration: 0.5)
        view?.presentScene(menuScene, transition: transition)
    }

    private func returnToSpellSelection() {
        GameManager.shared.challengesCompleted = 0
        let spellScene = SpellSelectionScene(size: size)
        spellScene.scaleMode = scaleMode
        let transition = SKTransition.fade(withDuration: 0.5)
        view?.presentScene(spellScene, transition: transition)
    }

    private func handleHexTap(_ coord: HexCoord) {
        // Rainbow mode: block movement/casting into lava
        if isRainbow && coord.q <= lavaColumn {
            return
        }

        // In team mode, block all actions after the player has already acted this turn
        if isTeam && isActingThisTurn { return }

        if let spell = selectedSpell {
            // Easy/Rainbow mode: AoE spells cannot target the player's own hex
            if (GameManager.shared.gameMode == .easy || isRainbow) && spell.isAoE && coord == player.position {
                return
            }

            // Cast selected spell at this hex
            let result = player.castSpell(spell, at: coord)

            switch result {
            case .success(let effect):
                isActingThisTurn = isTeam
                // Apply actual game effects based on spell type
                applySpellEffect(spell: spell, at: coord, effect: effect)
                showSpellEffect(spell: spell, at: coord, effect: effect)

                // In team mode, always deselect (passive spells still end your turn)
                if !spell.isPassive || isTeam {
                    selectSpell(nil)
                    spellBar?.deselectAll()
                    selectedPotion = nil
                }
                // In team mode, passive spells must explicitly advance the turn
                if isTeam && spell.isPassive {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.markActivePlayerActed()
                    }
                }

            case .failure(let error):
                showCastError(error)
            }
        } else {
            // Move to this hex (check if not blocked by enemy)
            let enemyPositions = Set(activeEnemies.filter { $0.isAlive }.map { $0.position })
            var allBlocked = blockedHexes.union(enemyPositions)
            if isTeam {
                // Prevent walking into a living teammate's hex
                let teammatePositions = Set(teamMembers.enumerated().compactMap { idx, m -> HexCoord? in
                    guard idx != activeTeamIndex, !m.isDowned else { return nil }
                    return m.worldPosition
                })
                allBlocked = allBlocked.union(teammatePositions)
            }

            isActingThisTurn = isTeam  // Lock out further actions immediately
            player.moveTo(coord, blocked: allBlocked) { [weak self] in
                guard let self = self else { return }
                // Check if player reached any targets
                self.checkInteractionsAtPosition(coord)
                self.checkChallengeCompletion()
                // In team mode, movement counts as the player's action
                if self.isTeam {
                    self.markActivePlayerActed()
                }
            }
        }
    }

    private func applySpellEffect(spell: Spell, at coord: HexCoord, effect: SpellEffect) {
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
                        showSpellFlash(color: SpellSlot.spellColor(for: spell), at: screenPos)
                    } else if damageObstacleAt(hex, damage: spell.rollOffense()) {
                        let screenPos = worldToScreen(hex)
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
            } else if spell.isOffensive && blockedHexes.contains(coord) {
                // Life steal off barrier (e.g. Life Transference hitting an obstacle)
                let healing = spell.rollDefense()
                player.heal(healing)
                let playerScreenPos = CGPoint(x: size.width / 2, y: size.height / 2)
                showHealingNumber(healing, at: playerScreenPos)
                let screenPos = worldToScreen(coord)
                showSpellFlash(color: .green, at: screenPos)
            } else if spell.isOffensive && isRainbow {
                // Rainbow mode dual potions (gold, rainbow): always heal even if no enemies hit
                let healing = spell.rollDefense()
                player.heal(healing)
                let playerScreenPos = CGPoint(x: size.width / 2, y: size.height / 2)
                showHealingNumber(healing, at: playerScreenPos)
            } else if !spell.isOffensive {
                if spell.isAoE && isTeam {
                    // AoE healing in team mode: heal all teammates/self in radius
                    let radius = max(1, spell.range / 2)
                    for hex in coord.hexesInRange(radius) {
                        let roll = spell.rollDefense()
                        if reviveDownedTeamMember(at: hex, healing: roll) {
                            showHealingNumber(roll, at: worldToScreen(hex))
                        } else if healLivingTeamMember(at: hex, healing: roll) {
                            showHealingNumber(roll, at: worldToScreen(hex))
                        } else if hex == player.position {
                            player.heal(roll)
                            showHealingNumber(roll, at: worldToScreen(hex))
                        }
                    }
                } else {
                    let healRoll = spell.rollDefense()
                    // In team mode: check downed teammates first, then living teammates, then self
                    if isTeam && reviveDownedTeamMember(at: coord, healing: healRoll) {
                        let screenPos = worldToScreen(coord)
                        showHealingNumber(healRoll, at: screenPos)
                    } else if isTeam && healLivingTeamMember(at: coord, healing: healRoll) {
                        let screenPos = worldToScreen(coord)
                        showHealingNumber(healRoll, at: screenPos)
                    } else if isTeam && coord == player.position {
                        // Caster healing themselves
                        player.heal(healRoll)
                        let screenPos = worldToScreen(coord)
                        showHealingNumber(healRoll, at: screenPos)
                    } else if let healAmount = healNPCAt(coord, amount: healRoll) {
                        // Pure healing spell - check for NPCs at target location
                        let screenPos = worldToScreen(coord)
                        showHealingNumber(healAmount, at: screenPos)
                        showStatusText("Healed!", at: screenPos, color: .green)
                    } else if !isTeam {
                        // Non-team mode: heal the caster when no other target is found
                        if case .healing(let amount) = effect {
                            player.heal(amount)
                            let playerScreenPos = CGPoint(x: size.width / 2, y: size.height / 2)
                            showHealingNumber(amount, at: playerScreenPos)
                        }
                    }
                }
            }
        }

        // Handle crowd control
        if spell.causesParalysis {
            if spell.isAoE {
                let radius = max(1, spell.range / 2)
                let affectedHexes = coord.hexesInRange(radius)
                for hex in affectedHexes {
                    if let enemy = enemyAt(hex) {
                        enemy.stun(turns: 2)
                        let screenPos = worldToScreen(hex)
                        showStatusText("Stunned!", at: screenPos, color: .yellow)
                    }
                }
            } else if let enemy = enemyAt(coord) {
                enemy.stun(turns: 2)
                let screenPos = worldToScreen(coord)
                showStatusText("Stunned!", at: screenPos, color: .yellow)
            }
            refreshEnemyStunVisuals()
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

        // Check for stealth detection (radius scales with grid size)
        let detectionRadius = max(0, GameScene.visibleRange - 1)
        if currentChallenge?.type == .stealth && detectionRadius > 0 {
            for enemy in activeEnemies where enemy.isAlive {
                if position.distance(to: enemy.position) <= detectionRadius {
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

    private func dispelDarknessAt(_ position: HexCoord) -> Bool {
        for (id, var element) in interactiveElements {
            // Dispel darkness within range of the spell
            if position.distance(to: element.position) <= 3 {
                if case .darkness(let radius, let dispelled) = element.type, !dispelled {
                    element.type = .darkness(radius: radius, dispelled: true)
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

                    // Reveal enemies that were hidden in this darkness zone
                    for enemy in activeEnemies where enemy.isAlive {
                        if enemy.position.distance(to: element.position) <= radius {
                            let wasHidden = (enemySprites[enemy.id]?.alpha ?? 1.0) < 1.0
                            updateEnemyDarknessVisibility(enemy)
                            if wasHidden {
                                let screenPos = worldToScreen(enemy.position)
                                showStatusText("Revealed!", at: screenPos, color: .yellow)
                            }
                        }
                    }

                    return true
                }
            }
        }
        return false
    }

    private func isInActiveDarkness(_ position: HexCoord) -> Bool {
        for (_, element) in interactiveElements {
            if case .darkness(let radius, let dispelled) = element.type, !dispelled {
                if position.distance(to: element.position) <= radius {
                    return true
                }
            }
        }
        return false
    }

    private func updateEnemyDarknessVisibility(_ enemy: Enemy) {
        guard let sprite = enemySprites[enemy.id] else { return }
        let inDarkness = isInActiveDarkness(enemy.position)

        if inDarkness {
            sprite.alpha = 0.15
            if let hpLabel = sprite.children.compactMap({ $0 as? SKLabelNode }).first {
                hpLabel.text = "?"
            }
        } else {
            sprite.alpha = 1.0
            if let hpLabel = sprite.children.compactMap({ $0 as? SKLabelNode }).first {
                let isStealth = currentChallenge?.type == .stealth
                hpLabel.text = isStealth ? "∞" : "\(enemy.hp)"
            }
        }
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
                        // Update HP label on sprite
                        if let sprite = interactiveSprites[id],
                           let hpLabel = sprite.childNode(withName: "hpLabel") as? SKLabelNode {
                            hpLabel.text = "\(hp)"
                        }
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
            showSpellIconAnimation(spell: spell, at: worldScreenPos)

        case .healing(let amount):
            // Show healing at player position
            let playerScreenPos = CGPoint(x: size.width / 2, y: size.height / 2)
            showHealingNumber(amount, at: playerScreenPos)
            showSpellIconAnimation(spell: spell, at: playerScreenPos)

        case .activatedPassive:
            let playerScreenPos = CGPoint(x: size.width / 2, y: size.height / 2)
            showStatusText("Activated!", at: playerScreenPos, color: .cyan)
            showSpellIconAnimation(spell: spell, at: playerScreenPos)

        case .deactivatedPassive:
            let playerScreenPos = CGPoint(x: size.width / 2, y: size.height / 2)
            showStatusText("Deactivated", at: playerScreenPos, color: .gray)

        case .areaEffect(let center, let radius, _):
            let affectedHexes = center.hexesInRange(radius)
            showSpellIconAnimation(spell: spell, at: worldToScreen(center))
            for hex in affectedHexes where hex != center {
                showSpellFlash(color: .orange, at: worldToScreen(hex))
            }

        default:
            showSpellIconAnimation(spell: spell, at: worldScreenPos)
        }

        // Trigger enemy turns after casting any spell (including passives like Blur)
        if isTeam {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.markActivePlayerActed()
            }
        } else {
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

    private func showSpellIconAnimation(spell: Spell, at position: CGPoint) {
        // Determine color based on spell type
        let color: SKColor
        if spell.isOffensive && spell.isDefensive {
            color = SKColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0)  // Gold - hybrid
        } else if spell.isOffensive && spell.causesParalysis {
            color = SKColor(red: 0.7, green: 0.3, blue: 0.9, alpha: 1.0)  // Purple - damage + control
        } else if spell.isOffensive {
            color = SKColor(red: 1.0, green: 0.4, blue: 0.3, alpha: 1.0)  // Red - damage
        } else if spell.isDefensive {
            color = SKColor(red: 0.3, green: 1.0, blue: 0.4, alpha: 1.0)  // Green - healing
        } else {
            color = SKColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0)  // Blue - utility
        }

        let icon = SpellIcons.createIcon(for: spell.id, size: 30, color: color)
        icon.position = position
        icon.zPosition = 48
        icon.setScale(0.5)

        // Subtle glow behind icon
        let glow = SKShapeNode(circleOfRadius: 18)
        glow.fillColor = color.withAlphaComponent(0.3)
        glow.strokeColor = .clear
        glow.zPosition = -1
        icon.addChild(glow)

        effectLayer.addChild(icon)

        let scaleUp = SKAction.scale(to: 1.5, duration: 0.15)
        scaleUp.timingMode = .easeOut
        let hold = SKAction.wait(forDuration: 0.25)
        let fadeAndShrink = SKAction.group([
            SKAction.fadeOut(withDuration: 0.4),
            SKAction.scale(to: 1.0, duration: 0.4)
        ])
        let remove = SKAction.removeFromParent()

        icon.run(SKAction.sequence([scaleUp, hold, fadeAndShrink, remove]))
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

    // MARK: - Spell Tooltip

    private func showSpellTooltip(_ spell: Spell) {
        dismissSpellTooltip()

        let tooltip = SKNode()
        tooltip.zPosition = 150

        // Build stats line
        var statsText = "Range: \(spell.range)"
        if spell.offenseDie > 0 {
            statsText += "  Dmg: d\(spell.offenseDie)"
        }
        if spell.defenseDie > 0 {
            statsText += "  Heal: d\(spell.defenseDie)"
        }
        if spell.isAoE {
            statsText += "  AoE"
        }
        if spell.causesParalysis {
            statsText += "  Stun"
        }
        if spell.producesLight {
            statsText += "  Light"
        }
        let showMana = !isBlitz
        let manaText = spell.manaCost < 0 ? "Mana: +\(abs(spell.manaCost))" : spell.manaCost > 0 ? "Mana: -\(spell.manaCost)" : "Mana: 0"

        // Measure text to size the card
        let padding: CGFloat = 12
        let lineSpacing: CGFloat = 4
        let nameFontSize: CGFloat = 16
        let bodyFontSize: CGFloat = 12

        // Create labels to measure
        let nameLabel = SKLabelNode(fontNamed: "Cochin-Bold")
        nameLabel.text = spell.name
        nameLabel.fontSize = nameFontSize
        nameLabel.fontColor = .white
        nameLabel.horizontalAlignmentMode = .center
        nameLabel.verticalAlignmentMode = .top

        let descLabel = SKLabelNode(fontNamed: "Cochin")
        descLabel.text = spell.description
        descLabel.fontSize = bodyFontSize
        descLabel.fontColor = SKColor(white: 0.85, alpha: 1.0)
        descLabel.horizontalAlignmentMode = .center
        descLabel.verticalAlignmentMode = .top

        let statsLabel = SKLabelNode(fontNamed: "Cochin")
        statsLabel.text = statsText
        statsLabel.fontSize = bodyFontSize
        statsLabel.fontColor = SKColor(white: 0.7, alpha: 1.0)
        statsLabel.horizontalAlignmentMode = .center
        statsLabel.verticalAlignmentMode = .top

        var manaLabel: SKLabelNode?
        if showMana {
            let ml = SKLabelNode(fontNamed: "Cochin-Bold")
            ml.text = manaText
            ml.fontSize = bodyFontSize
            ml.fontColor = spell.manaCost < 0
                ? SKColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1.0)
                : SKColor(red: 0.9, green: 0.5, blue: 0.3, alpha: 1.0)
            ml.horizontalAlignmentMode = .center
            ml.verticalAlignmentMode = .top
            manaLabel = ml
        }

        // Calculate card dimensions
        let manaLineWidth = manaLabel?.frame.width ?? 0
        let maxTextWidth = max(
            nameLabel.frame.width,
            max(descLabel.frame.width, max(statsLabel.frame.width, manaLineWidth))
        )
        let cardWidth = maxTextWidth + padding * 2
        let lineCount: CGFloat = showMana ? 3 : 2  // desc + stats (+ mana)
        let spacingCount: CGFloat = showMana ? 4 : 3
        let cardHeight = nameFontSize + bodyFontSize * lineCount + lineSpacing * spacingCount + padding * 2

        // Background card
        let bg = SKShapeNode(rectOf: CGSize(width: cardWidth, height: cardHeight), cornerRadius: 8)
        bg.fillColor = SKColor(white: 0.1, alpha: 0.95)
        bg.strokeColor = SKColor(white: 0.4, alpha: 1.0)
        bg.lineWidth = 1.5
        tooltip.addChild(bg)

        // Position labels inside card
        var yPos = cardHeight / 2 - padding
        nameLabel.position = CGPoint(x: 0, y: yPos)
        tooltip.addChild(nameLabel)

        yPos -= nameFontSize + lineSpacing
        descLabel.position = CGPoint(x: 0, y: yPos)
        tooltip.addChild(descLabel)

        yPos -= bodyFontSize + lineSpacing
        statsLabel.position = CGPoint(x: 0, y: yPos)
        tooltip.addChild(statsLabel)

        if let ml = manaLabel {
            yPos -= bodyFontSize + lineSpacing
            ml.position = CGPoint(x: 0, y: yPos)
            tooltip.addChild(ml)
        }

        // Position tooltip above spell bar
        let barY = spellBar?.position.y ?? 50
        tooltip.position = CGPoint(x: size.width / 2, y: barY + 80)
        tooltip.alpha = 0

        uiLayer.addChild(tooltip)
        spellTooltip = tooltip

        // Fade in
        tooltip.run(SKAction.fadeIn(withDuration: 0.15))
    }

    private func dismissSpellTooltip() {
        guard let tooltip = spellTooltip else { return }
        tooltip.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.1),
            SKAction.removeFromParent()
        ]))
        spellTooltip = nil
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
        // Rainbow mode handles zone completion in rainbowAfterPlayerAction
        guard !isRainbow else { return }
        // Team mode handles completion per-player via checkTeamChallengeCompletion
        if isTeam { checkTeamChallengeCompletion(); return }
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
            // In hardcore, also fail if time runs out
            if challengeTimeLimit > 0 && challengeTimer >= challengeTimeLimit {
                showStatusText("Time's up!", at: CGPoint(x: size.width / 2, y: size.height / 2), color: .red)
                player.takeDamage(1)
                if isBlitz {
                    blitzTimer -= BlitzConfig.penaltyPerDamage
                    if blitzTimer <= 0 { showGameOver(); return }
                } else if !player.isAlive { showGameOver(); return }
                challengeCompleted = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    self?.challengeCompleted = false
                    self?.generateNewChallenge()
                }
                return
            }
            // Fail if player was detected — lose 1 HP and advance
            if playerDetected {
                showStatusText("Detected!", at: CGPoint(x: size.width / 2, y: size.height / 2), color: .red)
                player.takeDamage(1)
                if isBlitz {
                    blitzTimer -= BlitzConfig.penaltyPerDamage
                    if blitzTimer <= 0 { showGameOver(); return }
                } else if !player.isAlive { showGameOver(); return }
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
                if isBlitz {
                    blitzTimer -= BlitzConfig.penaltyPerDamage
                    if blitzTimer <= 0 { showGameOver(); return }
                } else if !player.isAlive { showGameOver(); return }
                challengeCompleted = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    self?.challengeCompleted = false
                    self?.generateNewChallenge()
                }
                return
            }
            isComplete = checkAllTargetsReached()

        case .puzzle:
            // Light-only puzzles fail if time runs out
            if challengeTimeLimit > 0 && challengeTimer >= challengeTimeLimit {
                showStatusText("Time's up!", at: CGPoint(x: size.width / 2, y: size.height / 2), color: .red)
                player.takeDamage(1)
                if isBlitz {
                    blitzTimer -= BlitzConfig.penaltyPerDamage
                    if blitzTimer <= 0 { showGameOver(); return }
                } else if !player.isAlive { showGameOver(); return }
                challengeCompleted = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    self?.challengeCompleted = false
                    self?.generateNewChallenge()
                }
                return
            }
            isComplete = checkPuzzleSolved()
        }

        if isComplete {
            challengeCompleted = true
            GameManager.shared.completeChallenge()
            scoreLabel?.text = "Score: \(GameManager.shared.challengesCompleted)"
            objectiveLabel?.text = "Victory!"

            if isBlitz {
                blitzTimer += BlitzConfig.bonusPerChallenge
                let bonusText = String(format: "+%.1fs", BlitzConfig.bonusPerChallenge)
                showStatusText(bonusText, at: CGPoint(x: size.width / 2, y: size.height / 2 + 40), color: SKColor(red: 0.9, green: 0.75, blue: 0.25, alpha: 1.0))
            }

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
                // Check if player is on the target hex
                if player.position == element.position {
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
                if isBlitz { blitzTimer -= BlitzConfig.penaltyPerDamage * Double(damage) }
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
                        if isBlitz { blitzTimer -= BlitzConfig.penaltyPerDamage * Double(damage) }
                        checkPlayerDeath()
                        let screenPos = CGPoint(x: size.width / 2, y: size.height / 2)
                        showDamageNumber(damage, at: screenPos)
                    }
                } else if type == .summon {
                    let minion = Enemy(hp: 1, damage: damage, behavior: .aggressive, position: center)
                    spawnEnemy(minion)
                    // "Summoned!" floats above the summoner
                    if let sprite = enemySprites[enemy.id] {
                        let worldPos = CGPoint(x: sprite.position.x + entityLayer.position.x,
                                               y: sprite.position.y + entityLayer.position.y)
                        showStatusText("Summoned!", at: worldPos, color: SKColor(red: 0.15, green: 0.55, blue: 0.4, alpha: 1.0))
                    }
                    // Dark mint flash at the minion spawn hex
                    let minionLocal = center - player.position
                    let minionScreen = hexLayout.hexToScreen(minionLocal)
                    let minionWorld = CGPoint(x: minionScreen.x + entityLayer.position.x,
                                             y: minionScreen.y + entityLayer.position.y)
                    showSpellFlash(color: SKColor(red: 0.15, green: 0.55, blue: 0.4, alpha: 1.0), at: minionWorld)
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

        // Rainbow mode: advance lava, check zone completion, etc.
        rainbowAfterPlayerAction()
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

        // Hide merged enemy if still in darkness
        updateEnemyDarknessVisibility(enemy)

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
        if isBlitz {
            if blitzTimer <= 0 { showGameOver() }
        } else if !player.isAlive {
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

        if isRainbow {
            let scoreDisplay = SKLabelNode(fontNamed: "Cochin-Bold")
            scoreDisplay.text = "Zones Cleared: \(zonesCleared)"
            scoreDisplay.fontSize = 22
            scoreDisplay.fontColor = .yellow
            scoreDisplay.position = CGPoint(x: size.width / 2, y: size.height / 2)
            scoreDisplay.zPosition = 201
            addChild(scoreDisplay)
        }

        let restartLabel = SKLabelNode(fontNamed: "Cochin")
        restartLabel.text = isRainbow ? "Tap to return to menu" : "Tap to return to spell selection"
        restartLabel.fontSize = 18
        restartLabel.fontColor = .white
        restartLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - (isRainbow ? 40 : 20))
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
            // In team mode, movement doesn't trigger enemy turns (only spell casts do)
            if !isTeam {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.processEnemyTurns()
                }
            }
        }
        if player.isMoving {
            playerWasMoving = true
        }

        // Update spell bar (for mana costs, etc.) — skip in Blitz (all spells always enabled)
        if !isBlitz {
            spellBar?.updateSpellStates(currentMana: player.mana)
        }

        // Update blitz countdown timer
        if isBlitz && !isGameOver {
            blitzTimer -= dt
            blitzTimerLabel?.text = String(format: "%.1fs", max(0, blitzTimer))
            if blitzTimer <= 0 {
                showGameOver()
                lastUpdateTime = currentTime
                return
            }
        }

        // Update challenge timer for timed/stealth/light-only-puzzle challenges
        let isTimed = currentChallenge?.type == .timed || currentChallenge?.type == .stealth
            || challengeTimeLimit > 0  // Covers light-only puzzles (timer set during setup)
        if isTimed && challengeTimeLimit > 0 && !challengeCompleted {
            challengeTimer += dt
            let remaining = max(0, challengeTimeLimit - challengeTimer)
            let desc = currentChallenge?.description ?? ""
            objectiveLabel?.text = String(format: "%@ (%.1fs)", desc, remaining)
            checkChallengeCompletion()
        }

        lastUpdateTime = currentTime
    }
}
