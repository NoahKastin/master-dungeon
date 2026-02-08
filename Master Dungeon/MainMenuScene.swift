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
    private var easyButton: SKShapeNode!
    private var mediumButton: SKShapeNode!
    private var hardButton: SKShapeNode!
    private var extremeButton: SKShapeNode!
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

        // Buttons
        let buttonWidth: CGFloat = 200
        let buttonHeight: CGFloat = 50
        let buttonTopY = size.height * 0.55
        let buttonSpacing: CGFloat = 60

        // "Easy" button (blue, locked)
        easyButton = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: buttonHeight), cornerRadius: 12)
        easyButton.fillColor = SKColor(red: 0.2, green: 0.4, blue: 0.7, alpha: 1.0)
        easyButton.strokeColor = SKColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 1.0)
        easyButton.lineWidth = 2
        easyButton.position = CGPoint(x: size.width / 2, y: buttonTopY)
        easyButton.zPosition = 10
        easyButton.alpha = 0.4
        addChild(easyButton)

        let easyLabel = SKLabelNode(fontNamed: "Cochin-Bold")
        easyLabel.text = "Easy \u{1F512}"
        easyLabel.fontSize = 18
        easyLabel.fontColor = .white
        easyLabel.verticalAlignmentMode = .center
        easyLabel.position = easyButton.position
        easyLabel.zPosition = 11
        easyLabel.alpha = 0.4
        addChild(easyLabel)

        // "Medium" button (green, locked)
        mediumButton = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: buttonHeight), cornerRadius: 12)
        mediumButton.fillColor = SKColor(red: 0.2, green: 0.6, blue: 0.3, alpha: 1.0)
        mediumButton.strokeColor = SKColor(red: 0.3, green: 0.8, blue: 0.4, alpha: 1.0)
        mediumButton.lineWidth = 2
        mediumButton.position = CGPoint(x: size.width / 2, y: buttonTopY - buttonSpacing)
        mediumButton.zPosition = 10
        mediumButton.alpha = 0.4
        addChild(mediumButton)

        let mediumLabel = SKLabelNode(fontNamed: "Cochin-Bold")
        mediumLabel.text = "Medium \u{1F512}"
        mediumLabel.fontSize = 18
        mediumLabel.fontColor = .white
        mediumLabel.verticalAlignmentMode = .center
        mediumLabel.position = mediumButton.position
        mediumLabel.zPosition = 11
        mediumLabel.alpha = 0.4
        addChild(mediumLabel)

        // "Hard" button (gold)
        hardButton = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: buttonHeight), cornerRadius: 12)
        hardButton.fillColor = SKColor(red: 0.7, green: 0.55, blue: 0.15, alpha: 1.0)
        hardButton.strokeColor = SKColor(red: 0.9, green: 0.75, blue: 0.25, alpha: 1.0)
        hardButton.lineWidth = 2
        hardButton.position = CGPoint(x: size.width / 2, y: buttonTopY - buttonSpacing * 2)
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
        extremeButton.position = CGPoint(x: size.width / 2, y: buttonTopY - buttonSpacing * 3)
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

        // "Help" button (secondary gray)
        howToPlayButton = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: buttonHeight), cornerRadius: 12)
        howToPlayButton.fillColor = SKColor(white: 0.2, alpha: 0.8)
        howToPlayButton.strokeColor = SKColor(white: 0.4, alpha: 1.0)
        howToPlayButton.lineWidth = 2
        howToPlayButton.position = CGPoint(x: size.width / 2, y: buttonTopY - buttonSpacing * 4)
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

        // If help overlay is showing, any tap dismisses it
        if helpOverlay != nil {
            hideHelp()
            return
        }

        // Check "Hard" button
        let hardBounds = CGRect(
            x: hardButton.position.x - 100,
            y: hardButton.position.y - 25,
            width: 200,
            height: 50
        )
        if hardBounds.contains(location) {
            startHardMode()
            return
        }

        // Check "Extreme" button
        let extremeBounds = CGRect(
            x: extremeButton.position.x - 100,
            y: extremeButton.position.y - 25,
            width: 200,
            height: 50
        )
        if extremeBounds.contains(location) {
            startExtremeMode()
            return
        }

        // Check "Help" button
        let helpBounds = CGRect(
            x: howToPlayButton.position.x - 100,
            y: howToPlayButton.position.y - 25,
            width: 200,
            height: 50
        )
        if helpBounds.contains(location) {
            showHelp()
            return
        }
    }

    // MARK: - Navigation

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
        SELECT SPELLS
        Choose up to 3 spells. Pass is always
        available and restores all your mana.

        MOVEMENT
        Tap a hex to walk there.
        Walking is critical to success!

        CASTING SPELLS
        Tap a spell, then tap a target hex.
        Range 0 spells cast on yourself.

        COMBAT
        Defeat enemies (triangles) by casting
        offensive (red) spells at them.

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
}
