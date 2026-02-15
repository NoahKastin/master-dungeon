//
//  WatchSpellBarView.swift
//  Master Dungeon Watch
//
//  Compact spell icon for bottom-right corner. Long-press for description.
//

import SwiftUI

struct WatchSpellBarView: View {
    var engine: WatchGameEngine
    var onLongPress: ((Spell) -> Void)? = nil

    var body: some View {
        if let spell = engine.selectedSpell {
            Image(systemName: sfSymbol(for: spell))
                .foregroundStyle(spellColor(for: spell))
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(engine.isTargeting ? Color.yellow.opacity(0.3) : Color.white.opacity(0.15))
                )
                .onLongPressGesture(minimumDuration: 0.4) {
                    onLongPress?(spell)
                }
        }
    }

    static func sfSymbol(for spell: Spell) -> String {
        switch spell.id {
        case "move": return "figure.walk"
        case "blight": return "leaf.fill"
        case "stealth": return "eye.slash"
        case "brand": return "lightbulb.fill"
        case "burning-hands": return "flame.fill"
        case "calm-emotions": return "heart.circle"
        case "cure-wounds": return "cross.circle.fill"
        case "life-transference": return "arrow.left.arrow.right"
        case "private-sanctum": return "shield.fill"
        case "shocking-grasp": return "bolt.fill"
        default: return "sparkle"
        }
    }

    static func spellColor(for spell: Spell) -> Color {
        if spell.isOffensive && spell.isDefensive { return .yellow }
        if spell.isOffensive && spell.causesParalysis { return .purple }
        if spell.isDefensive && spell.causesParalysis { return .mint }
        if spell.isOffensive { return .red }
        if spell.isDefensive { return .green }
        return .blue
    }

    private func sfSymbol(for spell: Spell) -> String {
        Self.sfSymbol(for: spell)
    }

    private func spellColor(for spell: Spell) -> Color {
        Self.spellColor(for: spell)
    }
}
