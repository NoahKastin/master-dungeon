//
//  WatchGameView.swift
//  Master Dungeon Watch
//
//  Main game screen: hex grid fills the screen.
//  Score top-left, time top-right (system), back bottom-left, spell bottom-right.
//  Digital Crown controls spell selection and target selection.
//

import SwiftUI
import WatchKit

struct WatchGameView: View {
    let loadout: SpellLoadout
    @State private var engine = WatchGameEngine()
    @State private var crownValue: Double = 0.0
    @State private var showGameOver = false
    @State private var showObjective = false
    @State private var objectiveText = ""
    @State private var showSpellInfo = false
    @State private var spellInfoText = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geo in
            let hexSize = min(geo.size.width / 5.0, geo.size.height / CGFloat(3.0 * sqrt(3.0)))
            let gridHeight = hexSize * CGFloat(3.0 * sqrt(3.0))

            ZStack {
                // Hex grid centered
                WatchHexGridView(engine: engine, hexSize: hexSize, playerHP: engine.playerHP)
                    .frame(width: geo.size.width, height: gridHeight)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)

                // Bottom-left: back button
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .position(x: 28, y: geo.size.height - 24)

                // Bottom-right: spell icon
                WatchSpellBarView(engine: engine) { spell in
                    spellInfoText = "\(spell.watchName): \(spell.description)"
                    withAnimation { showSpellInfo = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation { showSpellInfo = false }
                    }
                }
                .position(x: geo.size.width - 28, y: geo.size.height - 24)

                // Overlays
                if showObjective {
                    Text(objectiveText)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.black.opacity(0.85))
                        )
                        .transition(.opacity)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                        .onTapGesture {
                            withAnimation { showObjective = false }
                        }
                }

                if showSpellInfo {
                    Text(spellInfoText)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.blue.opacity(0.85))
                        )
                        .transition(.opacity)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                        .onTapGesture {
                            withAnimation { showSpellInfo = false }
                        }
                }
            }
        }
        .ignoresSafeArea()
        .focusable()
        .digitalCrownRotation(
            $crownValue,
            from: 0,
            through: crownUpperBound,
            by: 1.0,
            sensitivity: .medium,
            isContinuous: true,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownValue) { _, newValue in
            let index = Int(newValue.rounded())
            if engine.isTargeting {
                engine.cycleTarget(index)
            } else {
                engine.selectSpellIndex(index)
            }
        }
        .onTapGesture {
            if showSpellInfo {
                withAnimation { showSpellInfo = false }
                return
            }
            if showObjective {
                withAnimation { showObjective = false }
                return
            }
            if engine.isTargeting {
                engine.confirmCast()
                crownValue = Double(engine.selectedSpellIndex)
            } else {
                engine.enterTargeting()
                if engine.isTargeting {
                    crownValue = 0
                }
            }
        }
        .onChange(of: engine.challengeDescription) { _, newDesc in
            guard !newDesc.isEmpty else { return }
            objectiveText = newDesc
            withAnimation { showObjective = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation { showObjective = false }
            }
        }
        .onChange(of: engine.isGameOver) { _, gameOver in
            if gameOver {
                showGameOver = true
            }
        }
        .sheet(isPresented: $showGameOver) {
            WatchGameOverView(score: engine.challengeCount) {
                showGameOver = false
                dismiss()
            }
        }
        .onAppear {
            engine.startGame(with: loadout)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Text("\(engine.challengeCount)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.yellow)
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private var crownUpperBound: Double {
        if engine.isTargeting {
            return 5.0
        }
        return max(0, Double(engine.spells.count - 1))
    }
}
