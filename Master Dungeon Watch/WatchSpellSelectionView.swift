//
//  WatchSpellSelectionView.swift
//  Master Dungeon Watch
//
//  Spell selection screen — pick 3 of 9 easy spells. Serves as the home screen.
//

import SwiftUI

struct WatchSpellSelectionView: View {
    @State private var selectedIDs: Set<String> = []
    @State private var navigateToGame = false
    @State private var showHelp = false
    private let allSpells = SpellData.easySpells

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                HStack {
                    Text("Choose 3 Spells")
                        .font(.headline)

                    Spacer()

                    Button {
                        showHelp = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)

                ForEach(allSpells) { spell in
                    Button {
                        toggleSpell(spell)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: sfSymbol(for: spell))
                                .foregroundStyle(spellColor(for: spell))
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(spell.watchName)
                                    .font(.system(.body, design: .rounded))
                                    .lineLimit(1)

                                Text(spell.description)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            if selectedIDs.contains(spell.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedIDs.contains(spell.id) ? Color.white.opacity(0.12) : Color.clear)
                    )
                }

                NavigationLink(value: "game") {
                    Text("Play")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .disabled(selectedIDs.count != 3)
                .opacity(selectedIDs.count == 3 ? 1.0 : 0.4)
                .padding(.top, 8)
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Dungeon")
        .navigationDestination(for: String.self) { _ in
            WatchGameView(loadout: buildLoadout())
        }
        .sheet(isPresented: $showHelp) {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("How to Play")
                        .font(.headline)
                        .padding(.bottom, 4)

                    Text("Lower enemy HP to 0 with offensive spells. Keep your own HP up with healing spells. Long-press a spell to see its stats.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)

                    ForEach(allSpells) { spell in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Image(systemName: sfSymbol(for: spell))
                                    .foregroundStyle(spellColor(for: spell))
                                    .frame(width: 16)
                                Text(spell.watchName)
                                    .font(.system(.body, design: .rounded, weight: .semibold))
                            }
                            Text(spell.description)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                if spell.isOffensive {
                                    Text("d\(spell.offenseDie) dmg")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.red)
                                }
                                if spell.isDefensive {
                                    Text("d\(spell.defenseDie) heal")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.green)
                                }
                                if spell.causesParalysis {
                                    Text("stun")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.purple)
                                }
                                if spell.isAoE {
                                    Text("AoE")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.orange)
                                }
                                if spell.producesLight {
                                    Text("light")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.yellow)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(.horizontal, 8)
            }
        }
    }

    private func toggleSpell(_ spell: Spell) {
        if selectedIDs.contains(spell.id) {
            selectedIDs.remove(spell.id)
        } else if selectedIDs.count < 3 {
            selectedIDs.insert(spell.id)
        }
    }

    private func buildLoadout() -> SpellLoadout {
        var loadout = SpellLoadout()
        for spell in allSpells where selectedIDs.contains(spell.id) {
            _ = loadout.addSpell(spell)
        }
        return loadout
    }

    private func sfSymbol(for spell: Spell) -> String {
        switch spell.id {
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
