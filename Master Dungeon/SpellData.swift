//
//  SpellData.swift
//  Master Dungeon
//
//  All spells from the Master Dungeon VG Spells spreadsheet.
//

import Foundation

struct SpellData {
    /// The Pass spell - always available, cannot be deselected
    static let passSpell = Spell(
        id: "pass", name: "Pass",
        description: "Wait, prompting enemies to act.",
        range: 0, offenseDie: 0, defenseDie: 0, manaCost: -4,
        isQuickCast: false, isPassive: false, noSave: false, isAoE: false,
        hasAdvantage: false, causesParalysis: false, affectsMovement: false,
        affectsObjects: false, producesLight: false, exchangesKnowledge: false
    )

    static let allSpells: [Spell] = [
        // Mana -4
        passSpell,
        // Mana 0
        Spell(
            id: "spare-the-dying", name: "Spare the Dying",
            description: "Keep a dying ally from death's door.",
            range: 1, offenseDie: 0, defenseDie: 1, manaCost: 0,
            isQuickCast: true, isPassive: false, noSave: true, isAoE: false,
            hasAdvantage: false, causesParalysis: false, affectsMovement: false,
            affectsObjects: false, producesLight: false, exchangesKnowledge: false
        ),
        Spell(
            id: "stealth", name: "Stealth",
            description: "Disappear from nearby foes' view.",
            range: 0, offenseDie: 0, defenseDie: 0, manaCost: 0,
            isQuickCast: true, isPassive: true, noSave: true, isAoE: true,
            hasAdvantage: false, causesParalysis: true, affectsMovement: false,
            affectsObjects: false, producesLight: false, exchangesKnowledge: false
        ),
        // Mana 1
        Spell(
            id: "brand", name: "Brand",
            description: "Light up a hex with a gleaming strike.",
            range: 1, offenseDie: 2, defenseDie: 0, manaCost: 1,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: false,
            hasAdvantage: false, causesParalysis: false, affectsMovement: false,
            affectsObjects: false, producesLight: true, exchangesKnowledge: false
        ),
        Spell(
            id: "shocking-grasp", name: "Shocking Grasp",
            description: "Electrically shock a hex.",
            range: 1, offenseDie: 2, defenseDie: 0, manaCost: 1,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: false,
            hasAdvantage: false, causesParalysis: true, affectsMovement: false,
            affectsObjects: false, producesLight: false, exchangesKnowledge: false
        ),
        // Mana 2
        Spell(
            id: "burning-hands", name: "Burning Hands",
            description: "Conflagrate nearby hexes.",
            range: 1, offenseDie: 3, defenseDie: 0, manaCost: 2,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: true,
            hasAdvantage: false, causesParalysis: false, affectsMovement: false,
            affectsObjects: false, producesLight: false, exchangesKnowledge: false
        ),
        Spell(
            id: "cure-wounds", name: "Cure Wounds",
            description: "Knit an ally's wounds together.",
            range: 1, offenseDie: 0, defenseDie: 2, manaCost: 2,
            isQuickCast: true, isPassive: false, noSave: true, isAoE: false,
            hasAdvantage: false, causesParalysis: false, affectsMovement: false,
            affectsObjects: false, producesLight: false, exchangesKnowledge: false
        ),
        Spell(
            id: "life-transference", name: "Life Transference",
            description: "Take the life force of an enemy.",
            range: 1, offenseDie: 1, defenseDie: 1, manaCost: 2,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: false,
            hasAdvantage: false, causesParalysis: false, affectsMovement: false,
            affectsObjects: false, producesLight: false, exchangesKnowledge: false
        ),
        Spell(
            id: "magic-missile", name: "Magic Missile",
            description: "Fling a dart of magical force.",
            range: 3, offenseDie: 1, defenseDie: 0, manaCost: 2,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: false,
            hasAdvantage: false, causesParalysis: false, affectsMovement: false,
            affectsObjects: false, producesLight: false, exchangesKnowledge: false
        ),
        Spell(
            id: "thunderwave", name: "Thunderwave",
            description: "Harm nearby foes with thunder.",
            range: 0, offenseDie: 3, defenseDie: 0, manaCost: 2,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: true,
            hasAdvantage: false, causesParalysis: false, affectsMovement: false,
            affectsObjects: false, producesLight: false, exchangesKnowledge: false
        ),
        // Mana 4
        Spell(
            id: "acid-splash", name: "Acid Splash",
            description: "Hurl a volatile bubble of acid.",
            range: 2, offenseDie: 3, defenseDie: 0, manaCost: 4,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: true,
            hasAdvantage: false, causesParalysis: false, affectsMovement: false,
            affectsObjects: false, producesLight: false, exchangesKnowledge: false
        ),
        Spell(
            id: "chill-touch", name: "Chill Touch",
            description: "Grip a hex with a ghostly, skeletal hand.",
            range: 3, offenseDie: 1, defenseDie: 0, manaCost: 4,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: false,
            hasAdvantage: false, causesParalysis: true, affectsMovement: false,
            affectsObjects: false, producesLight: false, exchangesKnowledge: false
        ),
        Spell(
            id: "mass-cure", name: "Mass Cure",
            description: "Pray that nearby allies be healed.",
            range: 1, offenseDie: 0, defenseDie: 2, manaCost: 4,
            isQuickCast: true, isPassive: false, noSave: true, isAoE: true,
            hasAdvantage: false, causesParalysis: false, affectsMovement: false,
            affectsObjects: false, producesLight: false, exchangesKnowledge: false
        ),
        Spell(
            id: "sleet-storm", name: "Sleet Storm",
            description: "Summon a chilling, blinding storm.",
            range: 2, offenseDie: 1, defenseDie: 0, manaCost: 4,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: true,
            hasAdvantage: false, causesParalysis: true, affectsMovement: false,
            affectsObjects: false, producesLight: false, exchangesKnowledge: false
        ),
    ]

    /// Get spell by ID
    static func spell(byId id: String) -> Spell? {
        allSpells.first { $0.id == id }
    }

    /// Get spells filtered by capability
    static func spells(with capability: SpellCapability) -> [Spell] {
        allSpells.filter { $0.capabilityTags.contains(capability) }
    }

    /// Get spells affordable within a mana budget
    static func affordableSpells(budget: Int) -> [Spell] {
        allSpells.filter { $0.manaCost <= budget }
    }

    /// Get spells sorted by mana cost
    static var spellsByManaCost: [Spell] {
        allSpells.sorted { $0.manaCost < $1.manaCost }
    }
}
