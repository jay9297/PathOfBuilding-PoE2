-- Shared module for skill stat coverage audit. Used by both the standalone
-- audit script and the Busted regression-guard spec.
--
-- Stat resolution order (mirrors CalcActiveSkill.lua mergeSkillInstanceMods):
--   statSet.statMap[statId] — normal index; the __index metatable installed by
--   Data.lua transparently falls through to data.skillStatMap for any key not
--   present locally, so a single lookup covers both local and global entries.
-- If the stat ID is not found, the stat is unmapped — the calc engine
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

--- Check whether a stat ID has a mod mapping.
-- Resolution mirrors the engine: statSet.statMap[statId] transparently falls
-- through to data.skillStatMap via the __index metatable installed by Data.lua.
-- @param statId string
-- @param statSet table  The statSet being checked (for local statMap).
-- @return boolean  true if mapped.
local function isStatMapped(statId, statSet)
	-- Guard: some statSets (e.g. sentinel rows) have no local statMap
	if not statSet.statMap then
		return false
	end
	-- Normal index: metatable __index falls through to data.skillStatMap
	if statSet.statMap[statId] then
		return true
	end
	return false
end

--- Analyse all skills and classify stat IDs as mapped or unmapped.
-- Requires the PoB data layer to be loaded (data.skills, data.skillStatMap).
-- @param skills table  data.skills (the granted effects table).
-- @param globalSkillStatMap table  data.skillStatMap (kept for API compatibility, no longer used directly).
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
				skillList[#skillList + 1] = grantedEffect.name or "(unnamed)"
			end
		end
	end

	-- Now check each stat ID against the mapping
	-- We need to check across ALL statSets that reference the stat,
	-- using the first one we find (since local statMap varies by statSet).
	-- Build a lookup: statId → first statSet that contains it
	local statToStatSet = {}
	for skillId, grantedEffect in pairs(skills) do
		-- qualityStats live at the top level of grantedEffect; resolve them
		-- through the first available statSet (mirrors SkillsTab.lua line 883).
		local fallbackStatSet = (grantedEffect.statSets or {})[1]
		for _, entry in ipairs(grantedEffect.qualityStats or {}) do
			local statId = entry[1]
			if not statToStatSet[statId] then
				if fallbackStatSet then
					statToStatSet[statId] = fallbackStatSet
				else
					-- No statSets at all: use a sentinel with the global map
					statToStatSet[statId] = { statMap = globalSkillStatMap }
				end
			end
		end

		for _, statSet in ipairs(grantedEffect.statSets or {}) do
			-- Check stats[]
			for _, statId in ipairs(statSet.stats or {}) do
				if not statToStatSet[statId] then
					statToStatSet[statId] = statSet
				end
			end
			-- Check constantStats[]
			for _, entry in ipairs(statSet.constantStats or {}) do
				local statId = entry[1]
				if not statToStatSet[statId] then
					statToStatSet[statId] = statSet
				end
			end
		end
	end

	local unmapped = {}
	local mapped = 0

	for _, statId in ipairs(allStatIds) do
		local statSet = statToStatSet[statId]
		if statSet and isStatMapped(statId, statSet) then
			mapped = mapped + 1
		else
			local skillNames = statToSkills[statId] or {}
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

	lines[#lines + 1] = string.format(
		"# unmapped=%d total_stats=%d",
		result.unmappedCount, result.totalStats
	)

	for _, entry in ipairs(result.unmapped) do
		-- Sort skill names for deterministic output before slicing
		local sortedNames = {}
		for i, v in ipairs(entry.skillNames) do sortedNames[i] = v end
		table.sort(sortedNames)
		local showCount = math.min(5, #sortedNames)
		local names = {}
		for i = 1, showCount do
			names[i] = sortedNames[i]
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
