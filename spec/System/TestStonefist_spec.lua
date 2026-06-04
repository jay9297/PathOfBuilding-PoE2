describe("TestStonefist", function()
	before_each(function()
		newBuild()
	end)

	-- ModParser: flag parsing

	it("GloveBaseTypeTransform flag is set from ascendancy mod string", function()
		build.configTab.input.customMods = "\z
		Gloves you equip have their base type transformed to fists of stone while equipped\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		assert.is_true(build.calcsTab.mainEnv.modDB:Flag(nil, "GloveBaseTypeTransform"))
	end)

	it("IgnoreAttributeRequirementsForGloves flag is set from ascendancy mod string", function()
		build.configTab.input.customMods = "\z
		Ignore attribute requirements to equip gloves\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		assert.is_true(build.calcsTab.mainEnv.modDB:Flag(nil, "IgnoreAttributeRequirementsForGloves"))
	end)

	it("GloveExplicitModTransform flag is set from ascendancy mod string", function()
		build.configTab.input.customMods = "\z
		their explicit modifiers are transformed into more powerful related modifiers\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		assert.is_true(build.calcsTab.mainEnv.modDB:Flag(nil, "GloveExplicitModTransform"))
	end)

	-- CalcPerform: base type transform overwrites glove armour values

	it("GloveBaseTypeTransform: equipping pure-evasion gloves gains Armour from Fists of Stone base", function()
		-- Suede Bracers: Evasion only, no Armour stat
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Suede Bracers
			Evasion: 10
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		local baseArmour = build.calcsTab.mainOutput.Armour or 0

		-- Apply transform flag
		build.configTab.input.customMods = "\z
		Gloves you equip have their base type transformed to fists of stone while equipped\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		local transformedArmour = build.calcsTab.mainOutput.Armour or 0
		-- Fists of Stone base armour is 44; should exceed the evasion-only baseline
		assert.is_true(transformedArmour > baseArmour,
			("expected transformed armour %d > base armour %d"):format(transformedArmour, baseArmour))
		assert.is_near(44, transformedArmour, 10)
	end)

	it("GloveBaseTypeTransform: armour-only gloves take on Fists of Stone armour value (~44)", function()
		-- Stocky Mitts base armour = 15; Fists of Stone base armour = 44
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Stocky Mitts
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		local baseArmour = build.calcsTab.mainOutput.Armour or 0

		build.configTab.input.customMods = "\z
		Gloves you equip have their base type transformed to fists of stone while equipped\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		local transformedArmour = build.calcsTab.mainOutput.Armour or 0
		-- Armour should change from Stocky Mitts base (~15) to Fists of Stone base (~44)
		assert.are_not.equals(baseArmour, transformedArmour)
		assert.is_near(44, transformedArmour, 10)
	end)

	it("GloveBaseTypeTransform: Fists of Stone implicit injects Evasion per level into modDB", function()
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Stocky Mitts
			Armour: 10
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		local baseEvasion = build.calcsTab.mainOutput.Evasion or 0

		build.configTab.input.customMods = "\z
		Gloves you equip have their base type transformed to fists of stone while equipped\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		-- Implicit: +2 Evasion per level; at level 1 that is +2, plus Fists of Stone base evasion (40)
		local transformedEvasion = build.calcsTab.mainOutput.Evasion or 0
		assert.is_true(transformedEvasion > baseEvasion,
			("expected evasion %d > base evasion %d after Fists of Stone transform"):format(transformedEvasion, baseEvasion))
	end)

	it("GloveBaseTypeTransform: Ward implicit is injected (Ward > 0 after transform)", function()
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Stocky Mitts
			Armour: 10
		]])
		build.itemsTab:AddDisplayItem()
		build.configTab.input.customMods = "\z
		Gloves you equip have their base type transformed to fists of stone while equipped\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		-- Implicit: +1 Ward per level; should be > 0 at any character level
		local ward = build.calcsTab.calcsOutput.Ward or 0
		assert.is_true(ward > 0,
			("expected Ward > 0 from Fists of Stone implicit, got %d"):format(ward))
	end)

	it("GloveBaseTypeTransform: actual Fists of Stone base still receives per-level Evasion implicit", function()
		-- Equip an actual Fists of Stone item (not a transformed base).
		-- The guard must not skip implicit injection when baseName is already "Fists of Stone".
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Fists of Stone
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		local baseEvasion = build.calcsTab.mainOutput.Evasion or 0

		build.configTab.input.customMods = "\z
		Gloves you equip have their base type transformed to fists of stone while equipped\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		-- +2 Evasion per level implicit must fire; Evasion should increase above the bare base
		local transformedEvasion = build.calcsTab.mainOutput.Evasion or 0
		assert.is_true(transformedEvasion > baseEvasion,
			("expected FoS implicit to increase Evasion from %d to >%d"):format(baseEvasion, baseEvasion))
	end)

	-- CalcPerform: scoped attribute requirement ignore

	it("IgnoreAttributeRequirementsForGloves does not zero global attribute requirements", function()
		-- The scoped flag should NOT zero requirements from non-glove sources
		build.configTab.input.customMods = "\z
		Ignore attribute requirements to equip gloves\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		-- Global flag should be nil; only the scoped flag should be set
		local globalFlag = build.calcsTab.mainEnv.modDB:Flag(nil, "IgnoreAttributeRequirements")
		assert.is_falsy(globalFlag)
		assert.is_true(build.calcsTab.mainEnv.modDB:Flag(nil, "IgnoreAttributeRequirementsForGloves"))
	end)

	-- CalcPerform: explicit mod transformation

	it("GloveExplicitModTransform: empty equivalencies table is a no-op", function()
		local origEquiv = data.modEquivalencies
		data.modEquivalencies = {}

		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Titan Mitts
			150% increased Armour
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")
		local baseArmour = build.calcsTab.mainOutput.Armour or 0

		build.configTab.input.customMods = "\z
		their explicit modifiers are transformed into more powerful related modifiers\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		-- Armour should be unchanged because no equivalency is defined
		local transformedArmour = build.calcsTab.mainOutput.Armour or 0
		assert.are.equal(baseArmour, transformedArmour)

		data.modEquivalencies = origEquiv
	end)

	it("GloveExplicitModTransform: INC mod is upgraded when a matching equivalency exists", function()
		local origEquiv = data.modEquivalencies
		-- Map the specific mod text used in the raw item below to a stronger version
		data.modEquivalencies = {
			["150% increased Armour"] = "300% increased Armour",
		}

		-- Titan Mitts: base Armour = 100 (no quality on a New Item)
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Titan Mitts
			150% increased Armour
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")
		-- Baseline: 100 * (1 + 150/100) = 250 (LOCAL INC baked into armourData)
		local baseArmour = build.calcsTab.mainOutput.Armour or 0

		build.configTab.input.customMods = "\z
		their explicit modifiers are transformed into more powerful related modifiers\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")
		-- After transform: armourData adjusted to 300% INC → 100 * (1+3) = 400
		local transformedArmour = build.calcsTab.mainOutput.Armour or 0
		assert.is_near(400, transformedArmour, 2)

		data.modEquivalencies = origEquiv
	end)

	it("GloveExplicitModTransform: range-format mod text is matched and upgraded", function()
		local origEquiv = data.modEquivalencies
		-- Unique item data files use range text like "(150-200)% increased Armour".
		-- Verify that the raw modLine.line (which retains the range text) is used as the key.
		-- The VALUE must be a resolved numeric literal (parseMod cannot handle range notation).
		data.modEquivalencies = {
			["(150-200)% increased Armour"] = "300% increased Armour",
		}

		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Titan Mitts
			(150-200)% increased Armour
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")
		local baseArmour = build.calcsTab.mainOutput.Armour or 0

		build.configTab.input.customMods = "\z
		their explicit modifiers are transformed into more powerful related modifiers\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")
		-- After transform: armourData adjusted to 300% INC → 100 * (1+3) = 400
		local transformedArmour = build.calcsTab.mainOutput.Armour or 0
		assert.is_near(400, transformedArmour, 2)

		data.modEquivalencies = origEquiv
	end)

	it("GloveExplicitModTransform: mapped mod transforms when item also has unmapped mods", function()
		local origEquiv = data.modEquivalencies
		-- Only the Armour INC mod is mapped; the Strength BASE mod has no equivalency
		data.modEquivalencies = {
			["150% increased Armour"] = "300% increased Armour",
		}

		-- Item has both a mapped mod and an unmapped mod
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Titan Mitts
			150% increased Armour
			+25 to Strength
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")
		local baseArmour = build.calcsTab.mainOutput.Armour or 0

		build.configTab.input.customMods = "\z
		their explicit modifiers are transformed into more powerful related modifiers\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")
		-- Mapped Armour mod upgrades: armourData adjusted to 300% INC → 100 * (1+3) = 400
		local transformedArmour = build.calcsTab.mainOutput.Armour or 0
		assert.is_near(400, transformedArmour, 2)

		data.modEquivalencies = origEquiv
	end)

	it("GloveExplicitModTransform: multiple local INC mods on same stat use full INC sum for ratio", function()
		local origEquiv = data.modEquivalencies
		-- Only the 150% mod is in the equivalency table; the 50% mod is NOT mapped.
		-- armourData bakes in both: 100 * (1+(150+50)/100) = 300.
		-- After transform: only the 150% mod changes to 300%, so total INC becomes 350%.
		-- Correct result: floor(300 * (1+3.5) / (1+2)) = floor(300*4.5/3) = 450.
		-- Buggy single-mod ratio would give: floor(300 / 2.5 * 4) = 480 (wrong).
		data.modEquivalencies = {
			["150% increased Armour"] = "300% increased Armour",
		}

		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Titan Mitts
			150% increased Armour
			50% increased Armour
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		build.configTab.input.customMods = "\z
		their explicit modifiers are transformed into more powerful related modifiers\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")
		local transformedArmour = build.calcsTab.mainOutput.Armour or 0
		-- round(100*(1+(300+50)/100)) = 450
		assert.is_near(450, transformedArmour, 2)

		data.modEquivalencies = origEquiv
	end)

	it("GloveBaseTypeTransform and GloveExplicitModTransform work independently together", function()
		local origEquiv = data.modEquivalencies
		data.modEquivalencies = {
			["150% increased Armour"] = "300% increased Armour",
		}

		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Titan Mitts
			150% increased Armour
		]])
		build.itemsTab:AddDisplayItem()

		-- Baseline: only base type transform active (no explicit mod upgrade)
		-- LOCAL INC was consumed by calcLocal so modDB has none; armourData = FoS base = 44
		build.configTab.input.customMods = "\z
		Gloves you equip have their base type transformed to fists of stone while equipped\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")
		local baseTypeOnlyArmour = build.calcsTab.mainOutput.Armour or 0

		-- Enable both transforms together (as Way of the Stonefist does in game)
		build.configTab.input.customMods = "\z
		Gloves you equip have their base type transformed to fists of stone while equipped\n\z
		their explicit modifiers are transformed into more powerful related modifiers\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")
		local fullyTransformedArmour = build.calcsTab.mainOutput.Armour or 0
		-- Explicit upgrade: armourData (raw FoS base 44) × (1+3) = 176
		assert.is_near(176, fullyTransformedArmour, 10)
		assert.is_true(fullyTransformedArmour > baseTypeOnlyArmour,
			("expected fully-transformed armour %d > base-type-only armour %d"):format(fullyTransformedArmour, baseTypeOnlyArmour))

		data.modEquivalencies = origEquiv
	end)

	it("GloveExplicitModTransform: global (non-defence) mod is cancelled and upgraded in modDB", function()
		local origEquiv = data.modEquivalencies
		-- Map a global Life mod; Life is not in armStatMap so it follows the cancel+inject path.
		data.modEquivalencies = {
			["+25 to maximum Life"] = "+50 to maximum Life",
		}

		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Titan Mitts
			+25 to maximum Life
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")
		local baseLife = build.calcsTab.mainOutput.Life or 0

		build.configTab.input.customMods = "\z
		their explicit modifiers are transformed into more powerful related modifiers\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")
		local transformedLife = build.calcsTab.mainOutput.Life or 0
		-- Old +25 is cancelled; new +50 is injected.  Net: exactly +25 more Life.
		assert.is_near(baseLife + 25, transformedLife, 2)

		data.modEquivalencies = origEquiv
	end)

	it("GloveExplicitModTransform: flat BASE defence mod is upgraded via baseDelta path", function()
		local origEquiv = data.modEquivalencies
		-- +25 to Armour is a local BASE defence mod (consumed by calcLocal into armourData).
		-- baseDelta = 25; with no INC, armourData goes from 125 to 150.
		data.modEquivalencies = {
			["+25 to Armour"] = "+50 to Armour",
		}

		-- Titan Mitts base Armour = 100 (New Item quality = 0); +25 flat → armourData = 125
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Titan Mitts
			+25 to Armour
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		build.configTab.input.customMods = "\z
		their explicit modifiers are transformed into more powerful related modifiers\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")
		-- baseDelta = +25, no INC change: floor(125 + 25 * 1 * 1) = 150
		local transformedArmour = build.calcsTab.mainOutput.Armour or 0
		assert.is_near(150, transformedArmour, 2)

		data.modEquivalencies = origEquiv
	end)
end)
