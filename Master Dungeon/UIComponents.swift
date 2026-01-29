//
//  UIComponents.swift
//  Master Dungeon
//
//  UI elements: Mana bar, HP display, Spell bar
//

import SpriteKit

// MARK: - Mana Display (Discrete Crystals)

class ManaDisplay: SKNode {
    private let maxMana = Player.maxMana
    private var currentMana = Player.maxMana
    private var crystalNodes: [SKNode] = []

    private let crystalSize: CGFloat = 20
    private let crystalSpacing: CGFloat = 4

    init(width: CGFloat = 0) {
        // Width parameter kept for compatibility but not used (discrete crystals)
        super.init()
        createCrystals()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func createCrystals() {
        // Center-align: crystals centered around anchor point
        let totalWidth = CGFloat(maxMana) * crystalSize + CGFloat(maxMana - 1) * crystalSpacing
        let startX = -totalWidth / 2 + crystalSize / 2
        for i in 0..<maxMana {
            let crystal = createCrystalNode(filled: true)
            crystal.position = CGPoint(x: startX + CGFloat(i) * (crystalSize + crystalSpacing), y: 0)
            addChild(crystal)
            crystalNodes.append(crystal)
        }
    }

    private func createCrystalNode(filled: Bool) -> SKNode {
        let container = SKNode()

        // Diamond/crystal shape
        let crystalPath = CGMutablePath()
        let size = crystalSize / 2

        // Diamond shape pointing up
        crystalPath.move(to: CGPoint(x: 0, y: size))           // Top
        crystalPath.addLine(to: CGPoint(x: size * 0.7, y: 0))  // Right
        crystalPath.addLine(to: CGPoint(x: 0, y: -size))       // Bottom
        crystalPath.addLine(to: CGPoint(x: -size * 0.7, y: 0)) // Left
        crystalPath.closeSubpath()

        let crystalShape = SKShapeNode(path: crystalPath)
        crystalShape.fillColor = filled ? SKColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1.0) : SKColor(white: 0.3, alpha: 0.5)
        crystalShape.strokeColor = filled ? SKColor(red: 0.1, green: 0.3, blue: 0.7, alpha: 1.0) : SKColor(white: 0.2, alpha: 0.5)
        crystalShape.lineWidth = 1.5

        // Add inner highlight for filled crystals
        if filled {
            let highlightPath = CGMutablePath()
            let hSize = size * 0.4
            highlightPath.move(to: CGPoint(x: 0, y: hSize))
            highlightPath.addLine(to: CGPoint(x: hSize * 0.5, y: 0))
            highlightPath.addLine(to: CGPoint(x: 0, y: -hSize * 0.3))
            highlightPath.addLine(to: CGPoint(x: -hSize * 0.5, y: 0))
            highlightPath.closeSubpath()

            let highlight = SKShapeNode(path: highlightPath)
            highlight.fillColor = SKColor(red: 0.5, green: 0.8, blue: 1.0, alpha: 0.6)
            highlight.strokeColor = .clear
            highlight.position = CGPoint(x: -size * 0.1, y: size * 0.15)
            container.addChild(highlight)
        }

        container.addChild(crystalShape)
        return container
    }

    func setMana(_ mana: Int) {
        currentMana = max(0, min(maxMana, mana))

        // Update crystal visuals
        for (index, crystalNode) in crystalNodes.enumerated() {
            crystalNode.removeAllChildren()

            let filled = index < currentMana
            let newCrystal = createCrystalNode(filled: filled)
            for child in newCrystal.children {
                crystalNode.addChild(child.copy() as! SKNode)
            }

            // Animate mana loss
            if !filled && index == currentMana {
                let scale = SKAction.sequence([
                    SKAction.scale(to: 1.3, duration: 0.1),
                    SKAction.scale(to: 1.0, duration: 0.1)
                ])
                crystalNode.run(scale)
            }
        }
    }
}

// Keep ManaBar as alias for compatibility
typealias ManaBar = ManaDisplay

// MARK: - HP Display

class HPDisplay: SKNode {
    private let maxHP = Player.maxHP
    private var currentHP = Player.maxHP
    private var heartNodes: [SKNode] = []

    private let heartSize: CGFloat = 24
    private let heartSpacing: CGFloat = 4

    override init() {
        super.init()
        createHearts()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func createHearts() {
        for i in 0..<maxHP {
            let heart = createHeartNode(filled: true)
            heart.position = CGPoint(x: CGFloat(i) * (heartSize + heartSpacing), y: 0)
            addChild(heart)
            heartNodes.append(heart)
        }
    }

    private func createHeartNode(filled: Bool) -> SKNode {
        let container = SKNode()

        // Heart shape - right-side up (point at bottom, lobes at top)
        let heartPath = CGMutablePath()
        let s = heartSize / 2

        // Start at bottom point, draw right-side up heart
        heartPath.move(to: CGPoint(x: 0, y: -s))  // Bottom tip

        // Left side: curve up to left lobe
        heartPath.addCurve(
            to: CGPoint(x: -s, y: s * 0.3),       // Left lobe peak
            control1: CGPoint(x: -s * 0.5, y: -s),
            control2: CGPoint(x: -s, y: -s * 0.2)
        )

        // Top left: curve to center dip
        heartPath.addCurve(
            to: CGPoint(x: 0, y: 0),              // Center dip
            control1: CGPoint(x: -s, y: s * 0.8),
            control2: CGPoint(x: -s * 0.3, y: s * 0.3)
        )

        // Top right: curve to right lobe
        heartPath.addCurve(
            to: CGPoint(x: s, y: s * 0.3),        // Right lobe peak
            control1: CGPoint(x: s * 0.3, y: s * 0.3),
            control2: CGPoint(x: s, y: s * 0.8)
        )

        // Right side: curve back to bottom point
        heartPath.addCurve(
            to: CGPoint(x: 0, y: -s),             // Back to bottom tip
            control1: CGPoint(x: s, y: -s * 0.2),
            control2: CGPoint(x: s * 0.5, y: -s)
        )
        heartPath.closeSubpath()

        let heartShape = SKShapeNode(path: heartPath)
        heartShape.fillColor = filled ? SKColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0) : SKColor(white: 0.3, alpha: 0.5)
        heartShape.strokeColor = filled ? SKColor(red: 0.6, green: 0.1, blue: 0.1, alpha: 1.0) : SKColor(white: 0.2, alpha: 0.5)
        heartShape.lineWidth = 1.5

        container.addChild(heartShape)
        return container
    }

    func setHP(_ hp: Int) {
        currentHP = max(0, min(maxHP, hp))

        // Update heart visuals
        for (index, heartNode) in heartNodes.enumerated() {
            heartNode.removeAllChildren()

            let filled = index < currentHP
            let heart = createHeartNode(filled: filled).children.first!.copy() as! SKShapeNode
            heartNode.addChild(heart)

            // Animate damage
            if !filled && index == currentHP {
                let scale = SKAction.sequence([
                    SKAction.scale(to: 1.3, duration: 0.1),
                    SKAction.scale(to: 1.0, duration: 0.1)
                ])
                heartNode.run(scale)
            }
        }
    }
}

// MARK: - Spell Bar

class SpellBar: SKNode {
    private var spells: [Spell]
    private var spellSlots: [SpellSlot] = []
    private let slotSize: CGFloat
    private let slotSpacing: CGFloat = 8

    private var selectedIndex: Int? = nil

    var onSpellSelected: ((Spell?) -> Void)?

    init(spells: [Spell], slotSize: CGFloat = 60) {
        self.spells = spells
        self.slotSize = slotSize
        super.init()
        createSlots()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func createSlots() {
        let totalWidth = CGFloat(spells.count) * slotSize + CGFloat(spells.count - 1) * slotSpacing
        let startX = -totalWidth / 2 + slotSize / 2

        for (index, spell) in spells.enumerated() {
            let slot = SpellSlot(spell: spell, size: slotSize)
            slot.position = CGPoint(x: startX + CGFloat(index) * (slotSize + slotSpacing), y: 0)
            addChild(slot)
            spellSlots.append(slot)
        }
    }

    func handleTouch(at point: CGPoint) {
        for (index, slot) in spellSlots.enumerated() {
            let slotFrame = CGRect(
                x: slot.position.x - slotSize / 2,
                y: slot.position.y - slotSize / 2,
                width: slotSize,
                height: slotSize
            )

            if slotFrame.contains(point) {
                if selectedIndex == index {
                    // Deselect
                    deselectAll()
                    onSpellSelected?(nil)
                } else {
                    // Select new spell
                    deselectAll()
                    selectedIndex = index
                    slot.setSelected(true)
                    onSpellSelected?(spells[index])
                }
                return
            }
        }
    }

    func deselectAll() {
        selectedIndex = nil
        for slot in spellSlots {
            slot.setSelected(false)
        }
    }

    func updateSpellStates(currentMana: Int) {
        for (index, slot) in spellSlots.enumerated() {
            let canCast = currentMana >= spells[index].manaCost
            slot.setEnabled(canCast)
        }
    }

    override func contains(_ point: CGPoint) -> Bool {
        guard !spells.isEmpty else { return false }
        let totalWidth = CGFloat(spells.count) * slotSize + CGFloat(max(0, spells.count - 1)) * slotSpacing
        let frame = CGRect(
            x: -totalWidth / 2,
            y: -slotSize / 2,
            width: totalWidth,
            height: slotSize
        )
        return frame.contains(point)
    }
}

// MARK: - Spell Slot

class SpellSlot: SKNode {
    private let spell: Spell
    private let size: CGFloat

    private let background: SKShapeNode
    private let iconLabel: SKLabelNode
    private let costLabel: SKLabelNode
    private let selectionBorder: SKShapeNode

    private var isEnabled: Bool = true
    private var isSelected: Bool = false

    init(spell: Spell, size: CGFloat) {
        self.spell = spell
        self.size = size

        // Background
        background = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: 8)
        background.fillColor = SKColor(white: 0.15, alpha: 0.9)
        background.strokeColor = SKColor(white: 0.3, alpha: 1.0)
        background.lineWidth = 2

        // Spell icon (using first letter for now)
        iconLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        iconLabel.fontSize = size * 0.4
        iconLabel.fontColor = SpellSlot.spellColor(for: spell)
        iconLabel.verticalAlignmentMode = .center
        iconLabel.text = String(spell.name.prefix(2))

        // Mana cost
        costLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        costLabel.fontSize = 12
        costLabel.fontColor = SKColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 1.0)
        costLabel.verticalAlignmentMode = .top
        costLabel.horizontalAlignmentMode = .right
        costLabel.position = CGPoint(x: size / 2 - 4, y: size / 2 - 4)
        costLabel.text = "\(spell.manaCost)"

        // Selection border
        selectionBorder = SKShapeNode(rectOf: CGSize(width: size + 4, height: size + 4), cornerRadius: 10)
        selectionBorder.fillColor = .clear
        selectionBorder.strokeColor = SKColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0)
        selectionBorder.lineWidth = 3
        selectionBorder.isHidden = true

        super.init()

        addChild(background)
        addChild(iconLabel)
        addChild(costLabel)
        addChild(selectionBorder)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func spellColor(for spell: Spell) -> SKColor {
        if spell.isOffensive {
            return SKColor(red: 1.0, green: 0.4, blue: 0.3, alpha: 1.0)
        } else if spell.isDefensive {
            return SKColor(red: 0.3, green: 1.0, blue: 0.4, alpha: 1.0)
        } else {
            return SKColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0)
        }
    }

    func setSelected(_ selected: Bool) {
        isSelected = selected
        selectionBorder.isHidden = !selected

        if selected {
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.1, duration: 0.1),
                SKAction.scale(to: 1.0, duration: 0.1)
            ])
            run(pulse)
        }
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        alpha = enabled ? 1.0 : 0.4
    }
}
