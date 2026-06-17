local lib

describe("SkillStatCoverage #data", function()
	lazy_setup(function()
		local saved_path = package.path
		package.path = "../tools/?.lua;" .. package.path
		lib = require("skill_stat_coverage_lib")
		package.path = saved_path
	end)
	it("manifest matches committed audit/skill-stat-coverage.txt", function()
		local expected = lib.generate(data.skills, data.skillStatMap)

		local f, err = io.open("../audit/skill-stat-coverage.txt", "r")
		assert(f, "audit/skill-stat-coverage.txt not found: " .. tostring(err))
		local actual = f:read("*a")
		f:close()

		if expected .. "\n" == actual then
			return
		end

		-- Build sets from each side to avoid false positives from a single
		-- inserted line shifting all subsequent positional comparisons.
		local committed_set = {}
		for line in actual:gmatch("([^\n]*)\n") do
			committed_set[line] = true
		end
		local generated_set = {}
		for line in (expected .. "\n"):gmatch("([^\n]*)\n") do
			generated_set[line] = true
		end

		-- "-" = in committed file but not in generated (removed)
		-- "+" = in generated but not in committed (added)
		local diff_lines = {}
		for line in actual:gmatch("([^\n]*)\n") do
			if not generated_set[line] then
				diff_lines[#diff_lines + 1] = "- " .. line
			end
		end
		for line in (expected .. "\n"):gmatch("([^\n]*)\n") do
			if not committed_set[line] then
				diff_lines[#diff_lines + 1] = "+ " .. line
			end
		end

		local diff = table.concat(diff_lines, "\n")
		fail("audit/skill-stat-coverage.txt is stale. Re-run: luajit tools/audit_skill_stats.lua\nDiff:\n" .. diff)
	end)

	it("well-known mapped stats are not in the unmapped set", function()
		local result = lib.analyse(data.skills, data.skillStatMap)
		local unmappedSet = {}
		for _, entry in ipairs(result.unmapped) do
			unmappedSet[entry.statId] = true
		end

		local wellKnownMapped = {
			"spell_minimum_base_fire_damage",
			"spell_maximum_base_fire_damage",
			"base_skill_effect_duration",
			"number_of_chains",
			"spell_minimum_base_lightning_damage",
		}
		for _, statId in ipairs(wellKnownMapped) do
			assert.is_nil(unmappedSet[statId],
				"Expected mapped stat '" .. statId .. "' found in unmapped set — resolution order may be wrong")
		end
	end)
end)
