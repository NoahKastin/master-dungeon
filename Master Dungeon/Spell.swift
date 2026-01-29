//
//  Spell.swift
//  Master Dungeon
//
//  Spell data model matching the Excel spreadsheet structure.
//

import Foundation

struct Spell: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let range: Int              // Range in hexes
    let offenseDie: Int         // Damage die (d4=4, d6=6, etc.), 0 if none
    let defenseDie: Int         // Defense/healing die, 0 if none
    let manaCost: Int           // 0-20 range

    // Boolean properties for challenge generation
    let isQuickCast: Bool       // Short Casting Time (<=1 Action)
    let isPassive: Bool         // Not Instantaneous
    let noSave: Bool            // No Save required
    let isAoE: Bool             // Area of Effect
    let hasAdvantage: Bool      // Grants Advantage
    let causesParalysis: Bool   // Paralysis (No Harm to You)
    let affectsMovement: Bool   // Creature Movement
    let affectsObjects: Bool    // Object Changes
    let producesLight: Bool     // Lights
    let exchangesKnowledge: Bool // Exchange of Knowledge

    // Computed properties
    var averageOffense: Double { offenseDie > 0 ? Double(offenseDie + 1) / 2.0 : 0.0 }
    var averageDefense: Double { defenseDie > 0 ? Double(defenseDie + 1) / 2.0 : 0.0 }

    var isOffensive: Bool { offenseDie > 0 }
    var isDefensive: Bool { defenseDie > 0 }
    var isUtility: Bool { !isOffensive && !isDefensive }

    /// Roll the offense die
    func rollOffense() -> Int {
        guard offenseDie > 0 else { return 0 }
        return Int.random(in: 1...offenseDie)
    }

    /// Roll the defense die
    func rollDefense() -> Int {
        guard defenseDie > 0 else { return 0 }
        return Int.random(in: 1...defenseDie)
    }

    /// Tags describing this spell's capabilities (used for challenge matching)
    var capabilityTags: Set<SpellCapability> {
        var tags: Set<SpellCapability> = []

        if isOffensive { tags.insert(.damage) }
        // Only pure healing spells (defensive but NOT offensive) can heal allies
        // Life-steal spells (both offensive and defensive) only heal the caster
        if isDefensive && !isOffensive { tags.insert(.healing) }
        if isAoE { tags.insert(.areaEffect) }
        if causesParalysis { tags.insert(.crowdControl) }
        if affectsMovement { tags.insert(.mobility) }
        if affectsObjects { tags.insert(.objectManipulation) }
        if producesLight { tags.insert(.illumination) }
        if exchangesKnowledge { tags.insert(.information) }
        if hasAdvantage { tags.insert(.buffing) }
        if range >= 4 { tags.insert(.ranged) }
        if range <= 1 { tags.insert(.melee) }
        if isPassive { tags.insert(.sustained) }
        if noSave { tags.insert(.guaranteed) }
        if isQuickCast { tags.insert(.quickCast) }

        return tags
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Spell, rhs: Spell) -> Bool {
        lhs.id == rhs.id
    }
}

/// Capabilities that spells can have, used for challenge generation
enum SpellCapability: String, CaseIterable {
    case damage           // Can deal damage
    case healing          // Can heal
    case areaEffect       // Affects multiple hexes
    case crowdControl     // Can paralyze/stop enemies
    case mobility         // Affects movement
    case objectManipulation // Can affect objects
    case illumination     // Produces light
    case information      // Gathers information
    case buffing          // Provides advantages
    case ranged           // Long range (4+ hexes)
    case melee            // Close range (1 hex)
    case sustained        // Lasts over time
    case guaranteed       // No save, always works
    case quickCast        // Fast to cast
}

/// A loadout of spells that a player has selected (max 3 spells plus Pass)
struct SpellLoadout {
    static let maxSpells = 3  // Maximum selectable spells (not counting Pass)

    private(set) var spells: [Spell] = []

    /// Count of selectable spells (excludes Pass)
    var selectableSpellCount: Int {
        spells.filter { $0.id != "pass" }.count
    }

    var totalManaCost: Int {
        spells.reduce(0) { $0 + $1.manaCost }
    }

    var allCapabilities: Set<SpellCapability> {
        spells.reduce(into: Set<SpellCapability>()) { result, spell in
            result.formUnion(spell.capabilityTags)
        }
    }

    mutating func addSpell(_ spell: Spell) -> Bool {
        // Pass spell is always allowed
        if spell.id == "pass" {
            if !spells.contains(spell) {
                spells.insert(spell, at: 0)
            }
            return true
        }
        // Other spells limited to maxSpells count
        guard selectableSpellCount < SpellLoadout.maxSpells else {
            return false
        }
        guard !spells.contains(spell) else {
            return false
        }
        spells.append(spell)
        return true
    }

    mutating func removeSpell(_ spell: Spell) {
        // Pass cannot be removed
        guard spell.id != "pass" else { return }
        spells.removeAll { $0 == spell }
    }

    func canAfford(_ spell: Spell) -> Bool {
        selectableSpellCount < SpellLoadout.maxSpells && !spells.contains(spell)
    }

    /// Check if loadout has capability to handle a specific challenge requirement
    func hasCapability(_ capability: SpellCapability) -> Bool {
        allCapabilities.contains(capability)
    }

    /// Get spells that have a specific capability
    func spells(with capability: SpellCapability) -> [Spell] {
        spells.filter { $0.capabilityTags.contains(capability) }
    }
}
