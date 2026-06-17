-- Shared module for skill stat coverage audit. Used by both the standalone
-- audit script and the Busted regression-guard spec.
--
-- Stat resolution order (mirrors CalcActiveSkill.lua mergeSkillInstanceMods):
--   1. Local statMap on the statSet (rawget, bypasses metatable)
--   2. Global data.skillStatMap (loaded from Data/SkillStatMap.lua)
-- If neither contains the stat ID, the stat is unmapped — the calc engine
-- silently drops it, producing no mod.

local M = {}

--- Collect every stat ID referenced by a granted effect (all statSets).
-- Includes: statSet.stats[], statSet.constantStats[][1], grantedEffect.qualityStats[][1].
-- @param grantedEffect table  A single granted effect from data.skills[id].
-- @return table  Array of { statId = string, setName = string } entries.
local function collectStatIds(grantedEffect)
	local result = {}
	local seen = {}

	-- Quality stats (top-level on the granted effect)
	if grantedEffect.qualityStats then
		for _, entry in ipairs(grantedEffect.qualityStats) do
			local statId = entry[1]
			if not seen[statId] then
				seen[statId] = true
				result[#result + 1] = { statId = statId, setName = "qualityStats" }
			end
		end
	end

	-- Each statSet
	for setIdx, statSet in ipairs(grantedEffect.statSets or {}) do
		local setName = statSet.label or ("statSet_" .. setIdx)

		-- stats[] — boolean/flag stats and per-level-scaled stats
		for _, statId in ipairs(statSet.stats or {}) do
			if not seen[statId] then
				seen[statId] = true
				result[#result + 1] = { statId = statId, setName = setName }
			end
		end

		-- constantStats[] — { statId, value } pairs
		for _, entry in ipairs(statSet.constantStats or {}) do
			local statId = entry[1]
			if not seen[statId] then
				seen[statId] = true
				result[#result + 1] = { statId = statId, setName = setName }
			end
		end
	end

	return result
end

--- Analyse all skills and classify stat IDs as mapped or unmapped.
-- Requires the PoB data layer to be loaded (data.skills, data.skillStatMap).
-- @param skills table  data.skills (the granted effects table).
-- @param globalSkillStatMap table  data.skillStatMap.
-- @return table  { unmapped = { {statId, count, skillNames}... }, totalStats = N, unmappedCount = N }
function M.analyse(skills, globalSkillStatMap)
	-- Collect all unique stat IDs across all skills, tracking which skills use each
	local statToSkills = {}  -- statId → { skillName1, skillName2, ... }
	local allStatIds = {}    -- ordered list of unique stat IDs

	for skillId, grantedEffect in pairs(skills) do
		local entries = collectStatIds(grantedEffect)
		for _, entry in ipairs(entries) do
			local statId = entry.statId
			if not statToSkills[statId] then
				statToSkills[statId] = {}
				allStatIds[#allStatIds + 1] = statId
			end
			local skillList = statToSkills[statId]
			-- Deduplicate skill names per stat
			local already = false
			for _, name in ipairs(skillList) do
				if name == grantedEffect.name then
					already = true
					break
				end
			end
			if not already then
				skillList[#skillList + 1] = grantedEffect.name
			end
		end
	end

	-- Determine which stat IDs are mapped by a *local* statMap. A stat may
	-- appear in several statSets; treat it as locally mapped if ANY statSet
	-- referencing it maps it. This is order-independent (unlike picking an
	-- arbitrary "first" statSet) so the manifest is deterministic regardless
	-- of pairs() iteration order, and it matches the calc engine's behaviour:
	-- a stat that resolves in any context is not silently dropped everywhere.
	local locallyMapped = {}
	for _, grantedEffect in pairs(skills) do
		for _, statSet in ipairs(grantedEffect.statSets or {}) do
			if statSet.statMap then
				for _, statId in ipairs(statSet.stats or {}) do
					if rawget(statSet.statMap, statId) then
						locallyMapped[statId] = true
					end
				end
				for _, entry in ipairs(statSet.constantStats or {}) do
					if rawget(statSet.statMap, entry[1]) then
						locallyMapped[entry[1]] = true
					end
				end
			end
		end
	end

	local unmapped = {}
	local mapped = 0

	for _, statId in ipairs(allStatIds) do
		if locallyMapped[statId] or globalSkillStatMap[statId] then
			mapped = mapped + 1
		else
			local skillNames = statToSkills[statId] or {}
			-- Sort skill names so the "first few" rendered in the manifest are
			-- stable across runs (pairs() order over data.skills is undefined).
			table.sort(skillNames)
			unmapped[#unmapped + 1] = {
				statId = statId,
				count = #skillNames,
				skillNames = skillNames,
			}
		end
	end

	-- Sort unmapped by stat ID for deterministic output
	table.sort(unmapped, function(a, b) return a.statId < b.statId end)

	return {
		unmapped = unmapped,
		totalStats = #allStatIds,
		unmappedCount = #unmapped,
		mappedCount = mapped,
	}
end

--- Render analysis results as a manifest string.
-- @param result table  Return value from M.analyse().
-- @return string
function M.render(result)
	local lines = {}

	-- Generated artifact: every token below is a game stat ID or skill name
	-- (some carry typos baked into the game data). Disable spell-checking so the
	-- CI spellcheck job does not flag GGG's identifiers as misspellings.
	lines[#lines + 1] = "# cspell:disable"
	lines[#lines + 1] = string.format(
		"# unmapped=%d total_stats=%d",
		result.unmappedCount, result.totalStats
	)

	for _, entry in ipairs(result.unmapped) do
		local showCount = math.min(5, #entry.skillNames)
		local names = {}
		for i = 1, showCount do
			names[i] = entry.skillNames[i]
		end
		lines[#lines + 1] = string.format(
			"%s\t%d\t%s",
			entry.statId,
			entry.count,
			table.concat(names, ", ")
		)
	end

	return table.concat(lines, "\n")
end

--- Convenience: analyse + render in one call.
-- @param skills table  data.skills.
-- @param globalSkillStatMap table  data.skillStatMap.
-- @return string
function M.generate(skills, globalSkillStatMap)
	return M.render(M.analyse(skills, globalSkillStatMap))
end

return M
