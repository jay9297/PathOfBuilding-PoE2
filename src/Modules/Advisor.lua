-- Path of Building
--
-- Module: Advisor
-- Pure, deterministic build-advisor logic. No UI references — unit-testable headlessly.
-- Reads the already-calculated build (build.calcsTab.mainOutput) and returns findings.
--
local t_insert = table.insert
local t_sort = table.sort
local s_format = string.format

local Advisor = { }

-- Severity ranking: higher sorts first.
Advisor.severityRank = { high = 3, med = 2, low = 1, info = 0 }

-- Each check is function(build, out, findings) and appends 0..n findings.
-- A finding is { id, severity, category, title, detail, fix, jump }.
Advisor.checks = { }

local RESISTS = {
	{ key = "Fire", label = "Fire", severity = "high" },
	{ key = "Cold", label = "Cold", severity = "high" },
	{ key = "Lightning", label = "Lightning", severity = "high" },
	{ key = "Chaos", label = "Chaos", severity = "med" },
}

-- Check: resistances below cap. <Elem>ResistOverCap < 0 means under the max cap.
t_insert(Advisor.checks, function(build, out, findings)
	for _, res in ipairs(RESISTS) do
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
