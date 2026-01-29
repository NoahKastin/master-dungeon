//
//  Master_DungeonTests.swift
//  Master DungeonTests
//
//  Tests for core game systems.
//

import Testing
@testable import Master_Dungeon

// MARK: - Hex Coordinate Tests

@MainActor
struct HexCoordTests {
    @Test func hexDistanceCalculation() {
        let origin = HexCoord(q: 0, r: 0)
        let adjacent = HexCoord(q: 1, r: 0)
        let farAway = HexCoord(q: 3, r: -2)

        #expect(origin.distance(to: origin) == 0)
        #expect(origin.distance(to: adjacent) == 1)
        #expect(origin.distance(to: farAway) == 3)
    }

    @Test func hexNeighbors() {
        let origin = HexCoord(q: 0, r: 0)
        let neighbors = origin.neighbors()

        #expect(neighbors.count == 6)
        for neighbor in neighbors {
            #expect(origin.distance(to: neighbor) == 1)
        }
    }

    @Test func hexesInRange() {
        let origin = HexCoord(q: 0, r: 0)

        let range0 = origin.hexesInRange(0)
        #expect(range0.count == 1)

        let range1 = origin.hexesInRange(1)
        #expect(range1.count == 7)  // Center + 6 neighbors

        let range2 = origin.hexesInRange(2)
        #expect(range2.count == 19)  // 1 + 6 + 12
    }

    @Test func hexAddition() {
        let a = HexCoord(q: 1, r: 2)
        let b = HexCoord(q: 3, r: -1)
        let sum = a + b

        #expect(sum.q == 4)
        #expect(sum.r == 1)
    }

    @Test func hexCubeInvariant() {
        // q + r + s should always equal 0
        let coord = HexCoord(q: 5, r: -3)
        #expect(coord.q + coord.r + coord.s == 0)
    }
}

// MARK: - Pathfinding Tests

@MainActor
struct PathfindingTests {
    @Test func pathToSelf() {
        let start = HexCoord(q: 0, r: 0)
        let path = HexPathfinder.findPath(from: start, to: start, blocked: [])

        #expect(path != nil)
        #expect(path?.count == 1)
    }

    @Test func pathToAdjacent() {
        let start = HexCoord(q: 0, r: 0)
        let end = HexCoord(q: 1, r: 0)
        let path = HexPathfinder.findPath(from: start, to: end, blocked: [])

        #expect(path != nil)
        #expect(path?.count == 2)
    }

    @Test func pathAroundObstacle() {
        let start = HexCoord(q: 0, r: 0)
        let end = HexCoord(q: 2, r: 0)
        let blocked: Set<HexCoord> = [HexCoord(q: 1, r: 0)]  // Block direct path

        let path = HexPathfinder.findPath(from: start, to: end, blocked: blocked)

        #expect(path != nil)
        #expect(path!.count > 2)  // Should take longer route
        #expect(!path!.contains(HexCoord(q: 1, r: 0)))  // Should not contain blocked hex
    }

    @Test func noPathWhenBlocked() {
        let start = HexCoord(q: 0, r: 0)
        let end = HexCoord(q: 1, r: 0)
        let blocked: Set<HexCoord> = [end]  // Block destination

        let path = HexPathfinder.findPath(from: start, to: end, blocked: blocked)

        #expect(path == nil)
    }
}

// MARK: - Spell Tests

@MainActor
struct SpellTests {
    @Test func spellDataLoaded() {
        #expect(SpellData.allSpells.count == 17)  // Updated spell count
    }

    @Test func spellLookupById() {
        let spell = SpellData.spell(byId: "magic-missile")

        #expect(spell != nil)
        #expect(spell?.name == "Magic Missile")
        #expect(spell?.manaCost == 3)
        #expect(spell?.range == 3)
    }

    @Test func spellCapabilities() {
        let spell = SpellData.spell(byId: "burning-hands")!
        let caps = spell.capabilityTags

        #expect(caps.contains(.damage))
        #expect(caps.contains(.areaEffect))
    }

    @Test func spellsByManaCostSorted() {
        let sorted = SpellData.spellsByManaCost
        for i in 0..<(sorted.count - 1) {
            #expect(sorted[i].manaCost <= sorted[i + 1].manaCost)
        }
    }

    @Test func passSpellRestoresMana() {
        let pass = SpellData.passSpell
        #expect(pass.manaCost == -4)  // Restores 4 mana
    }
}

// MARK: - Loadout Tests

@MainActor
struct LoadoutTests {
    @Test func emptyLoadout() {
        let loadout = SpellLoadout()

        #expect(loadout.spells.isEmpty)
        #expect(loadout.totalManaCost == 0)
    }

    @Test func addSpellToLoadout() {
        var loadout = SpellLoadout()
        let spell = SpellData.spell(byId: "cure-wounds")!

        let success = loadout.addSpell(spell)

        #expect(success == true)
        #expect(loadout.spells.count == 1)
        #expect(loadout.totalManaCost == 2)
    }

    @Test func cannotAddDuplicateSpell() {
        var loadout = SpellLoadout()
        let spell = SpellData.spell(byId: "cure-wounds")!

        _ = loadout.addSpell(spell)
        let secondAdd = loadout.addSpell(spell)

        #expect(secondAdd == false)
        #expect(loadout.spells.count == 1)
    }

    @Test func cannotExceedSpellLimit() {
        var loadout = SpellLoadout()

        // Add 3 spells (max allowed)
        _ = loadout.addSpell(SpellData.spell(byId: "magic-missile")!)
        _ = loadout.addSpell(SpellData.spell(byId: "cure-wounds")!)
        _ = loadout.addSpell(SpellData.spell(byId: "burning-hands")!)

        // Try to add a 4th
        let fourthSpell = loadout.addSpell(SpellData.spell(byId: "acid-splash")!)

        #expect(fourthSpell == false)
        #expect(loadout.selectableSpellCount == 3)
    }

    @Test func passSpellAlwaysAllowed() {
        var loadout = SpellLoadout()
        let success = loadout.addSpell(SpellData.passSpell)

        #expect(success == true)
        #expect(loadout.spells.contains(SpellData.passSpell))
    }

    @Test func removeSpellFromLoadout() {
        var loadout = SpellLoadout()
        let spell = SpellData.spell(byId: "cure-wounds")!

        _ = loadout.addSpell(spell)
        loadout.removeSpell(spell)

        #expect(loadout.spells.isEmpty)
        #expect(loadout.totalManaCost == 0)
    }

    @Test func loadoutCapabilities() {
        var loadout = SpellLoadout()
        _ = loadout.addSpell(SpellData.spell(byId: "burning-hands")!)
        _ = loadout.addSpell(SpellData.spell(byId: "cure-wounds")!)

        #expect(loadout.hasCapability(.damage))
        #expect(loadout.hasCapability(.healing))
        #expect(loadout.hasCapability(.areaEffect))
    }
}

// MARK: - Challenge Generation Tests

@MainActor
struct ChallengeGeneratorTests {
    @Test func generatesChallengeForLoadout() {
        var loadout = SpellLoadout()
        _ = loadout.addSpell(SpellData.spell(byId: "magic-missile")!)
        _ = loadout.addSpell(SpellData.spell(byId: "cure-wounds")!)

        let generator = ChallengeGenerator()
        let challenge = generator.generateChallenge(for: loadout)

        #expect(!challenge.description.isEmpty)
        #expect(!challenge.elements.isEmpty)
    }

    @Test func deterministicWithSeed() {
        let loadout = SpellLoadout()

        let generator1 = ChallengeGenerator(seed: 42)
        let generator2 = ChallengeGenerator(seed: 42)

        let challenge1 = generator1.generateChallenge(for: loadout)
        let challenge2 = generator2.generateChallenge(for: loadout)

        #expect(challenge1.type == challenge2.type)
    }
}

// MARK: - Player Tests

@MainActor
struct PlayerTests {
    @Test func playerInitialState() {
        let player = Player()

        #expect(player.hp == Player.maxHP)
        #expect(player.mana == Player.maxMana)
        #expect(player.isAlive)
    }

    @Test func playerTakesDamage() {
        let player = Player()
        player.takeDamage(2)

        #expect(player.hp == Player.maxHP - 2)
        #expect(player.isAlive)
    }

    @Test func playerCanDie() {
        let player = Player()
        player.takeDamage(Player.maxHP)

        #expect(player.hp == 0)
        #expect(!player.isAlive)
    }

    @Test func playerHealing() {
        let player = Player()
        player.takeDamage(3)
        player.heal(2)

        #expect(player.hp == Player.maxHP - 1)
    }

    @Test func playerHealingCapped() {
        let player = Player()
        player.heal(10)  // Already at max

        #expect(player.hp == Player.maxHP)  // Should stay at max
    }

    @Test func playerSpendMana() {
        let player = Player()
        let success = player.spendMana(2)

        #expect(success == true)
        #expect(player.mana == Player.maxMana - 2)
    }

    @Test func playerCannotOverspendMana() {
        let player = Player()
        _ = player.spendMana(3)
        let overSpend = player.spendMana(3)

        #expect(overSpend == false)
        #expect(player.mana == Player.maxMana - 3)
    }
}

// MARK: - Enemy Tests

@MainActor
struct EnemyTests {
    @Test func enemyInitialState() {
        let enemy = Enemy(hp: 3, damage: 1, behavior: .aggressive, position: HexCoord(q: 2, r: 0))

        #expect(enemy.hp == 3)
        #expect(enemy.damage == 1)
        #expect(enemy.isAlive)
    }

    @Test func enemyTakesDamage() {
        let enemy = Enemy(hp: 3, damage: 1, behavior: .aggressive, position: .zero)
        enemy.takeDamage(2)

        #expect(enemy.hp == 1)
        #expect(enemy.isAlive)
    }

    @Test func enemyCanDie() {
        let enemy = Enemy(hp: 2, damage: 1, behavior: .aggressive, position: .zero)
        enemy.takeDamage(3)

        #expect(enemy.hp == 0)
        #expect(!enemy.isAlive)
    }

    @Test func enemyStun() {
        let enemy = Enemy(hp: 3, damage: 1, behavior: .aggressive, position: .zero)
        enemy.stun(turns: 2)

        #expect(enemy.isStunned)

        let action = enemy.takeTurn(playerPosition: HexCoord(q: 1, r: 0), blocked: [])
        if case .stunned = action {
            // Expected
        } else {
            Issue.record("Expected stunned action")
        }
    }
}
