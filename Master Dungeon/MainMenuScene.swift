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
    private var normalButton: SKShapeNode!
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
        let buttonCenterY = size.height * 0.42

        // "Normal" button (primary green)
        normalButton = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: buttonHeight), cornerRadius: 12)
        normalButton.fillColor = SKColor(red: 0.2, green: 0.6, blue: 0.3, alpha: 1.0)
        normalButton.strokeColor = SKColor(red: 0.3, green: 0.8, blue: 0.4, alpha: 1.0)
        normalButton.lineWidth = 2
        normalButton.position = CGPoint(x: size.width / 2, y: buttonCenterY)
        normalButton.zPosition = 10
        addChild(normalButton)

        let normalLabel = SKLabelNode(fontNamed: "Cochin-Bold")
        normalLabel.text = "Normal"
        normalLabel.fontSize = 18
        normalLabel.fontColor = .white
        normalLabel.verticalAlignmentMode = .center
        normalLabel.position = normalButton.position
        normalLabel.zPosition = 11
        addChild(normalLabel)

        // "How to Play" button (secondary gray)
        howToPlayButton = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: buttonHeight), cornerRadius: 12)
        howToPlayButton.fillColor = SKColor(white: 0.2, alpha: 0.8)
        howToPlayButton.strokeColor = SKColor(white: 0.4, alpha: 1.0)
        howToPlayButton.lineWidth = 2
        howToPlayButton.position = CGPoint(x: size.width / 2, y: buttonCenterY - 70)
        howToPlayButton.zPosition = 10
        addChild(howToPlayButton)

        let howToPlayLabel = SKLabelNode(fontNamed: "Cochin-Bold")
        howToPlayLabel.text = "How to Play"
        howToPlayLabel.fontSize = 18
        howToPlayLabel.fontColor = .white
        howToPlayLabel.verticalAlignmentMode = .center
        howToPlayLabel.position = howToPlayButton.position
        howToPlayLabel.zPosition = 11
        addChild(howToPlayLabel)
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

        // Check "Normal" button
        let normalBounds = CGRect(
            x: normalButton.position.x - 100,
            y: normalButton.position.y - 25,
            width: 200,
            height: 50
        )
        if normalBounds.contains(location) {
            startNormalMode()
            return
        }

        // Check "How to Play" button
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

    private func startNormalMode() {
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
        Tap a hex to walk there. You can only
        move to adjacent hexes each step.

        CASTING SPELLS
        Tap a spell, then tap a target hex.
        Range 0 spells cast on yourself.

        COMBAT
        Defeat enemies by casting offensive
        spells at them. Red = damage dealers.

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
