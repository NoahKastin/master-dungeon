//
//  HexGrid.swift
//  Master Dungeon
//
//  Hex coordinate system using cube coordinates for the isometric grid.
//  Visible area: 5 hexes in each direction from player (11x11 diamond).
//

#if canImport(SpriteKit)
import SpriteKit
#else
import CoreGraphics
#endif

// MARK: - Cube Coordinates

/// Cube coordinates for hex grid (q + r + s = 0 invariant)
struct HexCoord: Hashable, Equatable {
    let q: Int  // column
    let r: Int  // row
    var s: Int { -q - r }  // derived, maintains invariant

    static let zero = HexCoord(q: 0, r: 0)

    /// All six directions in cube coordinates
    static let directions: [HexCoord] = [
        HexCoord(q: 1, r: 0),   // E
        HexCoord(q: 1, r: -1),  // NE
        HexCoord(q: 0, r: -1),  // NW
        HexCoord(q: -1, r: 0),  // W
        HexCoord(q: -1, r: 1),  // SW
        HexCoord(q: 0, r: 1)    // SE
    ]

    func neighbor(_ direction: Int) -> HexCoord {
        let dir = HexCoord.directions[direction % 6]
        return self + dir
    }

    func neighbors() -> [HexCoord] {
        HexCoord.directions.map { self + $0 }
    }

    /// Manhattan distance in hex grid
    func distance(to other: HexCoord) -> Int {
        (abs(q - other.q) + abs(r - other.r) + abs(s - other.s)) / 2
    }

    /// All hexes within given range
    func hexesInRange(_ range: Int) -> [HexCoord] {
        var results: [HexCoord] = []
        for dq in -range...range {
            for dr in max(-range, -dq - range)...min(range, -dq + range) {
                results.append(HexCoord(q: q + dq, r: r + dr))
            }
        }
        return results
    }

    static func + (lhs: HexCoord, rhs: HexCoord) -> HexCoord {
        HexCoord(q: lhs.q + rhs.q, r: lhs.r + rhs.r)
    }

    static func - (lhs: HexCoord, rhs: HexCoord) -> HexCoord {
        HexCoord(q: lhs.q - rhs.q, r: lhs.r - rhs.r)
    }
}

// MARK: - Hex Grid Layout

/// Handles conversion between hex coordinates and screen positions
class HexLayout {
    let hexSize: CGFloat  // Distance from center to corner
    let origin: CGPoint
    let flatTop: Bool

    // Orientation matrices (set based on flatTop)
    private let f0: CGFloat
    private let f1: CGFloat
    private let f2: CGFloat
    private let f3: CGFloat

    private let b0: CGFloat
    private let b1: CGFloat
    private let b2: CGFloat
    private let b3: CGFloat

    // Starting angle for corners (flat-top: 0°, pointy-top: 30°)
    private let startAngle: CGFloat

    init(hexSize: CGFloat, origin: CGPoint = .zero, flatTop: Bool = false) {
        self.hexSize = hexSize
        self.origin = origin
        self.flatTop = flatTop

        if flatTop {
            // Flat-top hex orientation (rotated 30° from pointy-top)
            f0 = 3.0 / 2.0
            f1 = 0.0
            f2 = sqrt(3.0) / 2.0
            f3 = sqrt(3.0)

            b0 = 2.0 / 3.0
            b1 = 0.0
            b2 = -1.0 / 3.0
            b3 = sqrt(3.0) / 3.0

            startAngle = 0.0
        } else {
            // Pointy-top hex orientation
            f0 = sqrt(3.0)
            f1 = sqrt(3.0) / 2.0
            f2 = 0.0
            f3 = 3.0 / 2.0

            b0 = sqrt(3.0) / 3.0
            b1 = -1.0 / 3.0
            b2 = 0.0
            b3 = 2.0 / 3.0

            startAngle = 30.0
        }
    }

    /// Convert hex coordinate to screen position
    func hexToScreen(_ hex: HexCoord) -> CGPoint {
        let x = (f0 * CGFloat(hex.q) + f1 * CGFloat(hex.r)) * hexSize
        let y = (f2 * CGFloat(hex.q) + f3 * CGFloat(hex.r)) * hexSize
        return CGPoint(x: x + origin.x, y: y + origin.y)
    }

    /// Convert screen position to hex coordinate
    func screenToHex(_ point: CGPoint) -> HexCoord {
        let pt = CGPoint(x: (point.x - origin.x) / hexSize,
                         y: (point.y - origin.y) / hexSize)
        let q = b0 * pt.x + b1 * pt.y
        let r = b2 * pt.x + b3 * pt.y
        return cubeRound(q: q, r: r)
    }

    /// Round fractional cube coordinates to nearest hex
    private func cubeRound(q: CGFloat, r: CGFloat) -> HexCoord {
        let s = -q - r
        var rq = round(q)
        var rr = round(r)
        let rs = round(s)

        let qDiff = abs(rq - q)
        let rDiff = abs(rr - r)
        let sDiff = abs(rs - s)

        if qDiff > rDiff && qDiff > sDiff {
            rq = -rr - rs
        } else if rDiff > sDiff {
            rr = -rq - rs
        }

        return HexCoord(q: Int(rq), r: Int(rr))
    }

    /// Get the 6 corner points of a hex for drawing
    func hexCorners(_ hex: HexCoord) -> [CGPoint] {
        let center = hexToScreen(hex)
        var corners: [CGPoint] = []
        for i in 0..<6 {
            let angle = CGFloat.pi / 180.0 * (60.0 * CGFloat(i) + startAngle)
            corners.append(CGPoint(
                x: center.x + hexSize * cos(angle),
                y: center.y + hexSize * sin(angle)
            ))
        }
        return corners
    }
}

// MARK: - Pathfinding

/// A* pathfinding on hex grid
class HexPathfinder {

    struct Node: Comparable {
        let coord: HexCoord
        let gCost: Int  // Cost from start
        let hCost: Int  // Heuristic to goal
        var fCost: Int { gCost + hCost }

        static func < (lhs: Node, rhs: Node) -> Bool {
            lhs.fCost < rhs.fCost
        }
    }

    /// Find path from start to goal, avoiding blocked hexes
    static func findPath(from start: HexCoord, to goal: HexCoord, blocked: Set<HexCoord>) -> [HexCoord]? {
        if start == goal { return [start] }
        if blocked.contains(goal) { return nil }

        var openSet: [Node] = [Node(coord: start, gCost: 0, hCost: start.distance(to: goal))]
        var closedSet: Set<HexCoord> = []
        var cameFrom: [HexCoord: HexCoord] = [:]
        var gScore: [HexCoord: Int] = [start: 0]

        while !openSet.isEmpty {
            openSet.sort(by: >)  // Sort descending so we can popLast
            let current = openSet.removeLast()

            if current.coord == goal {
                return reconstructPath(cameFrom: cameFrom, current: goal)
            }

            closedSet.insert(current.coord)

            for neighbor in current.coord.neighbors() {
                if closedSet.contains(neighbor) || blocked.contains(neighbor) {
                    continue
                }

                let tentativeG = current.gCost + 1

                if tentativeG < (gScore[neighbor] ?? Int.max) {
                    cameFrom[neighbor] = current.coord
                    gScore[neighbor] = tentativeG

                    if !openSet.contains(where: { $0.coord == neighbor }) {
                        openSet.append(Node(
                            coord: neighbor,
                            gCost: tentativeG,
                            hCost: neighbor.distance(to: goal)
                        ))
                    }
                }
            }
        }

        return nil  // No path found
    }

    private static func reconstructPath(cameFrom: [HexCoord: HexCoord], current: HexCoord) -> [HexCoord] {
        var path = [current]
        var node = current
        while let previous = cameFrom[node] {
            path.insert(previous, at: 0)
            node = previous
        }
        return path
    }
}

#if canImport(SpriteKit)
// MARK: - Hex Sprite

/// Visual representation of a single hex tile
class HexSprite: SKShapeNode {
    let localCoord: HexCoord  // Position relative to player (player is always at 0,0)
    var isBlocked: Bool = false
    var isHighlighted: Bool = false {
        didSet { updateAppearance() }
    }
    var highlightColor: SKColor = SKColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.8)

    init(localCoord: HexCoord, layout: HexLayout) {
        self.localCoord = localCoord
        super.init()

        // Create path with corners relative to (0,0) - the node's local origin
        // Use the same starting angle as the layout (flat-top: 0°, pointy-top: 30°)
        let startAngle: CGFloat = layout.flatTop ? 0.0 : 30.0
        let path = CGMutablePath()
        for i in 0..<6 {
            let angle = CGFloat.pi / 180.0 * (60.0 * CGFloat(i) + startAngle)
            let corner = CGPoint(
                x: layout.hexSize * cos(angle),
                y: layout.hexSize * sin(angle)
            )
            if i == 0 {
                path.move(to: corner)
            } else {
                path.addLine(to: corner)
            }
        }
        path.closeSubpath()

        self.path = path
        // Position at the screen location for this local coordinate
        // (relative to screen center, which is where the player appears)
        self.position = layout.hexToScreen(localCoord)
        self.strokeColor = SKColor(white: 0.3, alpha: 1.0)
        self.lineWidth = 1.0
        self.fillColor = SKColor(white: 0.1, alpha: 0.8)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateAppearance() {
        if isHighlighted {
            fillColor = highlightColor
        } else if isBlocked {
            fillColor = SKColor(white: 0.05, alpha: 0.9)
        } else {
            fillColor = SKColor(white: 0.1, alpha: 0.8)
        }
    }
}
#endif
