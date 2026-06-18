describe("Advisor", function()
	local Advisor

	before_each(function()
		newBuild()
		Advisor = require("Modules/Advisor")
	end)

	-- A defensively "healthy" build: capped resists, ample EHP, recovery, and a mitigation
	-- layer, so no check fires unless a test overrides the relevant stats.
	local function healthyOutput(overrides)
		local out = {
			FireResist = 75, FireResistOverCap = 0,
			ColdResist = 75, ColdResistOverCap = 0,
			LightningResist = 75, LightningResistOverCap = 0,
			ChaosResist = 0, ChaosResistOverCap = 0,
			Life = 4000, EnergyShield = 0, TotalEHP = 40000,
			LifeRegenRecovery = 200, EnergyShieldRegenRecovery = 0,
			LifeLeechGainRate = 0, EnergyShieldLeechGainRate = 0,
			PhysicalDamageReduction = 30, EvadeChance = 0,
			EffectiveBlockChance = 0, EffectiveSpellSuppressionChance = 0,
		}
		if overrides then
			for k, v in pairs(overrides) do out[k] = v end
		end
		return out
	end

	local function makeBuild(mainOutput, level)
		return { calcsTab = { mainOutput = mainOutput }, characterLevel = level or 90 }
	end

	local function byId(findings, id)
		for _, f in ipairs(findings) do
			if f.id == id then return f end
		end
		return nil
	end

	it("returns no findings when the build is not calculated", function()
		assert.are.equal(0, #Advisor.analyze({ }))
		assert.are.equal(0, #Advisor.analyze(makeBuild(nil)))
	end)

	it("produces no survivability findings for a healthy build", function()
		assert.are.equal(0, #Advisor.analyze(makeBuild(healthyOutput())))
	end)

	it("flags an under-cap elemental resistance with the exact deficit", function()
		local findings = Advisor.analyze(makeBuild(healthyOutput({ FireResist = 58, FireResistOverCap = -17 })))
		local f = byId(findings, "res.fire.uncapped")
		assert.is_truthy(f)
		assert.are.equal("high", f.severity)
		assert.is_truthy(f.detail:find("58"))
		assert.is_truthy(f.detail:find("17"))
	end)

	it("flags chaos as med severity and respects Chaos Inoculation", function()
		local under = Advisor.analyze(makeBuild(healthyOutput({ ChaosResist = -30, ChaosResistOverCap = -30 })))
		local f = byId(under, "res.chaos.uncapped")
		assert.is_truthy(f)
		assert.are.equal("med", f.severity)

		local immune = Advisor.analyze(makeBuild(healthyOutput({ ChaosResist = -30, ChaosResistOverCap = -30, ChaosInoculation = true })))
		assert.is_nil(byId(immune, "res.chaos.uncapped"))
	end)

	it("sorts higher severity before lower", function()
		local findings = Advisor.analyze(makeBuild(healthyOutput({ FireResistOverCap = -25, ChaosResistOverCap = -30, ChaosResist = -30 })))
		assert.is_true(#findings >= 2)
		assert.are.equal("high", findings[1].severity)
	end)

	it("flags wasted elemental resistance over the cap as info", function()
		local f = byId(Advisor.analyze(makeBuild(healthyOutput({ FireResistOverCap = 20 }))), "res.fire.surplus")
		assert.is_truthy(f)
		assert.are.equal("info", f.severity)
		assert.is_truthy(f.detail:find("20"))
	end)

	it("flags low effective HP for the level and not when ample", function()
		local low = byId(Advisor.analyze(makeBuild(healthyOutput({ TotalEHP = 5000 }), 90)), "ehp.low")
		assert.is_truthy(low)
		assert.are.equal("med", low.severity)
		assert.is_nil(byId(Advisor.analyze(makeBuild(healthyOutput({ TotalEHP = 40000 }), 90)), "ehp.low"))
	end)

	it("flags missing recovery", function()
		local f = byId(Advisor.analyze(makeBuild(healthyOutput({ LifeRegenRecovery = 0, EnergyShieldRegenRecovery = 0, LifeLeechGainRate = 0, EnergyShieldLeechGainRate = 0 }))), "recovery.none")
		assert.is_truthy(f)
		assert.are.equal("med", f.severity)
	end)

	it("flags missing mitigation layers", function()
		local f = byId(Advisor.analyze(makeBuild(healthyOutput({ PhysicalDamageReduction = 0, EvadeChance = 0, EffectiveBlockChance = 0, EffectiveSpellSuppressionChance = 0 }))), "mitigation.none")
		assert.is_truthy(f)
		assert.are.equal("med", f.severity)
	end)

	it("surfaces the weakest damage type by max hit", function()
		local f = byId(Advisor.analyze(makeBuild(healthyOutput({
			PhysicalMaximumHitTaken = 5000, FireMaximumHitTaken = 3000,
			ColdMaximumHitTaken = 8000, LightningMaximumHitTaken = 8000, ChaosMaximumHitTaken = 9000,
		}))), "maxhit.weakest")
		assert.is_truthy(f)
		assert.is_truthy(f.detail:find("Fire"))
		assert.is_truthy(f.detail:find("3000"))
	end)

	local function activeGem(name, skillType)
		return { enabled = true, gemData = { name = name, gameId = name, grantedEffect = { name = name, skillTypes = { [skillType] = true } } } }
	end

	local function supportGem(name, gameId, opts)
		opts = opts or { }
		return { enabled = true, gemData = { name = name, gameId = gameId or name, grantedEffect = {
			name = name, support = true,
			requireSkillTypes = opts.require or { },
			excludeSkillTypes = opts.exclude or { },
			addSkillTypes = opts.add or { },
		} } }
	end

	local function makeSkillBuild(socketGroupList, outOverrides)
		return { calcsTab = { mainOutput = healthyOutput(outOverrides) }, characterLevel = 90, skillsTab = { socketGroupList = socketGroupList } }
	end

	it("flags a support whose tags do not match the active skill", function()
		local group = { enabled = true, gemList = {
			activeGem("Spark", SkillType.Spell),
			supportGem("Melee Infusion", "melee", { require = { SkillType.Attack } }),
		} }
		local f = byId(Advisor.analyze(makeSkillBuild({ group })), "support.inapplicable.Melee Infusion")
		assert.is_truthy(f)
		assert.are.equal("high", f.severity)
	end)

	it("does not flag a support whose tags match", function()
		local group = { enabled = true, gemList = {
			activeGem("Spark", SkillType.Spell),
			supportGem("Spell Echo", "echo", { require = { SkillType.Spell } }),
		} }
		assert.is_nil(byId(Advisor.analyze(makeSkillBuild({ group })), "support.inapplicable.Spell Echo"))
	end)

	it("flags a group with no support gems", function()
		local group = { enabled = true, gemList = { activeGem("Spark", SkillType.Spell) } }
		assert.is_truthy(byId(Advisor.analyze(makeSkillBuild({ group })), "support.empty.Spark"))
	end)

	it("flags a duplicate support gem", function()
		local group = { enabled = true, gemList = {
			activeGem("Spark", SkillType.Spell),
			supportGem("Spell Echo", "echo", { require = { SkillType.Spell } }),
			supportGem("Spell Echo", "echo", { require = { SkillType.Spell } }),
		} }
		local f = byId(Advisor.analyze(makeSkillBuild({ group })), "support.duplicate.echo")
		assert.is_truthy(f)
		assert.are.equal("med", f.severity)
	end)

	it("flags an unmet attribute requirement", function()
		local gem = activeGem("Heavy Skill", SkillType.Spell)
		gem.reqStr = 200
		local group = { enabled = true, gemList = { gem } }
		local f = byId(Advisor.analyze(makeSkillBuild({ group }, { Str = 100 })), "attr.unmet.Str.Heavy Skill")
		assert.is_truthy(f)
		assert.are.equal("high", f.severity)
		assert.is_truthy(f.detail:find("200"))
	end)

	it("flags over-reserved and unused spirit", function()
		local over = byId(Advisor.analyze(makeBuild(healthyOutput({ Spirit = 100, SpiritUnreserved = -10 }))), "spirit.over")
		assert.is_truthy(over)
		assert.are.equal("high", over.severity)
		local unused = byId(Advisor.analyze(makeBuild(healthyOutput({ Spirit = 100, SpiritUnreserved = 50 }))), "spirit.unused")
		assert.is_truthy(unused)
		assert.are.equal("info", unused.severity)
	end)
end)
