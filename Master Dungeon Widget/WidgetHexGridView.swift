//
//  WidgetHexGridView.swift
//  Master Dungeon Widget
//
//  Canvas-based hex grid for widget display, ported from WatchHexGridView.
//

import SwiftUI
import WidgetKit

/// Content occupying a hex on the widget grid
enum WidgetHexContent {
    case empty
    case player(hp: Int)
    case enemy(hp: Int)
    case obstacle(hp: Int)
    case npc(currentHP: Int, maxHP: Int)
    case target
    case darkness(dispelled: Bool)
}

struct WidgetHexGridView: View {
    let state: WidgetGameState

    private let hexCoords: [HexCoord] = {
        let center = HexCoord.zero
        return [center] + center.neighbors()
    }()

    var body: some View {
        GeometryReader { geo in
            let hexSize = min(geo.size.width / 5.0, geo.size.height / CGFloat(3.0 * sqrt(3.0)))
            let layout = HexLayout(
                hexSize: hexSize,
                origin: CGPoint(x: geo.size.width / 2, y: geo.size.height / 2),
                flatTop: true
            )

            // Canvas draws hex shapes only — marked accentable so it gets tinted,
            // while text overlays stay in the non-accent (visible) layer
            Canvas { context, size in
                let canvasLayout = HexLayout(
                    hexSize: min(size.width / 5.0, size.height / CGFloat(3.0 * sqrt(3.0))),
                    origin: CGPoint(x: size.width / 2, y: size.height / 2),
                    flatTop: true
                )

                for coord in hexCoords {
                    let corners = canvasLayout.hexCorners(coord)
                    var path = Path()
                    if let first = corners.first {
                        path.move(to: first)
                        for corner in corners.dropFirst() {
                            path.addLine(to: corner)
                        }
                        path.closeSubpath()
                    }

                    let content = hexContent(at: coord)
                    let fillColor = hexFillColor(for: content)
                    let isHighlighted = state.phase == .selectTarget && coord != .zero

                    context.fill(path, with: .color(fillColor))

                    let strokeColor: Color = isHighlighted ? .yellow : Color(white: 0.35)
                    let lineWidth: CGFloat = isHighlighted ? 2.0 : 1.0
                    context.stroke(path, with: .color(strokeColor), lineWidth: lineWidth)
                }
            }
            .widgetAccentable()

            // SwiftUI Text overlays — rendered as separate layer, survives tinting
            ForEach(Array(hexCoords.enumerated()), id: \.offset) { _, coord in
                let content = hexContent(at: coord)
                let center = layout.hexToScreen(coord)
                let fontSize = hexSize * 0.5

                hexLabel(content: content, fontSize: fontSize)
                    .position(x: center.x, y: center.y)
            }
        }
    }

    @ViewBuilder
    private func hexLabel(content: WidgetHexContent, fontSize: CGFloat) -> some View {
        switch content {
        case .player(let hp):
            Text("\(hp)")
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(.white)

        case .enemy(let hp):
            Text("\(hp)")
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(.white)

        case .npc(let hp, let maxHP):
            Text("\(hp)/\(maxHP)")
                .font(.system(size: fontSize * 0.7, weight: .medium))
                .foregroundStyle(.white)

        case .target:
            Text("\u{2605}")
                .font(.system(size: fontSize))
                .foregroundStyle(.black)

        case .darkness(let dispelled):
            if !dispelled {
                Text("?")
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundStyle(.gray)
            }

        case .obstacle(let hp):
            if hp > 0 {
                Text("\(hp)")
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundStyle(.orange)
            }

        case .empty:
            EmptyView()
        }
    }

    private func hexContent(at coord: HexCoord) -> WidgetHexContent {
        let playerPos = state.playerPosition.hexCoord
        let worldPos = coord + playerPos

        if coord == .zero {
            return .player(hp: state.playerHP)
        }

        // Check enemies
        for enemy in state.enemies where enemy.hp > 0 {
            if enemy.position.hexCoord == worldPos {
                // Check if in undispelled darkness
                let inDarkness = state.interactives.contains { interactive in
                    interactive.kind == "darkness" && !interactive.dispelled &&
                    worldPos.distance(to: interactive.position.hexCoord) <= interactive.radius
                }
                if inDarkness {
                    return .darkness(dispelled: false)
                }
                return .enemy(hp: enemy.hp)
            }
        }

        // Check interactives
        for interactive in state.interactives {
            if interactive.position.hexCoord == worldPos {
                switch interactive.kind {
                case "target": return .target
                case "npc": return .npc(currentHP: interactive.currentHP, maxHP: interactive.maxHP)
                case "darkness": return .darkness(dispelled: interactive.dispelled)
                default: return .target
                }
            }
        }

        // Check obstacles
        for obstacle in state.obstacles {
            if obstacle.position.hexCoord == worldPos {
                return .obstacle(hp: obstacle.hp)
            }
        }

        // Check blocked (indestructible)
        if state.blockedHexes.contains(where: { $0.hexCoord == worldPos }) {
            return .obstacle(hp: 0)
        }

        return .empty
    }

    private func hexFillColor(for content: WidgetHexContent) -> Color {
        switch content {
        case .empty: return Color(white: 0.1)
        case .player: return Color(red: 0.2, green: 0.4, blue: 0.8)
        case .enemy: return Color(red: 0.7, green: 0.15, blue: 0.15)
        case .obstacle(let hp): return hp > 0 ? Color(red: 0.5, green: 0.35, blue: 0.15) : Color(white: 0.2)
        case .npc: return Color(red: 0.15, green: 0.6, blue: 0.25)
        case .target: return Color(red: 0.8, green: 0.7, blue: 0.2)
        case .darkness(let dispelled): return dispelled ? Color(white: 0.1) : Color(red: 0.15, green: 0.05, blue: 0.25)
        }
    }
}
