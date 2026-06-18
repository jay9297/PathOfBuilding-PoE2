-- Path of Building
--
-- Module: Advisor
-- Pure, deterministic build-advisor logic. No UI references — unit-testable headlessly.
-- Reads the already-calculated build (build.calcsTab.mainOutput) and returns findings.
--
-- Severity guide:
--   high = likely loss or disabled (uncapped elemental resistance)
--   med  = meaningful weakness (under-cap chaos, low EHP, no mitigation/recovery layer)
--   low  = minor improvement
--   info = informational (wasted resistance surplus, weakest max-hit type)
--
local t_insert = table.insert
local t_sort = table.sort
local s_format = string.format

local Advisor = { }

Advisor.severityRank = { high = 3, med = 2, low = 1, info = 0 }

-- Each check is function(build, out, findings) and appends 0..n findings.
-- A finding is { id, severity, category, title, detail, fix, jump }.
Advisor.checks = { }

-- Tunable heuristics (each documented inline).
local RESIST_SURPLUS_INFO = 10    -- >10% resistance over the cap is meaningful wasted gear budget
local EHP_FLOOR_BASE = 1500       -- heuristic effective-HP floor at level 1...
local EHP_FLOOR_PER_LEVEL = 150   -- ...growing per character level; below this a build is usually too squishy
local RECOVERY_EPSILON = 0.5      -- per-second recovery at/below this counts as "no sustain"
local PHYS_DR_MIN = 10            -- % physical damage reduction that counts as an armour layer
local EVADE_MIN = 20              -- % evade that counts as an evasion layer
local BLOCK_MIN = 10              -- % block that counts as a block layer
local SUPPRESS_MIN = 30           -- % spell suppression that counts as a suppression layer

local ELEM_RESISTS = {
	{ key = "Fire", label = "Fire", severity = "high" },
	{ key = "Cold", label = "Cold", severity = "high" },
	{ key = "Lightning", label = "Lightning", severity = "high" },
}

local ALL_RESISTS = {
	{ key = "Fire", label = "Fire", severity = "high" },
	{ key = "Cold", label = "Cold", severity = "high" },
	{ key = "Lightning", label = "Lightning", severity = "high" },
	{ key = "Chaos", label = "Chaos", severity = "med" },
}

local MAX_HIT_TYPES = {
	{ key = "Physical", label = "Physical" },
	{ key = "Fire", label = "Fire" },
	{ key = "Cold", label = "Cold" },
	{ key = "Lightning", label = "Lightning" },
	{ key = "Chaos", label = "Chaos" },
}

-- Check 1: resistances below cap.
t_insert(Advisor.checks, function(build, out, findings)
	for _, res in ipairs(ALL_RESISTS) do
		if not (res.key == "Chaos" and out.ChaosInoculation) then
			local value = out[res.key .. "Resist"]
			local overCap = out[res.key .. "ResistOverCap"]
			if value and overCap and overCap < 0 then
				local deficit = -overCap
				t_insert(findings, {
					id = "res." .. res.key:lower() .. ".uncapped",
					severity = res.severity,
					category = "Survivability",
					title = res.label .. " Resistance is below cap",
					detail = s_format("%s Res %d%% (-%d%% under the cap).", res.label, value, deficit),
					fix = s_format("Add ~%d%% %s Resistance on gear, runes, or the tree.", deficit, res.label),
					jump = { mode = "ITEMS" },
				})
			end
		end
	end
end)

-- Check 2: wasted elemental resistance over the cap (informational).
t_insert(Advisor.checks, function(build, out, findings)
	for _, res in ipairs(ELEM_RESISTS) do
		local overCap = out[res.key .. "ResistOverCap"]
		if overCap and overCap > RESIST_SURPLUS_INFO then
			t_insert(findings, {
				id = "res." .. res.key:lower() .. ".surplus",
				severity = "info",
				category = "Survivability",
				title = res.label .. " Resistance is over the cap",
				detail = s_format("%s Res is %d%% over the cap (wasted).", res.label, overCap),
				fix = s_format("You could move ~%d%% %s Resistance to another stat.", overCap, res.label),
			})
		end
	end
end)

-- Check 3: effective HP pool too low for the character level.
t_insert(Advisor.checks, function(build, out, findings)
	local ehp = out.TotalEHP
	if not ehp then
		ehp = (out.Life or 0) + (out.EnergyShield or 0)
	end
	if ehp and ehp > 0 then
		local level = (build and build.characterLevel) or 1
		local floor = EHP_FLOOR_BASE + EHP_FLOOR_PER_LEVEL * level
		if ehp < floor then
			t_insert(findings, {
				id = "ehp.low",
				severity = "med",
				category = "Survivability",
				title = "Effective HP looks low for your level",
				detail = s_format("Effective Hit Pool %d at level %d (heuristic floor ~%d).", ehp, level, floor),
				fix = "Add Life, Energy Shield, or mitigation to raise your effective HP.",
			})
		end
	end
end)

-- Check 4: no meaningful life/ES recovery layer.
t_insert(Advisor.checks, function(build, out, findings)
	local lifeRegen = out.LifeRegenRecovery or 0
	local esRegen = out.EnergyShieldRegenRecovery or 0
	local lifeLeech = out.LifeLeechGainRate or 0
	local esLeech = out.EnergyShieldLeechGainRate or 0
	if lifeRegen <= RECOVERY_EPSILON and esRegen <= RECOVERY_EPSILON
		and lifeLeech <= RECOVERY_EPSILON and esLeech <= RECOVERY_EPSILON then
		t_insert(findings, {
			id = "recovery.none",
			severity = "med",
			category = "Survivability",
			title = "No meaningful Life or ES recovery",
			detail = "No notable life/ES regeneration or leech was found.",
			fix = "Add life/ES regeneration, leech, or recoup so you recover between hits.",
		})
	end
end)

-- Check 5: no meaningful mitigation layer present.
t_insert(Advisor.checks, function(build, out, findings)
	local physDR = out.PhysicalDamageReduction or 0
	local evade = out.EvadeChance or out.MeleeEvadeChance or 0
	local block = out.EffectiveBlockChance or 0
	local suppress = out.EffectiveSpellSuppressionChance or 0
	local hasLayer = physDR >= PHYS_DR_MIN or evade >= EVADE_MIN or block >= BLOCK_MIN or suppress >= SUPPRESS_MIN
	if not hasLayer then
		t_insert(findings, {
			id = "mitigation.none",
			severity = "med",
			category = "Survivability",
			title = "No meaningful mitigation layer",
			detail = s_format("Phys DR %d%%, Evade %d%%, Block %d%%, Suppression %d%% - all below useful levels.", physDR, evade, block, suppress),
			fix = "Add armour, evasion, block, or spell suppression to reduce incoming damage.",
		})
	end
end)

-- Check 6: surface the weakest damage type by maximum hit taken (informational).
t_insert(Advisor.checks, function(build, out, findings)
	local weakestType, weakestValue
	for _, hit in ipairs(MAX_HIT_TYPES) do
		local v = out[hit.key .. "MaximumHitTaken"]
		if v and v > 0 and (not weakestValue or v < weakestValue) then
			weakestValue = v
			weakestType = hit.label
		end
	end
	if weakestType then
		t_insert(findings, {
			id = "maxhit.weakest",
			severity = "info",
			category = "Survivability",
			title = "Weakest defence is vs " .. weakestType,
			detail = s_format("Largest survivable %s hit is %d (your lowest max hit).", weakestType, weakestValue),
			fix = s_format("Shore up %s mitigation if you die to %s spikes.", weakestType, weakestType),
		})
	end
end)

function Advisor.sort(findings)
	t_sort(findings, function(a, b)
		local ra = Advisor.severityRank[a.severity] or 0
		local rb = Advisor.severityRank[b.severity] or 0
		if ra ~= rb then return ra > rb end
		if a.category ~= b.category then return a.category < b.category end
		return (a.title or "") < (b.title or "")
	end)
	return findings
end

function Advisor.analyze(build)
	local findings = { }
	local out = build and build.calcsTab and build.calcsTab.mainOutput
	if not out then return findings end
	for _, check in ipairs(Advisor.checks) do
		local ok, err = pcall(check, build, out, findings)
		if not ok then
			ConPrintf("Advisor check error: %s", tostring(err))
		end
	end
	Advisor.sort(findings)
	return findings
end

return Advisor
