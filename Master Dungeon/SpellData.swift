//
//  SpellData.swift
//  Master Dungeon
//
//  All spells from the Master Dungeon VG Spells spreadsheet.
//

import Foundation

struct SpellData {
    /// The Pass spell - always available in normal/hardcore, cannot be deselected
    static let passSpell = Spell(
        id: "pass", name: "Pass",
        description: "Wait, prompting enemies to act.",
        range: 0, offenseDie: 0, defenseDie: 0, manaCost: -2,
        isQuickCast: false, isPassive: false, noSave: false, isAoE: false,
        causesParalysis: false,
        producesLight: false
    )

    /// The Potion spell - always available in medium, cannot be deselected
    static let potionSpell = Spell(
        id: "potion", name: "Potion",
        description: "Drink a potion, gaining health & mana.",
        range: 0, offenseDie: 0, defenseDie: 1, manaCost: -1,
        isQuickCast: false, isPassive: false, noSave: false, isAoE: false,
        causesParalysis: false,
        producesLight: false
    )

    static let allSpells: [Spell] = [
        // Mana -2
        passSpell,
        // Mana 0
        Spell(
            id: "stealth", name: "Blur",
            description: "Become hazy, confusing nearby foes.",
            range: 0, offenseDie: 0, defenseDie: 0, manaCost: 0,
            isQuickCast: true, isPassive: true, noSave: true, isAoE: true,
            causesParalysis: true,
            producesLight: false
        ),
        Spell(
            id: "brand", name: "Brand",
            description: "Light up a hex with a gleaming strike.",
            range: 1, offenseDie: 1, defenseDie: 0, manaCost: 0,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: false,
            causesParalysis: false,
            producesLight: true
        ),
        Spell(
            id: "spare-the-dying", name: "Spare the Dying",
            description: "Keep a dying ally from death's door.",
            range: 1, offenseDie: 0, defenseDie: 1, manaCost: 0,
            isQuickCast: true, isPassive: false, noSave: true, isAoE: false,
            causesParalysis: false,
            producesLight: false
        ),
        // Mana 1
        Spell(
            id: "burning-hands", name: "Burning Hands",
            description: "Conflagrate nearby hexes.",
            range: 1, offenseDie: 3, defenseDie: 0, manaCost: 1,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: true,
            causesParalysis: false,
            producesLight: false
        ),
        Spell(
            id: "cure-wounds", name: "Cure Wounds",
            description: "Knit an ally's wounds together.",
            range: 1, offenseDie: 0, defenseDie: 2, manaCost: 1,
            isQuickCast: true, isPassive: false, noSave: true, isAoE: false,
            causesParalysis: false,
            producesLight: false
        ),
        Spell(
            id: "life-transference", name: "Life Transference",
            description: "Take the life force of an enemy.",
            range: 1, offenseDie: 1, defenseDie: 1, manaCost: 1,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: false,
            causesParalysis: false,
            producesLight: false
        ),
        Spell(
            id: "magic-missile", name: "Magic Missile",
            description: "Fling a dart of magical force.",
            range: 3, offenseDie: 1, defenseDie: 0, manaCost: 1,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: false,
            causesParalysis: false,
            producesLight: false
        ),
        Spell(
            id: "shocking-grasp", name: "Shocking Grasp",
            description: "Electrically shock a hex.",
            range: 1, offenseDie: 3, defenseDie: 0, manaCost: 1,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: false,
            causesParalysis: true,
            producesLight: false
        ),
        Spell(
            id: "thunderwave", name: "Thunderwave",
            description: "Harm nearby foes with thunder.",
            range: 0, offenseDie: 3, defenseDie: 0, manaCost: 1,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: true,
            causesParalysis: false,
            producesLight: false
        ),
        // Mana 2
        Spell(
            id: "acid-splash", name: "Acid Splash",
            description: "Hurl a brittle vial of explosive acid.",
            range: 2, offenseDie: 3, defenseDie: 0, manaCost: 2,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: true,
            causesParalysis: false,
            producesLight: false
        ),
        Spell(
            id: "black-tentacles", name: "Black Tentacles",
            description: "Spawn crushing tendrils nearby.",
            range: 0, offenseDie: 3, defenseDie: 0, manaCost: 2,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: true,
            causesParalysis: true,
            producesLight: false
        ),
        Spell(
            id: "blight", name: "Blight",
            description: "Drain a hex, crumbling it.",
            range: 2, offenseDie: 5, defenseDie: 0, manaCost: 2,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: false,
            causesParalysis: false,
            producesLight: false
        ),
        Spell(
            id: "chill-touch", name: "Chill Touch",
            description: "Grip a hex with a ghostly, skeletal hand.",
            range: 3, offenseDie: 1, defenseDie: 0, manaCost: 2,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: false,
            causesParalysis: true,
            producesLight: false
        ),
        Spell(
            id: "calm-emotions", name: "Calm Emotions",
            description: "Calm hexes, healing or paralyzing.",
            range: 1, offenseDie: 0, defenseDie: 1, manaCost: 2,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: true,
            causesParalysis: true,
            producesLight: false
        ),
        Spell(
            id: "private-sanctum", name: "Private Sanctum",
            description: "Protect from damage and darkness.",
            range: 1, offenseDie: 0, defenseDie: 1, manaCost: 2,
            isQuickCast: true, isPassive: false, noSave: true, isAoE: true,
            causesParalysis: false,
            producesLight: true
        ),
        Spell(
            id: "sleet-storm", name: "Sleet Storm",
            description: "Summon a chilling, blinding storm.",
            range: 1, offenseDie: 3, defenseDie: 0, manaCost: 2,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: true,
            causesParalysis: true,
            producesLight: false
        ),
    ]

    /// Blitz mode spells — no mana, upgraded offense dice, combat-only
    static let blitzSpells: [Spell] = [
        Spell(
            id: "acid-splash", name: "Acid Splash",
            description: "Hurl a brittle vial of explosive acid.",
            range: 2, offenseDie: 6, defenseDie: 0, manaCost: 0,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: true,
            causesParalysis: false,
            producesLight: false
        ),
        Spell(
            id: "black-tentacles", name: "Black Tentacles",
            description: "Spawn crushing tendrils nearby.",
            range: 0, offenseDie: 6, defenseDie: 0, manaCost: 0,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: true,
            causesParalysis: true,
            producesLight: false
        ),
        Spell(
            id: "blight", name: "Blight",
            description: "Drain a hex, crumbling it.",
            range: 1, offenseDie: 10, defenseDie: 0, manaCost: 0,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: false,
            causesParalysis: false,
            producesLight: false
        ),
        Spell(
            id: "burning-hands", name: "Burning Hands",
            description: "Conflagrate nearby hexes.",
            range: 1, offenseDie: 8, defenseDie: 0, manaCost: 0,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: true,
            causesParalysis: false,
            producesLight: false
        ),
        Spell(
            id: "chill-touch", name: "Chill Touch",
            description: "Grip a hex with a ghostly, skeletal hand.",
            range: 3, offenseDie: 4, defenseDie: 0, manaCost: 0,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: false,
            causesParalysis: true,
            producesLight: false
        ),
        Spell(
            id: "magic-missile", name: "Magic Missile",
            description: "Fling a dart of magical force.",
            range: 3, offenseDie: 6, defenseDie: 0, manaCost: 0,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: false,
            causesParalysis: false,
            producesLight: false
        ),
        Spell(
            id: "shocking-grasp", name: "Shocking Grasp",
            description: "Electrically shock a hex.",
            range: 1, offenseDie: 8, defenseDie: 0, manaCost: 0,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: false,
            causesParalysis: true,
            producesLight: false
        ),
        Spell(
            id: "sleet-storm", name: "Sleet Storm",
            description: "Summon a chilling, blinding storm.",
            range: 1, offenseDie: 6, defenseDie: 0, manaCost: 0,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: true,
            causesParalysis: true,
            producesLight: false
        ),
        Spell(
            id: "thunderwave", name: "Thunderwave",
            description: "Harm nearby foes with thunder.",
            range: 0, offenseDie: 8, defenseDie: 0, manaCost: 0,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: true,
            causesParalysis: false,
            producesLight: false
        ),
    ]

    /// Medium mode spells — 1 mana, weaker dice, 2-hex max range
    static let mediumSpells: [Spell] = [
        // Mana -1
        potionSpell,
        // Mana 0
        Spell(
            id: "stealth", name: "Blur",
            description: "Become hazy, confusing nearby foes.",
            range: 0, offenseDie: 0, defenseDie: 0, manaCost: 0,
            isQuickCast: true, isPassive: true, noSave: true, isAoE: true,
            causesParalysis: true,
            producesLight: false
        ),
        Spell(
            id: "brand", name: "Brand",
            description: "Light up a hex with a gleaming strike.",
            range: 1, offenseDie: 1, defenseDie: 0, manaCost: 0,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: false,
            causesParalysis: false,
            producesLight: true
        ),
        Spell(
            id: "life-transference", name: "Life Transference",
            description: "Take the life force of an enemy.",
            range: 1, offenseDie: 1, defenseDie: 1, manaCost: 0,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: false,
            causesParalysis: false,
            producesLight: false
        ),
        Spell(
            id: "magic-missile", name: "Magic Missile",
            description: "Fling a dart of magical force.",
            range: 2, offenseDie: 1, defenseDie: 0, manaCost: 0,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: false,
            causesParalysis: false,
            producesLight: false
        ),
        Spell(
            id: "thunderwave", name: "Thunderwave",
            description: "Harm nearby foes with thunder.",
            range: 0, offenseDie: 1, defenseDie: 0, manaCost: 0,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: true,
            causesParalysis: false,
            producesLight: false
        ),
        // Mana 1
        Spell(
            id: "acid-splash", name: "Acid Splash",
            description: "Hurl a brittle vial of explosive acid.",
            range: 2, offenseDie: 1, defenseDie: 0, manaCost: 1,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: true,
            causesParalysis: false,
            producesLight: false
        ),
        Spell(
            id: "black-tentacles", name: "Black Tentacles",
            description: "Spawn crushing tendrils nearby.",
            range: 0, offenseDie: 1, defenseDie: 0, manaCost: 1,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: true,
            causesParalysis: true,
            producesLight: false
        ),
        Spell(
            id: "blight", name: "Blight",
            description: "Drain a hex, crumbling it.",
            range: 2, offenseDie: 3, defenseDie: 0, manaCost: 1,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: false,
            causesParalysis: false,
            producesLight: false
        ),
        Spell(
            id: "burning-hands", name: "Burning Hands",
            description: "Conflagrate nearby hexes.",
            range: 1, offenseDie: 3, defenseDie: 0, manaCost: 1,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: true,
            causesParalysis: false,
            producesLight: false
        ),
        Spell(
            id: "calm-emotions", name: "Calm Emotions",
            description: "Calm hexes, healing or paralyzing.",
            range: 1, offenseDie: 0, defenseDie: 1, manaCost: 1,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: true,
            causesParalysis: true,
            producesLight: false
        ),
        Spell(
            id: "chill-touch", name: "Chill Touch",
            description: "Grip a hex with a ghostly, skeletal hand.",
            range: 2, offenseDie: 1, defenseDie: 0, manaCost: 1,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: false,
            causesParalysis: true,
            producesLight: false
        ),
        Spell(
            id: "cure-wounds", name: "Cure Wounds",
            description: "Knit an ally's wounds together.",
            range: 1, offenseDie: 0, defenseDie: 5, manaCost: 1,
            isQuickCast: true, isPassive: false, noSave: true, isAoE: false,
            causesParalysis: false,
            producesLight: false
        ),
        Spell(
            id: "private-sanctum", name: "Private Sanctum",
            description: "Protect from damage and darkness.",
            range: 1, offenseDie: 0, defenseDie: 1, manaCost: 1,
            isQuickCast: true, isPassive: false, noSave: true, isAoE: true,
            causesParalysis: false,
            producesLight: true
        ),
        Spell(
            id: "shocking-grasp", name: "Shocking Grasp",
            description: "Electrically shock a hex.",
            range: 1, offenseDie: 3, defenseDie: 0, manaCost: 1,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: false,
            causesParalysis: true,
            producesLight: false
        ),
        Spell(
            id: "sleet-storm", name: "Sleet Storm",
            description: "Summon a chilling, blinding storm.",
            range: 1, offenseDie: 1, defenseDie: 0, manaCost: 1,
            isQuickCast: true, isPassive: false, noSave: false, isAoE: true,
            causesParalysis: true,
            producesLight: false
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
