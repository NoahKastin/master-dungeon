//
//  UIComponents.swift
//  Master Dungeon
//
//  UI elements: Mana bar, HP display, Spell bar
//

import SpriteKit

// MARK: - Mana Display (Split Circle)

class ManaDisplay: SKNode {
    private let maxMana = Player.maxMana
    private var currentMana = Player.maxMana
    private var halfNodes: [SKNode] = []

    private let circleRadius: CGFloat = 12
    private let gapWidth: CGFloat = 3

    init(width: CGFloat = 0) {
        super.init()
        createHalves()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func createHalves() {
        // Left half-circle (index 0) and right half-circle (index 1)
        for i in 0..<maxMana {
            let half = createHalfNode(index: i, filled: true)
            addChild(half)
            halfNodes.append(half)
        }
    }

    private func createHalfNode(index: Int, filled: Bool) -> SKNode {
        let container = SKNode()
        let r = circleRadius
        let halfGap = gapWidth / 2

        let halfPath = CGMutablePath()
        if maxMana == 1 {
            // Full circle for single mana
            halfPath.addArc(center: .zero, radius: r,
                            startAngle: 0, endAngle: .pi * 2, clockwise: false)
            halfPath.closeSubpath()
            container.position = .zero
        } else if index == 0 {
            // Left semicircle: arc from top to bottom going through left
            halfPath.move(to: CGPoint(x: -halfGap, y: r))
            halfPath.addArc(center: CGPoint(x: -halfGap, y: 0), radius: r,
                            startAngle: .pi / 2, endAngle: .pi * 3 / 2, clockwise: false)
            halfPath.closeSubpath()
            container.position = .zero
        } else {
            // Right semicircle: arc from bottom to top going through right
            halfPath.move(to: CGPoint(x: halfGap, y: -r))
            halfPath.addArc(center: CGPoint(x: halfGap, y: 0), radius: r,
                            startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: false)
            halfPath.closeSubpath()
            container.position = .zero
        }

        let shape = SKShapeNode(path: halfPath)
        shape.fillColor = filled
            ? SKColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1.0)
            : SKColor(white: 0.3, alpha: 0.5)
        shape.strokeColor = filled
            ? SKColor(red: 0.1, green: 0.3, blue: 0.7, alpha: 1.0)
            : SKColor(white: 0.2, alpha: 0.5)
        shape.lineWidth = 1.5
        container.addChild(shape)

        // Inner highlight for filled halves
        if filled {
            let hlPath = CGMutablePath()
            let hr = r * 0.55
            if maxMana == 1 {
                // Full circle highlight
                hlPath.addArc(center: CGPoint(x: -r * 0.15, y: r * 0.1), radius: hr,
                              startAngle: 0, endAngle: .pi * 2, clockwise: false)
                hlPath.closeSubpath()
            } else if index == 0 {
                hlPath.addArc(center: CGPoint(x: -halfGap - r * 0.15, y: r * 0.1), radius: hr,
                              startAngle: .pi / 2, endAngle: .pi * 3 / 2, clockwise: false)
                hlPath.closeSubpath()
            } else {
                hlPath.addArc(center: CGPoint(x: halfGap + r * 0.15, y: r * 0.1), radius: hr,
                              startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: false)
                hlPath.closeSubpath()
            }
            let highlight = SKShapeNode(path: hlPath)
            highlight.fillColor = SKColor(red: 0.5, green: 0.8, blue: 1.0, alpha: 0.4)
            highlight.strokeColor = .clear
            container.addChild(highlight)
        }

        return container
    }

    func setMana(_ mana: Int) {
        currentMana = max(0, min(maxMana, mana))

        for (index, halfNode) in halfNodes.enumerated() {
            halfNode.removeAllChildren()

            let filled = index < currentMana
            let newHalf = createHalfNode(index: index, filled: filled)
            for child in newHalf.children {
                halfNode.addChild(child.copy() as! SKNode)
            }

            // Animate mana loss
            if !filled && index == currentMana {
                let scale = SKAction.sequence([
                    SKAction.scale(to: 1.3, duration: 0.1),
                    SKAction.scale(to: 1.0, duration: 0.1)
                ])
                halfNode.run(scale)
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

    /// In medium mode (8 HP), each heart represents 2 HP (shown via half-filling)
    private let hpPerHeart: Int = Player.maxHP > 4 ? 2 : 1
    private var heartCount: Int { (maxHP + hpPerHeart - 1) / hpPerHeart }

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
        for i in 0..<heartCount {
            let heart = createHeartNode(fill: .full)
            heart.position = CGPoint(x: CGFloat(i) * (heartSize + heartSpacing), y: 0)
            addChild(heart)
            heartNodes.append(heart)
        }
    }

    private enum HeartFill { case full, half, empty }

    private func heartPath() -> CGPath {
        let path = CGMutablePath()
        let s = heartSize / 2
        path.move(to: CGPoint(x: 0, y: -s))
        path.addCurve(to: CGPoint(x: -s, y: s * 0.3),
                       control1: CGPoint(x: -s * 0.5, y: -s),
                       control2: CGPoint(x: -s, y: -s * 0.2))
        path.addCurve(to: CGPoint(x: 0, y: 0),
                       control1: CGPoint(x: -s, y: s * 0.8),
                       control2: CGPoint(x: -s * 0.3, y: s * 0.3))
        path.addCurve(to: CGPoint(x: s, y: s * 0.3),
                       control1: CGPoint(x: s * 0.3, y: s * 0.3),
                       control2: CGPoint(x: s, y: s * 0.8))
        path.addCurve(to: CGPoint(x: 0, y: -s),
                       control1: CGPoint(x: s, y: -s * 0.2),
                       control2: CGPoint(x: s * 0.5, y: -s))
        path.closeSubpath()
        return path
    }

    private func createHeartNode(fill: HeartFill) -> SKNode {
        let container = SKNode()
        let path = heartPath()

        if fill == .half {
            // Empty outline first
            let emptyShape = SKShapeNode(path: path)
            emptyShape.fillColor = SKColor(white: 0.3, alpha: 0.5)
            emptyShape.strokeColor = SKColor(white: 0.2, alpha: 0.5)
            emptyShape.lineWidth = 1.5
            container.addChild(emptyShape)

            // Filled left half via crop
            let filledShape = SKShapeNode(path: path)
            filledShape.fillColor = SKColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0)
            filledShape.strokeColor = SKColor(red: 0.6, green: 0.1, blue: 0.1, alpha: 1.0)
            filledShape.lineWidth = 1.5

            let crop = SKCropNode()
            let mask = SKShapeNode(rectOf: CGSize(width: heartSize, height: heartSize * 2))
            mask.fillColor = .white
            mask.position = CGPoint(x: -heartSize / 2, y: 0)
            crop.maskNode = mask
            crop.addChild(filledShape)
            container.addChild(crop)
        } else {
            let filled = fill == .full
            let heartShape = SKShapeNode(path: path)
            heartShape.fillColor = filled ? SKColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0) : SKColor(white: 0.3, alpha: 0.5)
            heartShape.strokeColor = filled ? SKColor(red: 0.6, green: 0.1, blue: 0.1, alpha: 1.0) : SKColor(white: 0.2, alpha: 0.5)
            heartShape.lineWidth = 1.5
            container.addChild(heartShape)
        }

        // Vertical divider line when each heart represents 2 HP
        if hpPerHeart == 2 {
            let s = heartSize / 2
            let divider = SKShapeNode()
            let linePath = CGMutablePath()
            linePath.move(to: CGPoint(x: 0, y: s * 0.0))
            linePath.addLine(to: CGPoint(x: 0, y: -s))
            divider.path = linePath
            divider.strokeColor = SKColor(white: 0.0, alpha: 0.4)
            divider.lineWidth = 1.0
            container.addChild(divider)
        }

        return container
    }

    func setHP(_ hp: Int) {
        currentHP = max(0, min(maxHP, hp))

        for (index, heartNode) in heartNodes.enumerated() {
            heartNode.removeAllChildren()

            let hpForThisHeart = currentHP - index * hpPerHeart
            let fill: HeartFill
            if hpForThisHeart >= hpPerHeart {
                fill = .full
            } else if hpForThisHeart == 1 && hpPerHeart == 2 {
                fill = .half
            } else if hpForThisHeart > 0 {
                fill = .full
            } else {
                fill = .empty
            }

            let heart = createHeartNode(fill: fill)
            for child in heart.children {
                heartNode.addChild(child.copy() as! SKNode)
            }

            // Animate damage
            if fill == .empty && hpForThisHeart == 0 && (index * hpPerHeart) < currentHP + hpPerHeart && (index * hpPerHeart) >= currentHP {
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

    func spellAt(point: CGPoint) -> Spell? {
        for (index, slot) in spellSlots.enumerated() {
            let slotFrame = CGRect(
                x: slot.position.x - slotSize / 2,
                y: slot.position.y - slotSize / 2,
                width: slotSize,
                height: slotSize
            )
            if slotFrame.contains(point) {
                return spells[index]
            }
        }
        return nil
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

// MARK: - Spell Icons

struct SpellIcons {
    /// Create a simple line-drawing icon for a spell
    static func createIcon(for spellId: String, size: CGFloat, color: SKColor) -> SKNode {
        let container = SKNode()
        let s = size * 0.35  // Scale factor for icon within slot

        let path = CGMutablePath()

        switch spellId {
        case "pass":
            // Hourglass
            path.move(to: CGPoint(x: -s * 0.5, y: s))
            path.addLine(to: CGPoint(x: s * 0.5, y: s))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: s * 0.5, y: -s))
            path.addLine(to: CGPoint(x: -s * 0.5, y: -s))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.closeSubpath()

        case "potion":
            // Potion bottle
            path.move(to: CGPoint(x: -s * 0.2, y: s))
            path.addLine(to: CGPoint(x: s * 0.2, y: s))
            path.addLine(to: CGPoint(x: s * 0.2, y: s * 0.5))
            path.addLine(to: CGPoint(x: s * 0.5, y: 0))
            path.addLine(to: CGPoint(x: s * 0.5, y: -s * 0.7))
            path.addArc(center: CGPoint(x: 0, y: -s * 0.7), radius: s * 0.5,
                         startAngle: 0, endAngle: .pi, clockwise: false)
            path.addLine(to: CGPoint(x: -s * 0.5, y: 0))
            path.addLine(to: CGPoint(x: -s * 0.2, y: s * 0.5))
            path.closeSubpath()

        case "stealth":
            // Eye with slash
            path.addEllipse(in: CGRect(x: -s * 0.7, y: -s * 0.4, width: s * 1.4, height: s * 0.8))
            path.addEllipse(in: CGRect(x: -s * 0.2, y: -s * 0.2, width: s * 0.4, height: s * 0.4))
            // Slash
            path.move(to: CGPoint(x: -s * 0.8, y: -s * 0.8))
            path.addLine(to: CGPoint(x: s * 0.8, y: s * 0.8))

        case "spare-the-dying":
            // Reaching hand (simplified)
            path.move(to: CGPoint(x: -s * 0.3, y: -s))
            path.addLine(to: CGPoint(x: -s * 0.3, y: 0))
            path.addLine(to: CGPoint(x: -s * 0.6, y: s * 0.3))
            path.move(to: CGPoint(x: -s * 0.3, y: 0))
            path.addLine(to: CGPoint(x: 0, y: s * 0.5))
            path.move(to: CGPoint(x: -s * 0.3, y: 0))
            path.addLine(to: CGPoint(x: s * 0.1, y: s * 0.6))
            path.move(to: CGPoint(x: -s * 0.3, y: 0))
            path.addLine(to: CGPoint(x: s * 0.3, y: s * 0.5))
            path.move(to: CGPoint(x: -s * 0.3, y: 0))
            path.addLine(to: CGPoint(x: s * 0.4, y: s * 0.3))

        case "brand":
            // Sword with glow
            path.move(to: CGPoint(x: 0, y: s))
            path.addLine(to: CGPoint(x: 0, y: -s * 0.5))
            path.move(to: CGPoint(x: -s * 0.4, y: s * 0.3))
            path.addLine(to: CGPoint(x: s * 0.4, y: s * 0.3))
            path.move(to: CGPoint(x: 0, y: -s * 0.5))
            path.addLine(to: CGPoint(x: -s * 0.2, y: -s * 0.8))
            path.addLine(to: CGPoint(x: s * 0.2, y: -s * 0.8))
            path.addLine(to: CGPoint(x: 0, y: -s * 0.5))
            // Glow rays
            path.move(to: CGPoint(x: s * 0.3, y: s * 0.7))
            path.addLine(to: CGPoint(x: s * 0.5, y: s * 0.9))
            path.move(to: CGPoint(x: -s * 0.3, y: s * 0.7))
            path.addLine(to: CGPoint(x: -s * 0.5, y: s * 0.9))

        case "shocking-grasp":
            // Lightning bolt
            path.move(to: CGPoint(x: s * 0.2, y: s))
            path.addLine(to: CGPoint(x: -s * 0.3, y: s * 0.1))
            path.addLine(to: CGPoint(x: s * 0.1, y: s * 0.1))
            path.addLine(to: CGPoint(x: -s * 0.2, y: -s))

        case "thunderwave":
            // Expanding wave arcs
            for i in 0..<3 {
                let r = s * (0.3 + CGFloat(i) * 0.25)
                path.addArc(center: .zero, radius: r, startAngle: -.pi * 0.7, endAngle: .pi * 0.7, clockwise: false)
            }

        case "cure-wounds":
            // Heart with plus
            let hs = s * 0.6
            path.move(to: CGPoint(x: 0, y: -hs * 0.8))
            path.addCurve(to: CGPoint(x: -hs, y: hs * 0.2), control1: CGPoint(x: -hs * 0.5, y: -hs * 0.8), control2: CGPoint(x: -hs, y: -hs * 0.3))
            path.addCurve(to: CGPoint(x: 0, y: hs * 0.1), control1: CGPoint(x: -hs, y: hs * 0.6), control2: CGPoint(x: -hs * 0.3, y: hs * 0.3))
            path.addCurve(to: CGPoint(x: hs, y: hs * 0.2), control1: CGPoint(x: hs * 0.3, y: hs * 0.3), control2: CGPoint(x: hs, y: hs * 0.6))
            path.addCurve(to: CGPoint(x: 0, y: -hs * 0.8), control1: CGPoint(x: hs, y: -hs * 0.3), control2: CGPoint(x: hs * 0.5, y: -hs * 0.8))
            // Plus
            path.move(to: CGPoint(x: 0, y: hs * 0.6))
            path.addLine(to: CGPoint(x: 0, y: hs))
            path.move(to: CGPoint(x: -hs * 0.2, y: hs * 0.8))
            path.addLine(to: CGPoint(x: hs * 0.2, y: hs * 0.8))

        case "magic-missile":
            // Dart/arrow
            path.move(to: CGPoint(x: -s * 0.8, y: -s * 0.8))
            path.addLine(to: CGPoint(x: s * 0.5, y: s * 0.5))
            path.addLine(to: CGPoint(x: s * 0.2, y: s * 0.5))
            path.addLine(to: CGPoint(x: s * 0.8, y: s * 0.8))
            path.addLine(to: CGPoint(x: s * 0.5, y: s * 0.2))
            path.addLine(to: CGPoint(x: s * 0.5, y: s * 0.5))

        case "acid-splash":
            // Tipped vial pouring acid (sealed end upper-left, opening lower-right)
            // Upper wall: opening edge → neck/body junction → sealed end
            path.move(to: CGPoint(x: s * 0.43, y: -s * 0.22))
            path.addLine(to: CGPoint(x: s * 0.25, y: s * 0.05))
            path.addLine(to: CGPoint(x: -s * 0.2, y: s * 0.55))
            // Sealed end (rounded curve to lower wall)
            path.addCurve(to: CGPoint(x: -s * 0.45, y: s * 0.3),
                          control1: CGPoint(x: -s * 0.35, y: s * 0.7),
                          control2: CGPoint(x: -s * 0.55, y: s * 0.5))
            // Lower wall: sealed end → neck/body junction → opening edge
            path.addLine(to: CGPoint(x: 0, y: -s * 0.2))
            path.addLine(to: CGPoint(x: s * 0.25, y: -s * 0.4))
            // Acid drops falling from opening
            path.move(to: CGPoint(x: s * 0.4, y: -s * 0.48))
            path.addLine(to: CGPoint(x: s * 0.47, y: -s * 0.65))
            path.move(to: CGPoint(x: s * 0.52, y: -s * 0.75))
            path.addLine(to: CGPoint(x: s * 0.55, y: -s * 0.87))

        case "burning-hands":
            // Flame
            path.move(to: CGPoint(x: 0, y: s))
            path.addCurve(to: CGPoint(x: -s * 0.5, y: -s * 0.2), control1: CGPoint(x: -s * 0.3, y: s * 0.5), control2: CGPoint(x: -s * 0.6, y: s * 0.1))
            path.addCurve(to: CGPoint(x: 0, y: -s), control1: CGPoint(x: -s * 0.4, y: -s * 0.6), control2: CGPoint(x: -s * 0.2, y: -s))
            path.addCurve(to: CGPoint(x: s * 0.5, y: -s * 0.2), control1: CGPoint(x: s * 0.2, y: -s), control2: CGPoint(x: s * 0.4, y: -s * 0.6))
            path.addCurve(to: CGPoint(x: 0, y: s), control1: CGPoint(x: s * 0.6, y: s * 0.1), control2: CGPoint(x: s * 0.3, y: s * 0.5))
            // Inner flame
            path.move(to: CGPoint(x: 0, y: s * 0.5))
            path.addCurve(to: CGPoint(x: 0, y: -s * 0.5), control1: CGPoint(x: -s * 0.2, y: 0), control2: CGPoint(x: s * 0.2, y: -s * 0.3))

        case "life-transference":
            // Yin-yang swirl
            path.addArc(center: .zero, radius: s * 0.8, startAngle: 0, endAngle: .pi * 2, clockwise: false)
            path.addArc(center: CGPoint(x: 0, y: s * 0.4), radius: s * 0.4, startAngle: .pi * 0.5, endAngle: .pi * 1.5, clockwise: false)
            path.addArc(center: CGPoint(x: 0, y: -s * 0.4), radius: s * 0.4, startAngle: .pi * 1.5, endAngle: .pi * 0.5, clockwise: false)

        case "chill-touch":
            // Skeletal hand
            path.move(to: CGPoint(x: 0, y: -s))
            path.addLine(to: CGPoint(x: 0, y: s * 0.2))
            // Fingers
            path.move(to: CGPoint(x: 0, y: s * 0.2))
            path.addLine(to: CGPoint(x: -s * 0.5, y: s))
            path.move(to: CGPoint(x: 0, y: s * 0.2))
            path.addLine(to: CGPoint(x: -s * 0.15, y: s))
            path.move(to: CGPoint(x: 0, y: s * 0.2))
            path.addLine(to: CGPoint(x: s * 0.15, y: s))
            path.move(to: CGPoint(x: 0, y: s * 0.2))
            path.addLine(to: CGPoint(x: s * 0.5, y: s * 0.6))
            // Knuckles
            path.addEllipse(in: CGRect(x: -s * 0.15, y: s * 0.1, width: s * 0.3, height: s * 0.2))

        case "calm-emotions":
            // Serene face with closed eyes
            // Head circle
            path.addArc(center: .zero, radius: s * 0.7, startAngle: 0, endAngle: .pi * 2, clockwise: false)
            // Closed left eye (gentle arc)
            path.move(to: CGPoint(x: -s * 0.45, y: s * 0.15))
            path.addCurve(to: CGPoint(x: -s * 0.15, y: s * 0.15),
                          control1: CGPoint(x: -s * 0.4, y: s * 0.3),
                          control2: CGPoint(x: -s * 0.2, y: s * 0.3))
            // Closed right eye
            path.move(to: CGPoint(x: s * 0.15, y: s * 0.15))
            path.addCurve(to: CGPoint(x: s * 0.45, y: s * 0.15),
                          control1: CGPoint(x: s * 0.2, y: s * 0.3),
                          control2: CGPoint(x: s * 0.4, y: s * 0.3))
            // Peaceful smile
            path.move(to: CGPoint(x: -s * 0.25, y: -s * 0.15))
            path.addCurve(to: CGPoint(x: s * 0.25, y: -s * 0.15),
                          control1: CGPoint(x: -s * 0.1, y: -s * 0.35),
                          control2: CGPoint(x: s * 0.1, y: -s * 0.35))

        case "private-sanctum":
            // Shield with light rays
            // Shield outline
            path.move(to: CGPoint(x: 0, y: -s * 0.9))
            path.addLine(to: CGPoint(x: -s * 0.6, y: -s * 0.3))
            path.addLine(to: CGPoint(x: -s * 0.6, y: s * 0.3))
            path.addLine(to: CGPoint(x: 0, y: s * 0.7))
            path.addLine(to: CGPoint(x: s * 0.6, y: s * 0.3))
            path.addLine(to: CGPoint(x: s * 0.6, y: -s * 0.3))
            path.closeSubpath()
            // Light rays from top
            path.move(to: CGPoint(x: 0, y: s * 0.85))
            path.addLine(to: CGPoint(x: 0, y: s))
            path.move(to: CGPoint(x: -s * 0.3, y: s * 0.7))
            path.addLine(to: CGPoint(x: -s * 0.45, y: s * 0.85))
            path.move(to: CGPoint(x: s * 0.3, y: s * 0.7))
            path.addLine(to: CGPoint(x: s * 0.45, y: s * 0.85))

        case "sleet-storm":
            // Snowflake
            for i in 0..<6 {
                let angle = CGFloat(i) * .pi / 3
                path.move(to: .zero)
                path.addLine(to: CGPoint(x: cos(angle) * s * 0.8, y: sin(angle) * s * 0.8))
                // Small branches
                let branchStart = CGPoint(x: cos(angle) * s * 0.5, y: sin(angle) * s * 0.5)
                let branchAngle1 = angle + .pi / 6
                let branchAngle2 = angle - .pi / 6
                path.move(to: branchStart)
                path.addLine(to: CGPoint(x: branchStart.x + cos(branchAngle1) * s * 0.2, y: branchStart.y + sin(branchAngle1) * s * 0.2))
                path.move(to: branchStart)
                path.addLine(to: CGPoint(x: branchStart.x + cos(branchAngle2) * s * 0.2, y: branchStart.y + sin(branchAngle2) * s * 0.2))
            }

        case "black-tentacles":
            // Tendrils radiating from center with curled tips
            for i in 0..<4 {
                let angle = CGFloat(i) * .pi / 2 + .pi / 4
                let tipAngle = angle + .pi / 6
                path.move(to: .zero)
                let mid = CGPoint(x: cos(angle) * s * 0.5, y: sin(angle) * s * 0.5)
                let tip = CGPoint(x: cos(angle) * s * 0.8, y: sin(angle) * s * 0.8)
                let curl = CGPoint(x: tip.x + cos(tipAngle) * s * 0.3, y: tip.y + sin(tipAngle) * s * 0.3)
                path.addCurve(to: curl, control1: mid, control2: tip)
            }

        case "blight":
            // Wilted plant: drooping stem with dead leaves
            path.move(to: CGPoint(x: 0, y: -s))
            path.addLine(to: CGPoint(x: 0, y: s * 0.3))
            // Drooping left leaf
            path.move(to: CGPoint(x: 0, y: s * 0.1))
            path.addCurve(to: CGPoint(x: -s * 0.6, y: -s * 0.2),
                          control1: CGPoint(x: -s * 0.3, y: s * 0.4),
                          control2: CGPoint(x: -s * 0.5, y: 0))
            // Drooping right leaf
            path.move(to: CGPoint(x: 0, y: s * 0.3))
            path.addCurve(to: CGPoint(x: s * 0.6, y: -s * 0.1),
                          control1: CGPoint(x: s * 0.3, y: s * 0.5),
                          control2: CGPoint(x: s * 0.5, y: s * 0.1))
            // Drooping top
            path.move(to: CGPoint(x: 0, y: s * 0.3))
            path.addCurve(to: CGPoint(x: s * 0.2, y: s * 0.5),
                          control1: CGPoint(x: 0, y: s * 0.6),
                          control2: CGPoint(x: s * 0.1, y: s * 0.6))

        default:
            // Fallback: simple star
            for i in 0..<5 {
                let angle = CGFloat(i) * .pi * 2 / 5 - .pi / 2
                let nextAngle = CGFloat(i + 2) * .pi * 2 / 5 - .pi / 2
                if i == 0 {
                    path.move(to: CGPoint(x: cos(angle) * s * 0.8, y: sin(angle) * s * 0.8))
                }
                path.addLine(to: CGPoint(x: cos(nextAngle) * s * 0.8, y: sin(nextAngle) * s * 0.8))
            }
        }

        let shape = SKShapeNode(path: path)
        shape.strokeColor = color
        shape.fillColor = .clear
        shape.lineWidth = 2
        shape.lineCap = .round
        shape.lineJoin = .round
        container.addChild(shape)

        return container
    }
}

// MARK: - Spell Slot

class SpellSlot: SKNode {
    private let spell: Spell
    private let size: CGFloat

    private let background: SKShapeNode
    private var iconNode: SKNode
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

        // Spell icon
        let iconColor = SpellSlot.spellColor(for: spell)
        iconNode = SpellIcons.createIcon(for: spell.id, size: size, color: iconColor)

        // Mana cost - green for restorers, red for spenders
        costLabel = SKLabelNode(fontNamed: "Cochin-Bold")
        costLabel.fontSize = 12
        if spell.manaCost < 0 {
            costLabel.fontColor = SKColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1.0)  // Green for restorers
            costLabel.text = "+\(abs(spell.manaCost))"
        } else if spell.manaCost > 0 {
            costLabel.fontColor = SKColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0)  // Red for spenders
            costLabel.text = "-\(spell.manaCost)"
        } else {
            costLabel.fontColor = SKColor(white: 0.7, alpha: 1.0)  // Gray for free spells
            costLabel.text = "0"
        }
        costLabel.verticalAlignmentMode = .top
        costLabel.horizontalAlignmentMode = .right
        costLabel.position = CGPoint(x: size / 2 - 4, y: size / 2 - 4)

        // Selection border
        selectionBorder = SKShapeNode(rectOf: CGSize(width: size + 4, height: size + 4), cornerRadius: 10)
        selectionBorder.fillColor = .clear
        selectionBorder.strokeColor = SKColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0)
        selectionBorder.lineWidth = 3
        selectionBorder.isHidden = true

        super.init()

        addChild(background)
        addChild(iconNode)
        if GameManager.shared.gameMode.hasMana {
            addChild(costLabel)
        }
        addChild(selectionBorder)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func spellColor(for spell: Spell) -> SKColor {
        if spell.isOffensive && spell.isDefensive {
            return SKColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0)  // Gold - hybrid
        } else if spell.isOffensive && spell.causesParalysis {
            return SKColor(red: 0.7, green: 0.3, blue: 0.9, alpha: 1.0)  // Purple - damage + control
        } else if spell.isOffensive {
            return SKColor(red: 1.0, green: 0.4, blue: 0.3, alpha: 1.0)  // Red - damage
        } else if spell.isDefensive && spell.causesParalysis {
            return SKColor(red: 0.2, green: 0.95, blue: 0.8, alpha: 1.0)  // Mint - healing + control
        } else if spell.isDefensive {
            return SKColor(red: 0.3, green: 1.0, blue: 0.4, alpha: 1.0)  // Green - healing
        } else {
            return SKColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0)  // Blue - utility
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

// MARK: - Potion Bar (Rainbow Mode)

class PotionBar: SKNode {
    private let slotSize: CGFloat = 45
    private let slotSpacing: CGFloat = 6
    private var slots: [PotionColor: PotionSlotNode] = [:]
    private var selectedColor: PotionColor?

    var onPotionSelected: ((PotionColor?) -> Void)?

    override init() {
        super.init()
        createSlots()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func createSlots() {
        let colors = PotionColor.allCases
        let totalWidth = CGFloat(colors.count) * slotSize + CGFloat(colors.count - 1) * slotSpacing
        let startX = -totalWidth / 2 + slotSize / 2

        for (index, color) in colors.enumerated() {
            let slot = PotionSlotNode(color: color, size: slotSize)
            slot.position = CGPoint(x: startX + CGFloat(index) * (slotSize + slotSpacing), y: 0)
            addChild(slot)
            slots[color] = slot
        }
    }

    func updateCounts(from player: Player) {
        for color in PotionColor.allCases {
            let count = player.potionCount(for: color.rawValue)
            slots[color]?.updateCount(count)
        }
    }

    func handleTouch(at point: CGPoint) {
        for (color, slot) in slots {
            let slotFrame = CGRect(
                x: slot.position.x - slotSize / 2,
                y: slot.position.y - slotSize / 2,
                width: slotSize,
                height: slotSize
            )
            if slotFrame.contains(point) {
                if selectedColor == color {
                    deselectAll()
                    onPotionSelected?(nil)
                } else {
                    guard slot.currentCount > 0 else { return }
                    deselectAll()
                    selectedColor = color
                    slot.setSelected(true)
                    onPotionSelected?(color)
                }
                return
            }
        }
    }

    func deselectAll() {
        selectedColor = nil
        for (_, slot) in slots {
            slot.setSelected(false)
        }
    }

    override func contains(_ point: CGPoint) -> Bool {
        let colors = PotionColor.allCases
        let totalWidth = CGFloat(colors.count) * slotSize + CGFloat(max(0, colors.count - 1)) * slotSpacing
        let frame = CGRect(x: -totalWidth / 2, y: -slotSize / 2, width: totalWidth, height: slotSize)
        return frame.contains(point)
    }
}

class PotionSlotNode: SKNode {
    private let background: SKShapeNode
    private let countLabel: SKLabelNode
    private let selectionBorder: SKShapeNode
    private(set) var currentCount: Int = 0

    init(color: PotionColor, size: CGFloat) {
        background = SKShapeNode(circleOfRadius: size / 2)
        background.fillColor = PotionSlotNode.potionSKColor(for: color)
        background.strokeColor = SKColor(white: 0.3, alpha: 1.0)
        background.lineWidth = 2

        countLabel = SKLabelNode(fontNamed: "Cochin-Bold")
        countLabel.fontSize = 14
        countLabel.fontColor = .white
        countLabel.verticalAlignmentMode = .center
        countLabel.horizontalAlignmentMode = .center
        countLabel.text = "0"

        selectionBorder = SKShapeNode(circleOfRadius: size / 2 + 3)
        selectionBorder.fillColor = .clear
        selectionBorder.strokeColor = SKColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0)
        selectionBorder.lineWidth = 3
        selectionBorder.isHidden = true

        super.init()

        addChild(selectionBorder)
        if color == .rainbow {
            // Multicolored pie segments instead of solid fill
            background.fillColor = .clear
            let rainbow = PotionSlotNode.makeRainbowCircle(radius: size / 2)
            addChild(rainbow)
            addChild(countLabel)
        } else {
            addChild(background)
            addChild(countLabel)
        }

        alpha = 0.3  // Start grayed out
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateCount(_ count: Int) {
        currentCount = count
        countLabel.text = "\(count)"
        alpha = count > 0 ? 1.0 : 0.3
    }

    func setSelected(_ selected: Bool) {
        selectionBorder.isHidden = !selected
        if selected {
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.1, duration: 0.1),
                SKAction.scale(to: 1.0, duration: 0.1)
            ])
            run(pulse)
        }
    }

    static func potionSKColor(for color: PotionColor) -> SKColor {
        switch color {
        case .red:     return SKColor(red: 1.0, green: 0.4, blue: 0.3, alpha: 1.0)
        case .green:   return SKColor(red: 0.3, green: 1.0, blue: 0.4, alpha: 1.0)
        case .blue:    return SKColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0)
        case .gold:    return SKColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0)
        case .purple:  return SKColor(red: 0.7, green: 0.3, blue: 0.9, alpha: 1.0)
        case .mint:    return SKColor(red: 0.2, green: 0.95, blue: 0.8, alpha: 1.0)
        case .rainbow: return .white
        }
    }

    /// All potion colors for rainbow cycling
    static let rainbowSegmentColors: [SKColor] = [
        potionSKColor(for: .red),
        potionSKColor(for: .gold),
        potionSKColor(for: .green),
        potionSKColor(for: .mint),
        potionSKColor(for: .blue),
        potionSKColor(for: .purple),
    ]

    /// Creates a multicolored circle node with pie segments
    static func makeRainbowCircle(radius: CGFloat) -> SKNode {
        let container = SKNode()
        let colors = rainbowSegmentColors
        let segmentAngle = CGFloat.pi * 2.0 / CGFloat(colors.count)

        for (i, color) in colors.enumerated() {
            let startAngle = segmentAngle * CGFloat(i) - CGFloat.pi / 2
            let endAngle = startAngle + segmentAngle
            let path = CGMutablePath()
            path.move(to: .zero)
            path.addArc(center: .zero, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
            path.closeSubpath()
            let segment = SKShapeNode(path: path)
            segment.fillColor = color
            segment.strokeColor = .clear
            segment.lineWidth = 0
            container.addChild(segment)
        }
        return container
    }
}
