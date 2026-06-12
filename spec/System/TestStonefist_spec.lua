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

	it("GloveBaseTypeTransform: pure-evasion gloves lose base Evasion and gain per-level Evasion from Fists of Stone", function()
		-- Suede Bracers: Evasion=10 (×1.2 quality = 12 from glove). After FoS transform,
		-- armourData.Evasion is zeroed (FoS armour={}) and only the +2-per-level implicit remains.
		-- At level 1 that is 2, so total evasion DECREASES but stays > 0.
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Suede Bracers
			Evasion: 10
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		local baseEvasion = build.calcsTab.mainOutput.Evasion or 0

		-- Apply transform flag
		build.configTab.input.customMods = "\z
		Gloves you equip have their base type transformed to fists of stone while equipped\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		local transformedEvasion = build.calcsTab.mainOutput.Evasion or 0
		-- Glove base evasion is removed; per-level implicit is small at low level → net decrease
		assert.is_true(transformedEvasion < baseEvasion,
			("expected transformed evasion %d < base evasion %d (glove base removed, only per-level implicit remains)"):format(transformedEvasion, baseEvasion))
		assert.is_true(transformedEvasion > 0,
			("expected evasion > 0 after transform, got %d"):format(transformedEvasion))
	end)

	it("GloveBaseTypeTransform: armour-only gloves lose Armour and gain Evasion-per-level from Fists of Stone", function()
		-- Stocky Mitts: Armour only. Fists of Stone has no base Armour (armour={}),
		-- so after transform Armour drops to 0 and Evasion appears via per-level implicit.
		build.itemsTab:CreateDisplayItemFromRaw([[
			New Item
			Stocky Mitts
		]])
		build.itemsTab:AddDisplayItem()
		runCallback("OnFrame")

		local baseArmour = build.calcsTab.mainOutput.Armour or 0
		local baseEvasion = build.calcsTab.mainOutput.Evasion or 0

		build.configTab.input.customMods = "\z
		Gloves you equip have their base type transformed to fists of stone while equipped\n\z
		"
		build.configTab:BuildModList()
		runCallback("OnFrame")

		local transformedArmour = build.calcsTab.mainOutput.Armour or 0
		local transformedEvasion = build.calcsTab.mainOutput.Evasion or 0
		-- Armour goes away (FoS has no base Armour); Evasion appears via +3 per level implicit
		assert.is_true(transformedArmour < baseArmour,
			("expected transformed armour %d < base armour %d"):format(transformedArmour, baseArmour))
		assert.is_true(transformedEvasion > baseEvasion,
			("expected transformed evasion %d > base evasion %d"):format(transformedEvasion, baseEvasion))
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
end)
