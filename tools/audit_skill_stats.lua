#!/usr/bin/env luajit
-- Standalone skill stat coverage audit.
-- Run from src/ directory: cd src && luajit ../tools/audit_skill_stats.lua

dofile("HeadlessWrapper.lua")

package.path = "../tools/?.lua;" .. package.path
local lib = require("skill_stat_coverage_lib")

local manifest = lib.generate(data.skills, data.skillStatMap)

local out_path = "../audit/skill-stat-coverage.txt"
local f, err = io.open(out_path, "w")
if not f then
	io.stderr:write("Failed to open " .. out_path .. " for writing: " .. tostring(err) .. "\n")
	os.exit(1)
end
f:write(manifest)
f:write("\n")
f:close()

io.stdout:write("Wrote " .. out_path .. "\n")
