-- Path of Building
--
-- Module: Advisor Tab
-- Deterministic build-advisor tab. UI only — all rule logic lives in Modules/Advisor.lua.
--
local Advisor = LoadModule("Modules/Advisor")

local severityColor = {
	high = colorCodes.NEGATIVE,
	med = colorCodes.WARNING,
	low = colorCodes.NORMAL,
	info = "^8",
}

local AdvisorTabClass = newClass("AdvisorTab", "ControlHost", "Control", function(self, build)
	self.ControlHost()
	self.Control()

	self.build = build

	self.findings = { }

	self.controls.title = new("LabelControl", {"TOPLEFT",self,"TOPLEFT"}, {8, 8, 0, 20}, "^7Advisor")
	self.controls.refresh = new("ButtonControl", {"TOPLEFT",self.controls.title,"TOPLEFT"}, {0, 28, 80, 20}, "Refresh", function()
		self:Refresh()
	end)
end)

function AdvisorTabClass:Refresh()
	self.findings = Advisor.analyze(self.build) or { }
end

function AdvisorTabClass:Draw(viewPort, inputEvents)
	self.x = viewPort.x
	self.y = viewPort.y
	self.width = viewPort.width
	self.height = viewPort.height

	self:ProcessControlsInput(inputEvents, viewPort)

	main:DrawBackground(viewPort)

	self:DrawControls(viewPort)

	local x = viewPort.x + 8
	local y = viewPort.y + 80
	local findings = self.findings or { }
	if #findings == 0 then
		DrawString(x, y, "LEFT", 16, "VAR", "^7No issues found.")
		return
	end
	for _, f in ipairs(findings) do
		local color = severityColor[f.severity] or "^7"
		DrawString(x, y, "LEFT", 16, "VAR BOLD", color .. "[" .. f.severity:upper() .. "] " .. (f.title or ""))
		y = y + 18
		if f.detail then
			DrawString(x + 16, y, "LEFT", 14, "VAR", "^7" .. f.detail)
			y = y + 16
		end
		if f.fix then
			DrawString(x + 16, y, "LEFT", 14, "VAR", "^8Fix: " .. f.fix)
			y = y + 16
		end
		y = y + 6
	end
end
