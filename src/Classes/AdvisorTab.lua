-- Path of Building
--
-- Module: Advisor Tab
-- Deterministic build-advisor tab (UI shell). Analysis logic lands in a later issue.
--
local AdvisorTabClass = newClass("AdvisorTab", "ControlHost", "Control", function(self, build)
	self.ControlHost()
	self.Control()

	self.build = build

	self.findings = { }

	self.controls.title = new("LabelControl", {"TOPLEFT",self,"TOPLEFT"}, {8, 8, 0, 20}, "^7Advisor")
	self.controls.refresh = new("ButtonControl", {"TOPLEFT",self.controls.title,"TOPLEFT"}, {0, 28, 80, 20}, "Refresh", function()
		self:Refresh()
	end)
	self.controls.body = new("LabelControl", {"TOPLEFT",self.controls.refresh,"TOPLEFT"}, {0, 32, 0, 16}, "^7No findings yet — press Refresh")
end)

function AdvisorTabClass:Refresh()
	-- No-op stub. Issue #79 wires this to Advisor.analyze(self.build).
end

function AdvisorTabClass:Draw(viewPort, inputEvents)
	self.x = viewPort.x
	self.y = viewPort.y
	self.width = viewPort.width
	self.height = viewPort.height

	self:ProcessControlsInput(inputEvents, viewPort)

	main:DrawBackground(viewPort)

	self:DrawControls(viewPort)
end
