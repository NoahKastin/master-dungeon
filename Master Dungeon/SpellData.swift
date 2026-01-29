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
        passSpell,
        Spell(
            id: "stealth", name: "Stealth",
            description: "Radiate a veil of shadows and silence, masking you and allies in adjacent hexes from detection.",
            range: 0, offenseDie: 0, defenseDie: 0, manaCost: -2,
            isQuickCast: true, isPassive: true, noSave: true, isAoE: true,
            hasAdvantage: false, causesParalysis: true, affectsMovement: false,
            affectsObjects: false, producesLight: false, exchangesKnowledge: false
        ),
        Spell(
            id: "entangle", name: "Entangle",
            description: "Cause grasping weeds and vines to ensnare nearby hexes.",
            range: 1, offenseDie: 0, defenseDie: 0, manaCost: 0,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: true,
            hasAdvantage: false, causesParalysis: true, affectsMovement: false,
            affectsObjects: false, producesLight: false, exchangesKnowledge: false
        ),
        Spell(
            id: "shed-light", name: "Shed Light",
            description: "Cause a hex to shed light.",
            range: 1, offenseDie: 0, defenseDie: 0, manaCost: 0,
            isQuickCast: true, isPassive: false, noSave: true, isAoE: true,
            hasAdvantage: false, causesParalysis: false, affectsMovement: false,
            affectsObjects: false, producesLight: true, exchangesKnowledge: false
        ),
        Spell(
            id: "spare-the-dying", name: "Spare the Dying",
            description: "Stabilize a dying ally, keeping it alive so it can be healed.",
            range: 1, offenseDie: 0, defenseDie: 1, manaCost: 0,
            isQuickCast: true, isPassive: false, noSave: true, isAoE: false,
            hasAdvantage: false, causesParalysis: false, affectsMovement: false,
            affectsObjects: false, producesLight: false, exchangesKnowledge: false
        ),
        Spell(
            id: "poison-puff", name: "Poison Puff",
            description: "Puff noxious gas at a hex.",
            range: 1, offenseDie: 4, defenseDie: 0, manaCost: 1,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: false,
            hasAdvantage: false, causesParalysis: false, affectsMovement: false,
            affectsObjects: false, producesLight: false, exchangesKnowledge: false
        ),
        Spell(
            id: "thunderwave", name: "Thunderwave",
            description: "Sweep a wave of thunderous force outwards from yourself, damaging hexes nearby.",
            range: 0, offenseDie: 4, defenseDie: 0, manaCost: 1,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: true,
            hasAdvantage: false, causesParalysis: false, affectsMovement: false,
            affectsObjects: false, producesLight: false, exchangesKnowledge: false
        ),
        Spell(
            id: "cure-wounds", name: "Cure Wounds",
            description: "Touch an ally's wounds, causing them to knit together.",
            range: 1, offenseDie: 0, defenseDie: 2, manaCost: 2,
            isQuickCast: true, isPassive: false, noSave: true, isAoE: false,
            hasAdvantage: false, causesParalysis: false, affectsMovement: false,
            affectsObjects: false, producesLight: false, exchangesKnowledge: false
        ),
        Spell(
            id: "shocking-grasp", name: "Shocking Grasp",
            description: "Electrically shock a hex.",
            range: 1, offenseDie: 3, defenseDie: 0, manaCost: 2,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: false,
            hasAdvantage: false, causesParalysis: true, affectsMovement: false,
            affectsObjects: false, producesLight: false, exchangesKnowledge: false
        ),
        Spell(
            id: "magic-missile", name: "Magic Missile",
            description: "Assail a creature with a glowing dart of magical force.",
            range: 3, offenseDie: 2, defenseDie: 0, manaCost: 3,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: false,
            hasAdvantage: false, causesParalysis: false, affectsMovement: false,
            affectsObjects: false, producesLight: false, exchangesKnowledge: false
        ),
        Spell(
            id: "life-transference", name: "Life Transference",
            description: "Wreath your hand in shadows, making it siphon life force from hexes you strike with it, damaging them and healing you.",
            range: 1, offenseDie: 2, defenseDie: 1, manaCost: 3,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: false,
            hasAdvantage: false, causesParalysis: false, affectsMovement: false,
            affectsObjects: false, producesLight: false, exchangesKnowledge: false
        ),
        Spell(
            id: "brand", name: "Brand",
            description: "Assail a hex with a weapon gleaming with astral radiance, causing the hex to shed light.",
            range: 1, offenseDie: 4, defenseDie: 0, manaCost: 3,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: false,
            hasAdvantage: false, causesParalysis: false, affectsMovement: false,
            affectsObjects: false, producesLight: true, exchangesKnowledge: false
        ),
        Spell(
            id: "burning-hands", name: "Burning Hands",
            description: "Fling a thin sheet of flames, damaging hexes in a cone.",
            range: 1, offenseDie: 4, defenseDie: 0, manaCost: 3,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: true,
            hasAdvantage: false, causesParalysis: false, affectsMovement: false,
            affectsObjects: false, producesLight: false, exchangesKnowledge: false
        ),
        Spell(
            id: "acid-splash", name: "Acid Splash",
            description: "Hurl a bubble of acid at a group of hexes.",
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
            id: "sleet-storm", name: "Sleet Storm",
            description: "Summon a snowstorm, paralyzing and damaging hexes within.",
            range: 2, offenseDie: 1, defenseDie: 0, manaCost: 4,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: true,
            hasAdvantage: false, causesParalysis: true, affectsMovement: false,
            affectsObjects: false, producesLight: false, exchangesKnowledge: false
        ),
        Spell(
            id: "mass-cure", name: "Mass Cure",
            description: "Call out words of restoration, healing allies within range.",
            range: 1, offenseDie: 0, defenseDie: 2, manaCost: 4,
            isQuickCast: true, isPassive: false, noSave: true, isAoE: true,
            hasAdvantage: false, causesParalysis: false, affectsMovement: false,
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
