package.path = "../tools/?.lua;" .. package.path
local lib = require("mod_coverage_lib")

describe("ModCoverage #data", function()
    it("manifest matches committed audit/mod-coverage.txt", function()
        local expected = lib.generate("../src/Data/ModCache.lua")

        local f, err = io.open("../audit/mod-coverage.txt", "r")
        assert(f, "audit/mod-coverage.txt not found: " .. tostring(err))
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
        fail("audit/mod-coverage.txt is stale. Re-run: luajit tools/audit_mod_coverage.lua\nDiff:\n" .. diff)
    end)
end)
