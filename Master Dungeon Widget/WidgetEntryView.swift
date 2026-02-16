//
//  WidgetEntryView.swift
//  Master Dungeon Widget
//
//  Main widget view composing hex grid, spell bar, and status.
//

import AppIntents
import SwiftUI
import WidgetKit

struct WidgetEntryView: View {
    let state: WidgetGameState

    var body: some View {
        switch state.phase {
        case .spellSelection:
            spellSelectionView
        case .help:
            helpView
        case .selectSpell:
            gameplayView
        case .selectTarget:
            targetingView
        case .spellInfo:
            spellInfoView
        case .victory:
            victoryView
        case .gameOver:
            gameOverView
        }
    }

    // MARK: - Spell Selection

    private var spellSelectionView: some View {
        VStack(spacing: 4) {
            HStack {
                Text(state.challengeDescription)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.yellow)
                    .widgetAccentable()
                Spacer()
                Button(intent: ShowHelpIntent()) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }

            let spells = SpellData.easySpells
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
                ForEach(spells) { spell in
                    let isSelected = state.selectedSpellIDs.contains(spell.id)
                    Button(intent: PickSpellIntent(spellID: spell.id)) {
                        VStack(spacing: 1) {
                            Image(systemName: sfSymbol(for: spell))
                                .font(.system(size: 12))
                                .foregroundStyle(spellColor(for: spell))
                                .widgetAccentable()
                            Text(spell.watchName)
                                .font(.system(size: 7, weight: .medium))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isSelected ? Color.yellow.opacity(0.3) : Color.white.opacity(0.08))
                                .widgetAccentable()
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(isSelected ? Color.yellow : Color.clear, lineWidth: 1)
                                .widgetAccentable()
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if state.selectedSpellIDs.count == 3 {
                Button(intent: StartGameIntent()) {
                    Text("Play")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(.green.opacity(0.4)).widgetAccentable())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    // MARK: - Help

    private var helpView: some View {
        VStack(spacing: 4) {
            Text("How to Play")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.yellow)
                .widgetAccentable()

            VStack(alignment: .leading, spacing: 3) {
                helpLine("1.", "Pick 3 spells, then tap Play")
                helpLine("2.", "Tap a spell, then a hex to cast")
                helpLine("3.", "Lower enemy HP to 0 to win")
                helpLine("4.", "Tap \u{24D8} on spells for stats")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(intent: DismissHelpIntent()) {
                Text("Got it!")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.blue.opacity(0.4)).widgetAccentable())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }

    private func helpLine(_ num: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Text(num)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.yellow)
            Text(text)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    // MARK: - Gameplay (hex right, controls left)

    private var gameplayView: some View {
        HStack(spacing: 4) {
            // Left side: status + spells + back
            VStack(spacing: 3) {
                // Status
                HStack(spacing: 2) {
                    Text("\u{2764}\(state.playerHP)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.red)
                        .widgetAccentable()
                    Spacer()
                    Text("\u{2605}\(state.challengeCount)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.yellow)
                        .widgetAccentable()
                }

                // Spell buttons (vertical stack)
                ForEach(state.spellIDs, id: \.self) { spellID in
                    let spell = WidgetGameEngine.resolveSpell(spellID)
                    let isSelected = state.selectedSpellID == spellID

                    Button(intent: SelectSpellIntent(spellID: spellID)) {
                        HStack(spacing: 3) {
                            Image(systemName: sfSymbol(for: spell))
                                .font(.system(size: 10))
                                .foregroundStyle(spellColor(for: spell))
                                .widgetAccentable()
                            Text(spell.watchName)
                                .font(.system(size: 7, weight: .medium))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            // Info button
                            Button(intent: ShowSpellInfoIntent(spellID: spellID)) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isSelected ? Color.yellow.opacity(0.3) : Color.white.opacity(0.08))
                                .widgetAccentable()
                        )
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)

                // Back button
                Button(intent: BackToSelectionIntent()) {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 8))
                        Text("Back")
                            .font(.system(size: 8, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .frame(width: 90)

            // Right side: hex grid (takes remaining space)
            WidgetHexGridView(state: state)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }

    // MARK: - Targeting (hex right, spell info + cancel left)

    private var targetingView: some View {
        HStack(spacing: 4) {
            // Left side: selected spell + cancel
            VStack(spacing: 4) {
                if let id = state.selectedSpellID {
                    let spell = WidgetGameEngine.resolveSpell(id)
                    VStack(spacing: 2) {
                        Image(systemName: sfSymbol(for: spell))
                            .font(.system(size: 16))
                            .foregroundStyle(spellColor(for: spell))
                            .widgetAccentable()
                        Text(spell.watchName)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.yellow)
                            .widgetAccentable()
                        Text("Tap a hex")
                            .font(.system(size: 8))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                Spacer(minLength: 0)

                HStack(spacing: 2) {
                    Text("\u{2764}\(state.playerHP)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.red)
                        .widgetAccentable()
                    Spacer()
                    Text("\u{2605}\(state.challengeCount)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.yellow)
                        .widgetAccentable()
                }

                Button(intent: SelectSpellIntent(spellID: "move")) {
                    Text("Cancel")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }
            .frame(width: 90)

            // Right side: hex grid with directional buttons
            ZStack {
                WidgetHexGridView(state: state)

                GeometryReader { geo in
                    let hexSize = min(geo.size.width / 5.0, geo.size.height / CGFloat(3.0 * sqrt(3.0)))
                    let layout = HexLayout(
                        hexSize: hexSize,
                        origin: CGPoint(x: geo.size.width / 2, y: geo.size.height / 2),
                        flatTop: true
                    )

                    ForEach(0..<6, id: \.self) { dirIndex in
                        let neighbor = HexCoord.zero.neighbors()[dirIndex]
                        let center = layout.hexToScreen(neighbor)

                        Button(intent: TargetHexIntent(directionIndex: dirIndex)) {
                            Color.clear
                                .frame(width: hexSize * 1.5, height: hexSize * 1.5)
                        }
                        .buttonStyle(.plain)
                        .position(x: center.x, y: center.y)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }

    // MARK: - Spell Info

    private var spellInfoView: some View {
        VStack(spacing: 6) {
            if let id = state.infoSpellID {
                let spell = WidgetGameEngine.resolveSpell(id)

                HStack(spacing: 6) {
                    Image(systemName: sfSymbol(for: spell))
                        .font(.system(size: 18))
                        .foregroundStyle(spellColor(for: spell))
                        .widgetAccentable()
                    Text(spell.name)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                // Stats grid
                HStack(spacing: 12) {
                    if spell.isOffensive {
                        statBadge("ATK", "d\(spell.offenseDie)", .red)
                    }
                    if spell.isDefensive {
                        statBadge("DEF", "d\(spell.defenseDie)", .green)
                    }
                    statBadge("RNG", "\(spell.range)", .blue)
                    if spell.isAoE {
                        statBadge("AOE", "\u{2713}", .orange)
                    }
                    if spell.causesParalysis {
                        statBadge("STUN", "\u{2713}", .purple)
                    }
                }
                .widgetAccentable()

                Text(spell.description)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            Button(intent: DismissSpellInfoIntent()) {
                Text("Back")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.15)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private func statBadge(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .widgetAccentable()
            Text(label)
                .font(.system(size: 6, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Victory / Game Over

    private var victoryView: some View {
        VStack(spacing: 6) {
            Text("Victory!")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.yellow)
                .widgetAccentable()
            Text("Score: \(state.challengeCount)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Button(intent: NextChallengeIntent()) {
                Text("Next Challenge")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.green.opacity(0.4)).widgetAccentable())
            }
            .buttonStyle(.plain)
        }
    }

    private var gameOverView: some View {
        VStack(spacing: 6) {
            Text("Game Over")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.red)
                .widgetAccentable()
            Text("Score: \(state.challengeCount)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Button(intent: NewGameIntent()) {
                Text("New Game")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.blue.opacity(0.4)).widgetAccentable())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Spell Display Helpers

    private func sfSymbol(for spell: Spell) -> String {
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

    private func spellColor(for spell: Spell) -> Color {
        if spell.isOffensive && spell.isDefensive { return .yellow }
        if spell.isOffensive && spell.causesParalysis { return .purple }
        if spell.isDefensive && spell.causesParalysis { return .mint }
        if spell.isOffensive { return .red }
        if spell.isDefensive { return .green }
        return .blue
    }
}
