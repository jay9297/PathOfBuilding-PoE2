-- Maps raw glove explicit mod text to upgraded equivalent mod text.
-- Used by Way of the Stonefist (CalcPerform.lua) to transform glove explicit modifiers
-- when the GloveExplicitModTransform flag is active.
--
-- Keys: the exact text of an explicit mod line as it appears in src/Data/Uniques/gloves.lua
--   (i.e. the range-format text such as "(80-100)% increased Armour").
-- Values: the upgraded equivalent mod text (resolved numeric, no range notation).
--
-- Only BASE and INC mod types are remapped; FLAG-type mods (e.g. "Culling Strike") are left
-- active unchanged because they cannot be meaningfully negated.
--
-- cspell:ignore modequivalencies
-- Populate this table with entries from game data as unique glove mods become known.
return {
}
