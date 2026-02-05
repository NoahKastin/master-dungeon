//
//  GameViewController.swift
//  Master Dungeon
//
//  Created by Noah Kastin on 1/25/26.
//

import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let view = self.view as? SKView else {
            fatalError("View is not an SKView")
        }

        // Start with main menu scene
        let scene = MainMenuScene(size: view.bounds.size)
        scene.scaleMode = .aspectFill

        view.presentScene(scene)

        view.ignoresSiblingOrder = true

        #if DEBUG
        view.showsFPS = true
        view.showsNodeCount = true
        #endif
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .portrait
        } else {
            return .all
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
