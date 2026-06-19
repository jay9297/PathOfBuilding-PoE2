#!/usr/bin/env luajit
-- Standalone skill stat coverage audit.
-- Run from src/ directory: cd src && luajit ../tools/audit_skill_stats.lua

-- Bundled runtime libraries (xml, dkjson, sha1, ...) live in runtime/lua and
-- are normally added to the search path by the .busted config. Mirror that
-- here so the script can boot HeadlessWrapper standalone.
package.path = "../runtime/lua/?.lua;../runtime/lua/?/init.lua;" .. package.path

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
