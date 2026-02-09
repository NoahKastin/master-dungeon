//
//  SpellSelectionScene.swift
//  Master Dungeon
//
//  Scene where players select their spell loadout (up to 50 mana total).
//

import SpriteKit

class SpellSelectionScene: SKScene {

    // MARK: - Properties
    private var loadout = SpellLoadout()
    private var spellCards: [SpellCard] = []
    private var selectedCards: Set<String> = []

    private var scrollNode: SKCropNode!
    private var contentNode: SKNode!

    private var manaLabel: SKLabelNode!
    private var selectedLabel: SKLabelNode!
    private var startButton: SKShapeNode!
    private var startButtonLabel: SKLabelNode!

    private var cardWidth: CGFloat = 150
    private var cardHeight: CGFloat = 180
    private let cardSpacing: CGFloat = 10
    private var cardsPerRow: Int = 2

    private var scrollOffset: CGFloat = 0
    private var maxScroll: CGFloat = 0
    private var lastTouchY: CGFloat = 0
    private var isDragging: Bool = false
    private var dragStartY: CGFloat = 0

    private var headerHeight: CGFloat = 130
    private var footerHeight: CGFloat = 100
    private var backButton: SKNode?

    // MARK: - Scene Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(white: 0.08, alpha: 1.0)

        // Calculate layout based on screen size
        calculateLayout()

        setupUI()
        setupSpellGrid()
    }

    private func calculateLayout() {
        // Determine cards per row based on screen width
        let availableWidth = size.width - 40  // 20px margin on each side

        if availableWidth >= 500 {
            cardsPerRow = 3
            cardWidth = (availableWidth - CGFloat(cardsPerRow - 1) * cardSpacing) / CGFloat(cardsPerRow)
        } else {
            cardsPerRow = 2
            cardWidth = (availableWidth - CGFloat(cardsPerRow - 1) * cardSpacing) / CGFloat(cardsPerRow)
        }

        cardHeight = cardWidth * 1.2  // Maintain aspect ratio
    }

    // MARK: - Setup

    private func setupUI() {
        // Use safe area insets, with fallback for Dynamic Island/notch iPhones when not yet available
        let rawSafeTop = view?.safeAreaInsets.top ?? 0
        let safeTop = rawSafeTop > 0 ? rawSafeTop : 59  // 59 is typical for Dynamic Island
        let rawSafeBottom = view?.safeAreaInsets.bottom ?? 0
        let safeBottom = rawSafeBottom > 0 ? rawSafeBottom : 34  // 34 is typical home indicator

        // Title
        let titleLabel = SKLabelNode(fontNamed: "Cochin-Bold")
        titleLabel.text = "Choose Your Spells"
        titleLabel.fontSize = 24
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height - safeTop - 35)
        titleLabel.zPosition = 100
        addChild(titleLabel)

        // Subtitle
        let subtitleLabel = SKLabelNode(fontNamed: "Cochin")
        subtitleLabel.text = GameManager.shared.gameMode == .blitz
            ? "Select up to 3 spells"
            : "Select up to 3 spells (Pass is always available)"
        subtitleLabel.fontSize = 14
        subtitleLabel.fontColor = SKColor(white: 0.7, alpha: 1.0)
        subtitleLabel.position = CGPoint(x: size.width / 2, y: size.height - safeTop - 55)
        subtitleLabel.zPosition = 100
        addChild(subtitleLabel)

        // Mana counter (hidden in Blitz — no mana system)
        manaLabel = SKLabelNode(fontNamed: "Cochin-Bold")
        manaLabel.fontSize = 18
        manaLabel.fontColor = SKColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 1.0)
        manaLabel.horizontalAlignmentMode = .left
        manaLabel.position = CGPoint(x: 20, y: size.height - safeTop - 85)
        manaLabel.zPosition = 100
        updateManaLabel()
        if GameManager.shared.gameMode != .blitz {
            addChild(manaLabel)
        }

        // Selected count
        selectedLabel = SKLabelNode(fontNamed: "Cochin")
        selectedLabel.fontSize = 14
        selectedLabel.fontColor = SKColor(white: 0.7, alpha: 1.0)
        selectedLabel.horizontalAlignmentMode = .right
        selectedLabel.position = CGPoint(x: size.width - 20, y: size.height - safeTop - 85)
        selectedLabel.zPosition = 100
        updateSelectedLabel()
        addChild(selectedLabel)

        // Back button (top left)
        let backContainer = SKNode()
        backContainer.position = CGPoint(x: 50, y: size.height - safeTop - 35)
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

        addChild(backContainer)
        backButton = backContainer

        headerHeight = safeTop + 100

        // Start button
        let buttonWidth: CGFloat = 200
        let buttonHeight: CGFloat = 50

        startButton = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: buttonHeight), cornerRadius: 12)
        startButton.fillColor = SKColor(red: 0.2, green: 0.6, blue: 0.3, alpha: 1.0)
        startButton.strokeColor = SKColor(red: 0.3, green: 0.8, blue: 0.4, alpha: 1.0)
        startButton.lineWidth = 2
        startButton.position = CGPoint(x: size.width / 2, y: safeBottom + 50)
        startButton.alpha = 0.5
        startButton.zPosition = 100
        addChild(startButton)

        startButtonLabel = SKLabelNode(fontNamed: "Cochin-Bold")
        startButtonLabel.text = "Start Adventure"
        startButtonLabel.fontSize = 18
        startButtonLabel.fontColor = .white
        startButtonLabel.verticalAlignmentMode = .center
        startButtonLabel.position = startButton.position
        startButtonLabel.zPosition = 101
        addChild(startButtonLabel)

        footerHeight = safeBottom + 100

        // Scroll area with crop node for clipping
        let scrollAreaHeight = size.height - headerHeight - footerHeight

        scrollNode = SKCropNode()
        scrollNode.position = CGPoint(x: 0, y: footerHeight)
        scrollNode.zPosition = 10

        // Mask to clip content
        let maskNode = SKShapeNode(rectOf: CGSize(width: size.width, height: scrollAreaHeight))
        maskNode.fillColor = .white
        maskNode.position = CGPoint(x: size.width / 2, y: scrollAreaHeight / 2)
        scrollNode.maskNode = maskNode

        addChild(scrollNode)

        contentNode = SKNode()
        contentNode.position = CGPoint(x: 0, y: 0)
        scrollNode.addChild(contentNode)
    }

    private func setupSpellGrid() {
        let isBlitz = GameManager.shared.gameMode == .blitz
        var spells: [Spell]

        if isBlitz {
            // Blitz mode: no Pass, use dedicated Blitz spell list
            spells = SpellData.blitzSpells
        } else {
            // Put Pass first, then other spells sorted by mana cost
            spells = [SpellData.passSpell]
            let hardcoreSpellIDs: Set<String> = [
                "shocking-grasp", "burning-hands", "magic-missile",
                "acid-splash", "black-tentacles", "blight", "chill-touch", "sleet-storm"
            ]
            let availableSpells = SpellData.allSpells.filter { spell in
                spell.id != "pass" && (GameManager.shared.gameMode == .normal || hardcoreSpellIDs.contains(spell.id))
            }
            spells.append(contentsOf: availableSpells.sorted { $0.manaCost < $1.manaCost })
        }

        let scrollAreaHeight = size.height - headerHeight - footerHeight

        let totalWidth = CGFloat(cardsPerRow) * cardWidth + CGFloat(cardsPerRow - 1) * cardSpacing
        let startX = (size.width - totalWidth) / 2 + cardWidth / 2

        let rowCount = (spells.count + cardsPerRow - 1) / cardsPerRow
        let contentHeight = CGFloat(rowCount) * (cardHeight + cardSpacing) + cardSpacing

        // Start cards from top of scroll area
        let topY = scrollAreaHeight - cardHeight / 2 - cardSpacing

        for (index, spell) in spells.enumerated() {
            let row = index / cardsPerRow
            let col = index % cardsPerRow

            let x = startX + CGFloat(col) * (cardWidth + cardSpacing)
            let y = topY - CGFloat(row) * (cardHeight + cardSpacing)

            let card = SpellCard(spell: spell, size: CGSize(width: cardWidth, height: cardHeight))
            card.position = CGPoint(x: x, y: y)
            contentNode.addChild(card)
            spellCards.append(card)

            // Auto-select Pass and mark it as locked
            if spell.id == "pass" {
                _ = loadout.addSpell(spell)
                selectedCards.insert(spell.id)
                card.setSelected(true)
                card.setLocked(true)
            }
        }

        // Calculate max scroll (how far down we can scroll)
        maxScroll = max(0, contentHeight - scrollAreaHeight)

        updateManaLabel()
        updateSelectedLabel()
        updateStartButton()
    }

    // MARK: - UI Updates

    private func updateManaLabel() {
        manaLabel.text = "Spells: \(loadout.selectableSpellCount)/\(SpellLoadout.maxSpells)"

        if loadout.selectableSpellCount >= SpellLoadout.maxSpells {
            manaLabel.fontColor = SKColor(red: 1.0, green: 0.5, blue: 0.3, alpha: 1.0)
        } else {
            manaLabel.fontColor = SKColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 1.0)
        }
    }

    private func updateSelectedLabel() {
        let count = loadout.spells.count
        selectedLabel.text = "\(count) \(count == 1 ? "spell" : "spells") selected"
    }

    private func updateStartButton() {
        let canStart = !loadout.spells.isEmpty
        startButton.alpha = canStart ? 1.0 : 0.5
        startButtonLabel.alpha = canStart ? 1.0 : 0.5
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        lastTouchY = location.y
        dragStartY = location.y
        isDragging = false
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let deltaY = location.y - lastTouchY
        lastTouchY = location.y

        // If moved more than 10 points, consider it a drag
        if abs(location.y - dragStartY) > 10 {
            isDragging = true
        }

        if isDragging {
            // Standard scroll: drag finger up → see more content below (scrollOffset increases)
            // contentNode moves up, bringing lower rows into view
            scrollOffset = max(0, min(maxScroll, scrollOffset + deltaY))
            contentNode.position.y = scrollOffset
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }

        // If was dragging, don't register as tap
        if isDragging {
            isDragging = false
            return
        }

        let location = touch.location(in: self)

        // Check back button
        if let back = backButton {
            let backLocation = touch.location(in: back)
            let backBounds = CGRect(x: -40, y: -20, width: 80, height: 40)
            if backBounds.contains(backLocation) {
                returnToMainMenu()
                return
            }
        }

        // Check start button (simple bounds check)
        let buttonBounds = CGRect(
            x: startButton.position.x - 100,
            y: startButton.position.y - 25,
            width: 200,
            height: 50
        )
        if buttonBounds.contains(location) && !loadout.spells.isEmpty {
            startGame()
            return
        }

        // Check if touch is in scroll area
        if location.y > footerHeight && location.y < size.height - headerHeight {
            // Convert to content node coordinates
            let contentLocation = CGPoint(
                x: location.x,
                y: location.y - footerHeight - scrollOffset
            )

            // Check spell cards
            for card in spellCards {
                let cardBounds = CGRect(
                    x: card.position.x - cardWidth / 2,
                    y: card.position.y - cardHeight / 2,
                    width: cardWidth,
                    height: cardHeight
                )

                if cardBounds.contains(contentLocation) {
                    toggleSpell(card)
                    return
                }
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isDragging = false
    }

    private func toggleSpell(_ card: SpellCard) {
        let spell = card.spell

        // Pass cannot be toggled off
        if spell.id == "pass" {
            return
        }

        if selectedCards.contains(spell.id) {
            // Deselect
            loadout.removeSpell(spell)
            selectedCards.remove(spell.id)
            card.setSelected(false)
        } else {
            // Try to select
            if loadout.addSpell(spell) {
                selectedCards.insert(spell.id)
                card.setSelected(true)
            } else {
                // Can't add more spells - show feedback
                card.showCannotAfford()
            }
        }

        updateManaLabel()
        updateSelectedLabel()
        updateStartButton()

        // Update affordability for all cards
        for otherCard in spellCards {
            if !selectedCards.contains(otherCard.spell.id) && otherCard.spell.id != "pass" {
                otherCard.setAffordable(loadout.canAfford(otherCard.spell))
            }
        }
    }

    private func returnToMainMenu() {
        let menuScene = MainMenuScene(size: size)
        menuScene.scaleMode = scaleMode
        let transition = SKTransition.fade(withDuration: 0.5)
        view?.presentScene(menuScene, transition: transition)
    }

    private func startGame() {
        // Store loadout in game manager
        GameManager.shared.currentLoadout = loadout

        // Transition to game scene
        let gameScene = GameScene(size: size)
        gameScene.scaleMode = scaleMode

        let transition = SKTransition.fade(withDuration: 0.5)
        view?.presentScene(gameScene, transition: transition)
    }

}

// MARK: - Spell Card

class SpellCard: SKNode {
    let spell: Spell
    private let cardSize: CGSize

    private let background: SKShapeNode
    private let nameLabel: SKLabelNode
    private let descLabel: SKLabelNode
    private let costLabel: SKLabelNode
    private let selectionOverlay: SKShapeNode
    private let statsLabel: SKLabelNode
    private let iconNode: SKNode

    private var isSelected: Bool = false
    private var isAffordable: Bool = true
    private var isLocked: Bool = false

    init(spell: Spell, size: CGSize) {
        self.spell = spell
        self.cardSize = size

        // Scale factor based on card width (base reference: 150pt card)
        let scale = size.width / 150.0

        // Background
        background = SKShapeNode(rectOf: size, cornerRadius: 10)
        background.fillColor = SKColor(white: 0.12, alpha: 1.0)
        background.strokeColor = SpellCard.cardBorderColor(for: spell)
        background.lineWidth = 2

        // Spell name at top
        nameLabel = SKLabelNode(fontNamed: "Cochin-Bold")
        nameLabel.fontSize = 12 * scale
        nameLabel.fontColor = .white
        nameLabel.verticalAlignmentMode = .top
        nameLabel.horizontalAlignmentMode = .center
        nameLabel.position = CGPoint(x: 0, y: size.height / 2 - 8 * scale)
        nameLabel.text = spell.name

        // Spell description below name (single line for performance)
        descLabel = SKLabelNode(fontNamed: "Cochin")
        descLabel.fontSize = 9 * scale
        descLabel.fontColor = SKColor(white: 0.8, alpha: 1.0)
        descLabel.verticalAlignmentMode = .top
        descLabel.horizontalAlignmentMode = .center
        descLabel.position = CGPoint(x: 0, y: size.height / 2 - 24 * scale)
        descLabel.text = spell.description

        // Spell icon in center
        let iconColor = SpellCard.cardBorderColor(for: spell)
        iconNode = SpellIcons.createIcon(for: spell.id, size: 40 * scale, color: iconColor)
        iconNode.position = CGPoint(x: 0, y: 0)

        // Stats line (range, damage/healing)
        statsLabel = SKLabelNode(fontNamed: "Cochin")
        statsLabel.fontSize = 9 * scale
        statsLabel.fontColor = SpellCard.cardBorderColor(for: spell)
        statsLabel.verticalAlignmentMode = .center
        statsLabel.horizontalAlignmentMode = .center
        statsLabel.position = CGPoint(x: 0, y: -size.height / 2 + 28 * scale)

        var statsText = "Range: \(spell.range)"
        if spell.offenseDie > 0 {
            statsText += " | Dmg: d\(spell.offenseDie)"
        }
        if spell.defenseDie > 0 {
            statsText += " | Heal: d\(spell.defenseDie)"
        }
        if spell.isAoE {
            statsText += " | AoE"
        }
        statsLabel.text = statsText

        // Mana cost at bottom - green for restorers, red for spenders
        costLabel = SKLabelNode(fontNamed: "Cochin-Bold")
        costLabel.text = spell.manaCost < 0 ? "+\(abs(spell.manaCost))" : "\(spell.manaCost)"
        costLabel.fontSize = 16 * scale
        if spell.manaCost < 0 {
            costLabel.fontColor = SKColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1.0)  // Green for restorers
        } else if spell.manaCost > 0 {
            costLabel.fontColor = SKColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0)  // Red for spenders
        } else {
            costLabel.fontColor = SKColor(white: 0.7, alpha: 1.0)  // Gray for free spells
        }
        costLabel.verticalAlignmentMode = .center
        costLabel.position = CGPoint(x: 0, y: -size.height / 2 + 12 * scale)

        // Selection overlay
        selectionOverlay = SKShapeNode(rectOf: CGSize(width: size.width + 4, height: size.height + 4), cornerRadius: 12)
        selectionOverlay.fillColor = SKColor(red: 0.3, green: 0.8, blue: 0.4, alpha: 0.2)
        selectionOverlay.strokeColor = SKColor(red: 0.3, green: 0.9, blue: 0.4, alpha: 1.0)
        selectionOverlay.lineWidth = 3
        selectionOverlay.isHidden = true

        super.init()

        addChild(selectionOverlay)
        addChild(background)
        addChild(nameLabel)
        addChild(descLabel)
        addChild(iconNode)
        addChild(statsLabel)
        // Hide mana cost label in Blitz mode (no mana system)
        if GameManager.shared.gameMode != .blitz {
            addChild(costLabel)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func cardBorderColor(for spell: Spell) -> SKColor {
        if spell.isOffensive && spell.isDefensive {
            return SKColor(red: 0.8, green: 0.6, blue: 0.2, alpha: 1.0)  // Gold - hybrid
        } else if spell.isOffensive && spell.causesParalysis {
            return SKColor(red: 0.5, green: 0.2, blue: 0.7, alpha: 1.0)  // Purple - damage + control
        } else if spell.isOffensive {
            return SKColor(red: 0.8, green: 0.3, blue: 0.2, alpha: 1.0)  // Red - damage
        } else if spell.isDefensive {
            return SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)  // Green - healing
        } else {
            return SKColor(red: 0.3, green: 0.5, blue: 0.8, alpha: 1.0)  // Blue - utility
        }
    }

    func setSelected(_ selected: Bool) {
        isSelected = selected
        selectionOverlay.isHidden = !selected

        if selected {
            background.fillColor = SKColor(red: 0.15, green: 0.25, blue: 0.15, alpha: 1.0)
        } else {
            background.fillColor = SKColor(white: 0.12, alpha: 1.0)
        }
    }

    func setAffordable(_ affordable: Bool) {
        isAffordable = affordable
        alpha = affordable ? 1.0 : 0.4
    }

    func setLocked(_ locked: Bool) {
        isLocked = locked
        if locked {
            // Show a lock indicator or different visual for locked spells
            background.strokeColor = SKColor(white: 0.5, alpha: 1.0)
        }
    }

    func showCannotAfford() {
        let originalColor = background.fillColor
        background.fillColor = SKColor(red: 0.4, green: 0.1, blue: 0.1, alpha: 1.0)

        let wait = SKAction.wait(forDuration: 0.2)
        let restore = SKAction.run { [weak self] in
            self?.background.fillColor = originalColor
        }
        run(SKAction.sequence([wait, restore]))
    }
}
