describe("Advisor", function()
	local Advisor

	before_each(function()
		newBuild()
		Advisor = require("Modules/Advisor")
	end)

	local function makeBuild(mainOutput)
		return { calcsTab = { mainOutput = mainOutput } }
	end

	it("returns no findings when the build is not calculated", function()
		assert.are.equal(0, #Advisor.analyze({ }))
		assert.are.equal(0, #Advisor.analyze(makeBuild(nil)))
	end)

	it("flags an under-cap elemental resistance with the exact deficit", function()
		local findings = Advisor.analyze(makeBuild({
			FireResist = 58, FireResistOverCap = -17,
			ColdResist = 75, ColdResistOverCap = 0,
			LightningResist = 75, LightningResistOverCap = 12,
			ChaosResist = 0, ChaosResistOverCap = 0,
		}))
		assert.are.equal(1, #findings)
		local f = findings[1]
		assert.are.equal("res.fire.uncapped", f.id)
		assert.are.equal("high", f.severity)
		assert.is_truthy(f.detail:find("58"))
		assert.is_truthy(f.detail:find("17"))
	end)

	it("flags chaos as med severity and respects Chaos Inoculation", function()
		local under = Advisor.analyze(makeBuild({
			FireResist = 75, FireResistOverCap = 0,
			ColdResist = 75, ColdResistOverCap = 0,
			LightningResist = 75, LightningResistOverCap = 0,
			ChaosResist = -30, ChaosResistOverCap = -30,
		}))
		assert.are.equal(1, #under)
		assert.are.equal("med", under[1].severity)

		local immune = Advisor.analyze(makeBuild({
			FireResist = 75, FireResistOverCap = 0,
			ColdResist = 75, ColdResistOverCap = 0,
			LightningResist = 75, LightningResistOverCap = 0,
			ChaosResist = -30, ChaosResistOverCap = -30,
			ChaosInoculation = true,
		}))
		assert.are.equal(0, #immune)
	end)

	it("sorts higher severity first", function()
		local findings = Advisor.analyze(makeBuild({
			FireResist = 50, FireResistOverCap = -25,
			ColdResist = 75, ColdResistOverCap = 0,
			LightningResist = 75, LightningResistOverCap = 0,
			ChaosResist = -30, ChaosResistOverCap = -30,
		}))
		assert.are.equal(2, #findings)
		assert.are.equal("high", findings[1].severity)
		assert.are.equal("med", findings[2].severity)
	end)
end)
