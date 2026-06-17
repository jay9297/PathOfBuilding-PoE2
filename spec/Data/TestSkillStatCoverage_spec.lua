package.path = "../tools/?.lua;" .. package.path
local lib = require("skill_stat_coverage_lib")

describe("SkillStatCoverage #data", function()
	it("manifest matches committed audit/skill-stat-coverage.txt", function()
		local expected = lib.generate(data.skills, data.skillStatMap)

		local f, err = io.open("../audit/skill-stat-coverage.txt", "r")
		assert(f, "audit/skill-stat-coverage.txt not found: " .. tostring(err))
		local actual = f:read("*a")
		f:close()

		if expected .. "\n" == actual then
			return
		end

		local expected_lines = {}
		for line in (expected .. "\n"):gmatch("([^\n]*)\n") do
			expected_lines[#expected_lines + 1] = line
		end
		local actual_lines = {}
		for line in actual:gmatch("([^\n]*)\n") do
			actual_lines[#actual_lines + 1] = line
		end

		local added, removed = {}, {}
		local max = math.max(#expected_lines, #actual_lines)
		for i = 1, max do
			if expected_lines[i] ~= actual_lines[i] then
				if expected_lines[i] then
					removed[#removed + 1] = "- " .. expected_lines[i]
				end
				if actual_lines[i] then
					added[#added + 1] = "+ " .. actual_lines[i]
				end
			end
		end

		local diff = table.concat(removed, "\n") .. "\n" .. table.concat(added, "\n")
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
