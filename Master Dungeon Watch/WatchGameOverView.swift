//
//  WatchGameOverView.swift
//  Master Dungeon Watch
//
//  Game over screen with score. Navigates back to spell selection.
//

import SwiftUI

struct WatchGameOverView: View {
    let score: Int
    let onPlayAgain: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Game Over")
                .font(.title3)
                .fontWeight(.bold)

            Text("Score: \(score)")
                .font(.headline)
                .foregroundStyle(.yellow)

            Button("Play Again", action: onPlayAgain)
                .buttonStyle(.borderedProminent)
                .tint(.blue)
        }
        .padding()
    }
}
