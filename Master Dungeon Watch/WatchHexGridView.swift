//
//  WatchHexGridView.swift
//  Master Dungeon Watch
//
//  Draws the 7-hex flat-top grid using SwiftUI Canvas.
//

import SwiftUI

struct WatchHexGridView: View {
    var engine: WatchGameEngine
    let hexSize: CGFloat
    var playerHP: Int = 0

    private let hexCoords: [HexCoord] = {
        let center = HexCoord.zero
        return [center] + center.neighbors()
    }()

    var body: some View {
        Canvas { context, size in
            let layout = HexLayout(
                hexSize: hexSize,
                origin: CGPoint(x: size.width / 2, y: size.height / 2),
                flatTop: true
            )

            for coord in hexCoords {
                let corners = layout.hexCorners(coord)
                var path = Path()
                if let first = corners.first {
                    path.move(to: first)
                    for corner in corners.dropFirst() {
                        path.addLine(to: corner)
                    }
                    path.closeSubpath()
                }

                let content = engine.hexContents[coord] ?? .empty
                let fillColor = hexFillColor(for: content)
                let isHighlighted = engine.highlightedHex == coord

                context.fill(path, with: .color(fillColor))

                let strokeColor: Color = isHighlighted ? .yellow : Color(white: 0.35)
                let lineWidth: CGFloat = isHighlighted ? 2.5 : 1.0
                context.stroke(path, with: .color(strokeColor), lineWidth: lineWidth)

                // Draw content labels
                let center = layout.hexToScreen(coord)
                drawContentLabel(context: &context, at: center, content: content)
            }
        }
    }

    private func hexFillColor(for content: HexContent) -> Color {
        switch content {
        case .empty: return Color(white: 0.1)
        case .player: return Color(red: 0.2, green: 0.4, blue: 0.8)
        case .enemy: return Color(red: 0.7, green: 0.15, blue: 0.15)
        case .obstacle(let hp): return hp > 0 ? Color(red: 0.5, green: 0.35, blue: 0.15) : Color(white: 0.2)
        case .npc: return Color(red: 0.15, green: 0.6, blue: 0.25)
        case .target: return Color(red: 0.8, green: 0.7, blue: 0.2)
        case .darkness(let dispelled): return dispelled ? Color(white: 0.1) : Color(red: 0.15, green: 0.05, blue: 0.25)
        case .hazard: return Color(red: 0.8, green: 0.4, blue: 0.1)
        }
    }

    private func drawContentLabel(context: inout GraphicsContext, at center: CGPoint, content: HexContent) {
        let fontSize: CGFloat = hexSize * 0.55

        switch content {
        case .player:
            let text = Text("\(playerHP)").font(.system(size: fontSize, weight: .bold)).foregroundColor(.white)
            context.draw(text, at: center)

        case .enemy(let enemy):
            let text = Text("\(enemy.hp)").font(.system(size: fontSize, weight: .bold)).foregroundColor(.white)
            context.draw(text, at: center)

        case .npc(let hp, let maxHP):
            let text = Text("\(hp)/\(maxHP)").font(.system(size: fontSize * 0.7, weight: .medium)).foregroundColor(.white)
            context.draw(text, at: center)

        case .target:
            let text = Text("\u{2605}").font(.system(size: fontSize)).foregroundColor(.black)
            context.draw(text, at: center)

        case .darkness(let dispelled):
            if !dispelled {
                let text = Text("?").font(.system(size: fontSize, weight: .bold)).foregroundColor(.gray)
                context.draw(text, at: center)
            }

        case .obstacle(let hp):
            if hp > 0 {
                let text = Text("\(hp)").font(.system(size: fontSize, weight: .bold)).foregroundColor(.orange)
                context.draw(text, at: center)
            }

        default:
            break
        }
    }
}
