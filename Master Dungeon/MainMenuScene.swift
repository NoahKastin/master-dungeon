//
//  MainMenuScene.swift
//  Master Dungeon
//
//  Main menu with game mode selection and how-to-play.
//

import SpriteKit

class MainMenuScene: SKScene {

    // MARK: - Properties
    private var helpOverlay: SKNode?
    private var touchStartTime: Date?
    private var touchedButton: SKShapeNode?
    private var easyButton: SKShapeNode!
    private var mediumButton: SKShapeNode!
    private var hardButton: SKShapeNode!
    private var extremeButton: SKShapeNode!
    private var rainbowButton: SKShapeNode!
    private var teamButton: SKShapeNode!
    private var blitzButton: SKShapeNode!
    private var howToPlayButton: SKShapeNode!

    // MARK: - Scene Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(white: 0.08, alpha: 1.0)
        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        // Game title
        let titleLabel = SKLabelNode(fontNamed: "Cochin-Bold")
        titleLabel.text = "Master Dungeon"
        titleLabel.fontSize = 38
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.65)
        titleLabel.zPosition = 10
        addChild(titleLabel)

        // Two-column button layout
        let buttonWidth: CGFloat = 140
        let buttonHeight: CGFloat = 50
        let buttonTopY = size.height * 0.55
        let buttonSpacing: CGFloat = 60
        let columnGap: CGFloat = 16
        let leftX = size.width / 2 - buttonWidth / 2 - columnGap / 2
        let rightX = size.width / 2 + buttonWidth / 2 + columnGap / 2

        // --- Left Column ---

        // "Easy" button (blue, locked)
        easyButton = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: buttonHeight), cornerRadius: 12)
        easyButton.fillColor = SKColor(red: 0.2, green: 0.4, blue: 0.7, alpha: 1.0)
        easyButton.strokeColor = SKColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 1.0)
        easyButton.lineWidth = 2
        easyButton.position = CGPoint(x: leftX, y: buttonTopY)
        easyButton.zPosition = 10
        addChild(easyButton)

        let easyLabel = SKLabelNode(fontNamed: "Cochin-Bold")
        easyLabel.text = "Easy"
        easyLabel.fontSize = 18
        easyLabel.fontColor = .white
        easyLabel.verticalAlignmentMode = .center
        easyLabel.position = easyButton.position
        easyLabel.zPosition = 11
        addChild(easyLabel)

        // "Medium" button (green)
        mediumButton = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: buttonHeight), cornerRadius: 12)
        mediumButton.fillColor = SKColor(red: 0.2, green: 0.6, blue: 0.3, alpha: 1.0)
        mediumButton.strokeColor = SKColor(red: 0.3, green: 0.8, blue: 0.4, alpha: 1.0)
        mediumButton.lineWidth = 2
        mediumButton.position = CGPoint(x: leftX, y: buttonTopY - buttonSpacing)
        mediumButton.zPosition = 10
        addChild(mediumButton)

        let mediumLabel = SKLabelNode(fontNamed: "Cochin-Bold")
        mediumLabel.text = "Medium"
        mediumLabel.fontSize = 18
        mediumLabel.fontColor = .white
        mediumLabel.verticalAlignmentMode = .center
        mediumLabel.position = mediumButton.position
        mediumLabel.zPosition = 11
        addChild(mediumLabel)

        // "Hard" button (gold)
        hardButton = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: buttonHeight), cornerRadius: 12)
        hardButton.fillColor = SKColor(red: 0.7, green: 0.55, blue: 0.15, alpha: 1.0)
        hardButton.strokeColor = SKColor(red: 0.9, green: 0.75, blue: 0.25, alpha: 1.0)
        hardButton.lineWidth = 2
        hardButton.position = CGPoint(x: leftX, y: buttonTopY - buttonSpacing * 2)
        hardButton.zPosition = 10
        addChild(hardButton)

        let hardLabel = SKLabelNode(fontNamed: "Cochin-Bold")
        hardLabel.text = "Hard"
        hardLabel.fontSize = 18
        hardLabel.fontColor = .white
        hardLabel.verticalAlignmentMode = .center
        hardLabel.position = hardButton.position
        hardLabel.zPosition = 11
        addChild(hardLabel)

        // "Extreme" button (red)
        extremeButton = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: buttonHeight), cornerRadius: 12)
        extremeButton.fillColor = SKColor(red: 0.6, green: 0.2, blue: 0.2, alpha: 1.0)
        extremeButton.strokeColor = SKColor(red: 0.8, green: 0.3, blue: 0.3, alpha: 1.0)
        extremeButton.lineWidth = 2
        extremeButton.position = CGPoint(x: leftX, y: buttonTopY - buttonSpacing * 3)
        extremeButton.zPosition = 10
        addChild(extremeButton)

        let extremeLabel = SKLabelNode(fontNamed: "Cochin-Bold")
        extremeLabel.text = "Extreme"
        extremeLabel.fontSize = 18
        extremeLabel.fontColor = .white
        extremeLabel.verticalAlignmentMode = .center
        extremeLabel.position = extremeButton.position
        extremeLabel.zPosition = 11
        addChild(extremeLabel)

        // --- Right Column ---

        // "Rainbow" button (rainbow gradient, locked)
        rainbowButton = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: buttonHeight), cornerRadius: 12)
        rainbowButton.fillColor = .white
        rainbowButton.fillTexture = makeRainbowTexture(width: buttonWidth, height: buttonHeight)
        rainbowButton.strokeColor = SKColor(white: 0.4, alpha: 1.0)
        rainbowButton.lineWidth = 2
        rainbowButton.position = CGPoint(x: rightX, y: buttonTopY)
        rainbowButton.zPosition = 10
        addChild(rainbowButton)

        let rainbowLabel = SKLabelNode(fontNamed: "Cochin-Bold")
        rainbowLabel.text = "Rainbow"
        rainbowLabel.fontSize = 18
        rainbowLabel.fontColor = .white
        rainbowLabel.verticalAlignmentMode = .center
        rainbowLabel.position = rainbowButton.position
        rainbowLabel.zPosition = 11
        addChild(rainbowLabel)

        // "Team" button (purple, locked)
        teamButton = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: buttonHeight), cornerRadius: 12)
        teamButton.fillColor = SKColor(red: 0.45, green: 0.2, blue: 0.7, alpha: 1.0)
        teamButton.strokeColor = SKColor(red: 0.6, green: 0.3, blue: 0.9, alpha: 1.0)
        teamButton.lineWidth = 2
        teamButton.position = CGPoint(x: rightX, y: buttonTopY - buttonSpacing)
        teamButton.zPosition = 10
        teamButton.alpha = 0.4
        addChild(teamButton)

        let teamLabel = SKLabelNode(fontNamed: "Cochin-Bold")
        teamLabel.text = "Team \u{1F512}"
        teamLabel.fontSize = 18
        teamLabel.fontColor = .white
        teamLabel.verticalAlignmentMode = .center
        teamLabel.position = teamButton.position
        teamLabel.zPosition = 11
        teamLabel.alpha = 0.4
        addChild(teamLabel)

        // "Blitz" button (mint)
        blitzButton = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: buttonHeight), cornerRadius: 12)
        blitzButton.fillColor = SKColor(red: 0.15, green: 0.7, blue: 0.6, alpha: 1.0)
        blitzButton.strokeColor = SKColor(red: 0.2, green: 0.95, blue: 0.8, alpha: 1.0)
        blitzButton.lineWidth = 2
        blitzButton.position = CGPoint(x: rightX, y: buttonTopY - buttonSpacing * 2)
        blitzButton.zPosition = 10
        addChild(blitzButton)

        let blitzLabel = SKLabelNode(fontNamed: "Cochin-Bold")
        blitzLabel.text = "Blitz"
        blitzLabel.fontSize = 18
        blitzLabel.fontColor = .white
        blitzLabel.verticalAlignmentMode = .center
        blitzLabel.position = blitzButton.position
        blitzLabel.zPosition = 11
        addChild(blitzLabel)

        // "Help" button (secondary gray — retains original color)
        howToPlayButton = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: buttonHeight), cornerRadius: 12)
        howToPlayButton.fillColor = SKColor(white: 0.2, alpha: 0.8)
        howToPlayButton.strokeColor = SKColor(white: 0.4, alpha: 1.0)
        howToPlayButton.lineWidth = 2
        howToPlayButton.position = CGPoint(x: rightX, y: buttonTopY - buttonSpacing * 3)
        howToPlayButton.zPosition = 10
        addChild(howToPlayButton)

        let helpLabel = SKLabelNode(fontNamed: "Cochin-Bold")
        helpLabel.text = "Help"
        helpLabel.fontSize = 18
        helpLabel.fontColor = .white
        helpLabel.verticalAlignmentMode = .center
        helpLabel.position = howToPlayButton.position
        helpLabel.zPosition = 11
        addChild(helpLabel)
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // If overlay is showing, any tap dismisses it
        if helpOverlay != nil {
            hideHelp()
            return
        }

        // Record touch start — action is decided in touchesEnded
        touchStartTime = Date()

        let halfWidth: CGFloat = 70
        let halfHeight: CGFloat = 25

        let buttons = [easyButton!, mediumButton!, hardButton!, extremeButton!, blitzButton!, rainbowButton!, howToPlayButton!]
        for button in buttons {
            let bounds = CGRect(
                x: button.position.x - halfWidth,
                y: button.position.y - halfHeight,
                width: halfWidth * 2,
                height: halfHeight * 2
            )
            if bounds.contains(location) {
                touchedButton = button
                return
            }
        }

        touchedButton = nil
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        defer {
            touchStartTime = nil
            touchedButton = nil
        }

        guard let button = touchedButton, let startTime = touchStartTime else { return }

        let elapsed = Date().timeIntervalSince(startTime)
        let isLongPress = elapsed >= 0.5

        if isLongPress {
            // Long press — show mode description (only for mode buttons)
            if button === easyButton {
                showModeDescription("A gentle introduction.")
            } else if button === mediumButton {
                showModeDescription("A familiar RPG-like mode.")
            } else if button === hardButton {
                showModeDescription("Less health, longer range.")
            } else if button === extremeButton {
                showModeDescription("One mistake ends it all.")
            } else if button === blitzButton {
                showModeDescription("Beat the clock!")
            } else if button === rainbowButton {
                showModeDescription("Drink potions, outrun lava!")
            }
        } else {
            // Short tap — start mode or show help
            if button === easyButton {
                startEasyMode()
            } else if button === mediumButton {
                startMediumMode()
            } else if button === hardButton {
                startHardMode()
            } else if button === extremeButton {
                startExtremeMode()
            } else if button === blitzButton {
                startBlitzMode()
            } else if button === rainbowButton {
                startRainbowMode()
            } else if button === howToPlayButton {
                showHelp()
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchStartTime = nil
        touchedButton = nil
    }

    // MARK: - Navigation

    private func startEasyMode() {
        GameManager.shared.gameMode = .easy
        let spellScene = SpellSelectionScene(size: size)
        spellScene.scaleMode = scaleMode
        let transition = SKTransition.fade(withDuration: 0.5)
        view?.presentScene(spellScene, transition: transition)
    }

    private func startMediumMode() {
        GameManager.shared.gameMode = .medium
        let spellScene = SpellSelectionScene(size: size)
        spellScene.scaleMode = scaleMode
        let transition = SKTransition.fade(withDuration: 0.5)
        view?.presentScene(spellScene, transition: transition)
    }

    private func startHardMode() {
        GameManager.shared.gameMode = .normal
        let spellScene = SpellSelectionScene(size: size)
        spellScene.scaleMode = scaleMode
        let transition = SKTransition.fade(withDuration: 0.5)
        view?.presentScene(spellScene, transition: transition)
    }

    private func startExtremeMode() {
        GameManager.shared.gameMode = .hardcore
        let spellScene = SpellSelectionScene(size: size)
        spellScene.scaleMode = scaleMode
        let transition = SKTransition.fade(withDuration: 0.5)
        view?.presentScene(spellScene, transition: transition)
    }

    private func startBlitzMode() {
        GameManager.shared.gameMode = .blitz
        let spellScene = SpellSelectionScene(size: size)
        spellScene.scaleMode = scaleMode
        let transition = SKTransition.fade(withDuration: 0.5)
        view?.presentScene(spellScene, transition: transition)
    }

    private func startRainbowMode() {
        GameManager.shared.gameMode = .rainbow
        let spellScene = SpellSelectionScene(size: size)
        spellScene.scaleMode = scaleMode
        let transition = SKTransition.fade(withDuration: 0.5)
        view?.presentScene(spellScene, transition: transition)
    }

    // MARK: - Mode Description Overlay

    private func showModeDescription(_ text: String) {
        guard helpOverlay == nil else { return }

        let overlay = SKNode()
        overlay.zPosition = 500

        // Dimmed background
        let dimmer = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height))
        dimmer.fillColor = SKColor(white: 0, alpha: 0.85)
        dimmer.strokeColor = .clear
        dimmer.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.addChild(dimmer)

        // Small panel
        let panelWidth = min(size.width - 60, 280)
        let panelHeight: CGFloat = 70
        let panel = SKShapeNode(rectOf: CGSize(width: panelWidth, height: panelHeight), cornerRadius: 16)
        panel.fillColor = SKColor(white: 0.15, alpha: 1.0)
        panel.strokeColor = SKColor(white: 0.4, alpha: 1.0)
        panel.lineWidth = 2
        panel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.addChild(panel)

        // Description text
        let descLabel = SKLabelNode(fontNamed: "Cochin")
        descLabel.text = text
        descLabel.fontSize = 16
        descLabel.fontColor = SKColor(white: 0.9, alpha: 1.0)
        descLabel.verticalAlignmentMode = .center
        descLabel.horizontalAlignmentMode = .center
        descLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 6)
        overlay.addChild(descLabel)

        // Dismiss hint
        let hintLabel = SKLabelNode(fontNamed: "Cochin")
        hintLabel.text = "Tap anywhere to close"
        hintLabel.fontSize = 11
        hintLabel.fontColor = SKColor(white: 0.5, alpha: 1.0)
        hintLabel.verticalAlignmentMode = .center
        hintLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 16)
        overlay.addChild(hintLabel)

        addChild(overlay)
        helpOverlay = overlay

        overlay.alpha = 0
        overlay.run(SKAction.fadeIn(withDuration: 0.2))
    }

    // MARK: - Help Overlay

    private func showHelp() {
        guard helpOverlay == nil else { return }

        let overlay = SKNode()
        overlay.zPosition = 500

        // Dimmed background
        let dimmer = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height))
        dimmer.fillColor = SKColor(white: 0, alpha: 0.85)
        dimmer.strokeColor = .clear
        dimmer.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.addChild(dimmer)

        // Help panel
        let panelWidth = min(size.width - 40, 350)
        let panelHeight = min(size.height - 100, 500)
        let panel = SKShapeNode(rectOf: CGSize(width: panelWidth, height: panelHeight), cornerRadius: 16)
        panel.fillColor = SKColor(white: 0.15, alpha: 1.0)
        panel.strokeColor = SKColor(white: 0.4, alpha: 1.0)
        panel.lineWidth = 2
        panel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.addChild(panel)

        // Title
        let title = SKLabelNode(fontNamed: "Cochin-Bold")
        title.text = "How to Play"
        title.fontSize = 22
        title.fontColor = .white
        title.position = CGPoint(x: size.width / 2, y: size.height / 2 + panelHeight / 2 - 35)
        overlay.addChild(title)

        // Instructions text
        let instructions = """
        Choose up to 3 spells, then survive!
        Hold a mode button for its description.
        Hold a spell to see its stats.

        MOVEMENT
        Tap a hex to walk there.
        Walking is critical to success!

        CASTING SPELLS
        Tap a spell, then tap a target hex.
        Range 0 spells cast on yourself.

        COMBAT
        Defeat enemies (triangles) by casting
        offensive (red) spells at them.
        Numbers on enemies show their health.

        SURVIVAL
        Green spells heal. Keep your HP up!
        Hearts show health, crystals show mana.

        CHALLENGES
        Complete objectives shown at the top.
        Each challenge tests different skills.

        Tap anywhere to close
        """

        let helpText = SKLabelNode(fontNamed: "Cochin")
        helpText.text = instructions
        helpText.fontSize = 13
        helpText.fontColor = SKColor(white: 0.9, alpha: 1.0)
        helpText.numberOfLines = 0
        helpText.preferredMaxLayoutWidth = panelWidth - 30
        helpText.lineBreakMode = .byWordWrapping
        helpText.verticalAlignmentMode = .top
        helpText.horizontalAlignmentMode = .center
        helpText.position = CGPoint(x: size.width / 2, y: size.height / 2 + panelHeight / 2 - 60)
        overlay.addChild(helpText)

        addChild(overlay)
        helpOverlay = overlay

        // Fade in
        overlay.alpha = 0
        overlay.run(SKAction.fadeIn(withDuration: 0.2))
    }

    private func hideHelp() {
        guard let overlay = helpOverlay else { return }

        overlay.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.15),
            SKAction.removeFromParent()
        ]))
        helpOverlay = nil
    }

    // MARK: - Helpers

    private func makeRainbowTexture(width: CGFloat, height: CGFloat) -> SKTexture {
        let scale = view?.window?.screen.scale ?? UITraitCollection.current.displayScale
        let w = Int(width * scale)
        let h = Int(height * scale)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [
            SKColor(red: 0.6, green: 0.2, blue: 0.2, alpha: 1.0).cgColor,   // Red (Extreme)
            SKColor(red: 0.7, green: 0.55, blue: 0.15, alpha: 1.0).cgColor,  // Gold (Hard)
            SKColor(red: 0.2, green: 0.6, blue: 0.3, alpha: 1.0).cgColor,   // Green (Medium)
            SKColor(red: 0.15, green: 0.7, blue: 0.6, alpha: 1.0).cgColor,  // Mint (Blitz)
            SKColor(red: 0.2, green: 0.4, blue: 0.7, alpha: 1.0).cgColor,   // Blue (Easy)
            SKColor(red: 0.45, green: 0.2, blue: 0.7, alpha: 1.0).cgColor,  // Purple (Team)
        ] as CFArray
        let locations: [CGFloat] = [0, 0.2, 0.4, 0.6, 0.8, 1.0]
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations)!
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                            bytesPerRow: w * 4, space: colorSpace,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.drawLinearGradient(gradient,
                               start: CGPoint(x: 0, y: 0),
                               end: CGPoint(x: CGFloat(w), y: 0),
                               options: [])
        let image = ctx.makeImage()!
        return SKTexture(cgImage: image)
    }
}
