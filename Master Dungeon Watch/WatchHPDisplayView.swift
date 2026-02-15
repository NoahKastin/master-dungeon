//
//  WatchHPDisplayView.swift
//  Master Dungeon Watch
//
//  Compact hearts row for Easy mode (16 HP = 8 hearts at 2 HP each).
//

import SwiftUI

struct WatchHPDisplayView: View {
    let currentHP: Int
    let maxHP: Int

    private var heartCount: Int { maxHP / 2 }
    private let heartSize: CGFloat = 10

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<heartCount, id: \.self) { index in
                heartImage(for: index)
                    .font(.system(size: heartSize))
            }
        }
    }

    private func heartImage(for index: Int) -> some View {
        let hpForThisHeart = currentHP - (index * 2)

        if hpForThisHeart >= 2 {
            // Full heart
            return Image(systemName: "heart.fill")
                .foregroundStyle(.red)
        } else if hpForThisHeart == 1 {
            // Half heart
            return Image(systemName: "heart.lefthalf.fill")
                .foregroundStyle(.red)
        } else {
            // Empty heart
            return Image(systemName: "heart")
                .foregroundStyle(.gray.opacity(0.4))
        }
    }
}
