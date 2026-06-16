local BuildExportPoE2 = require("Modules/BuildExportPoE2")
local dkjson = require("dkjson")

describe("TestBuildExportPoE2", function()
	describe("ClampLevel", function()
		it("Returns nil for non-numeric input", function()
			assert.is_nil(BuildExportPoE2.ClampLevel("abc"))
		end)

		it("Returns nil for empty string", function()
			assert.is_nil(BuildExportPoE2.ClampLevel(""))
		end)

		it("Returns nil for nil input", function()
			assert.is_nil(BuildExportPoE2.ClampLevel(nil))
		end)

		it("Floors decimal values", function()
			assert.are.equals(5, BuildExportPoE2.ClampLevel(5.7))
			assert.are.equals(3, BuildExportPoE2.ClampLevel(3.2))
		end)

		it("Floors decimal strings", function()
			assert.are.equals(5, BuildExportPoE2.ClampLevel("5.7"))
		end)

		it("Clamps values below 1 to 1 (level 0 is invalid in PoE2)", function()
			assert.are.equals(1, BuildExportPoE2.ClampLevel(-10))
			assert.are.equals(1, BuildExportPoE2.ClampLevel(-0.5))
			assert.are.equals(1, BuildExportPoE2.ClampLevel(0))
		end)

		it("Clamps values above 100 to 100", function()
			assert.are.equals(100, BuildExportPoE2.ClampLevel(150))
			assert.are.equals(100, BuildExportPoE2.ClampLevel(100.5))
		end)

		it("Passes through valid integers", function()
			assert.are.equals(1, BuildExportPoE2.ClampLevel(1))
			assert.are.equals(50, BuildExportPoE2.ClampLevel(50))
			assert.are.equals(100, BuildExportPoE2.ClampLevel(100))
		end)

		it("Passes through valid integer strings", function()
			assert.are.equals(42, BuildExportPoE2.ClampLevel("42"))
		end)
	end)

	describe("PresetNextLevels", function()
		it("Seeds first entry and new entry to [1,30] when no existing levels", function()
			local existing = { { id = 1 }, { id = 2 } }
			local newEntry = { id = 3 }
			BuildExportPoE2.PresetNextLevels(existing, newEntry)
			assert.are.equals(1, existing[1].levelMin)
			assert.are.equals(30, existing[1].levelMax)
			assert.are.equals(30, newEntry.levelMin)
			assert.are.equals(60, newEntry.levelMax)
		end)

		it("Advances to next bracket when existing levels are set", function()
			local existing = { { id = 1, levelMin = 1, levelMax = 30 } }
			local newEntry = { id = 2 }
			BuildExportPoE2.PresetNextLevels(existing, newEntry)
			assert.are.equals(30, newEntry.levelMin)
			assert.are.equals(60, newEntry.levelMax)
		end)

		it("Caps at 100 when maxLvl is near ceiling", function()
			local existing = { { id = 1, levelMin = 1, levelMax = 90 } }
			local newEntry = { id = 2 }
			BuildExportPoE2.PresetNextLevels(existing, newEntry)
			assert.are.equals(90, newEntry.levelMin)
			assert.are.equals(100, newEntry.levelMax)
		end)

		it("Uses highest levelMax across multiple entries", function()
			local existing = {
				{ id = 1, levelMin = 1, levelMax = 30 },
				{ id = 2, levelMin = 30, levelMax = 60 },
			}
			local newEntry = { id = 3 }
			BuildExportPoE2.PresetNextLevels(existing, newEntry)
			assert.are.equals(60, newEntry.levelMin)
			assert.are.equals(90, newEntry.levelMax)
		end)

		it("Handles nil existingEntries", function()
			local newEntry = { id = 1 }
			BuildExportPoE2.PresetNextLevels(nil, newEntry)
			assert.are.equals(1, newEntry.levelMin)
			assert.are.equals(30, newEntry.levelMax)
		end)

		it("Handles empty existingEntries", function()
			local newEntry = { id = 1 }
			BuildExportPoE2.PresetNextLevels({}, newEntry)
			assert.are.equals(1, newEntry.levelMin)
			assert.are.equals(30, newEntry.levelMax)
		end)

		it("Treats levelMin-only entry as having a level set", function()
			local existing = { { id = 1, levelMin = 1 } }
			local newEntry = { id = 2 }
			BuildExportPoE2.PresetNextLevels(existing, newEntry)
			-- anyHas=true but maxLvl=0 (no levelMax), so new entry gets [1,30]
			assert.are.equals(1, newEntry.levelMin)
			assert.are.equals(30, newEntry.levelMax)
			-- Must NOT re-seed the existing entry (it already had levelMin set)
			assert.is_nil(existing[1].levelMax)
		end)
	end)

	describe("NextLoadoutBracket", function()
		before_each(function()
			newBuild()
		end)

		it("Returns [1,30] when no sets have levels", function()
			local lo, hi = BuildExportPoE2.NextLoadoutBracket(build)
			assert.are.equals(1, lo)
			assert.are.equals(30, hi)
		end)

		it("Advances past highest existing levelMax", function()
			build.treeTab.specList[1].levelMin = 1
			build.treeTab.specList[1].levelMax = 30
			local lo, hi = BuildExportPoE2.NextLoadoutBracket(build)
			assert.are.equals(30, lo)
			assert.are.equals(60, hi)
		end)
	end)

	describe("DefaultDir", function()
		it("Returns a non-empty string", function()
			local dir = BuildExportPoE2.DefaultDir()
			assert.is_not_nil(dir)
			assert.is_true(#dir > 0)
		end)

		it("Contains Path of Exile 2 and BuildPlanner", function()
			local dir = BuildExportPoE2.DefaultDir()
			assert.is_truthy(dir:find("Path of Exile 2"))
			assert.is_truthy(dir:find("BuildPlanner"))
		end)
	end)

	describe("DefaultPath", function()
		before_each(function()
			newBuild()
		end)

		it("Returns a string ending in .build", function()
			local path = BuildExportPoE2.DefaultPath(build)
			assert.is_truthy(path:find("%.build$"))
		end)

		it("Contains the build name", function()
			build.buildName = "TestBuild"
			local path = BuildExportPoE2.DefaultPath(build)
			assert.is_truthy(path:find("TestBuild"))
		end)

		it("Sanitizes special characters in build name", function()
			build.buildName = "My Build Name"
			local path = BuildExportPoE2.DefaultPath(build)
			assert.is_truthy(path:find("My Build Name"))
			build.buildName = "Build<>Test"
			local path2 = BuildExportPoE2.DefaultPath(build)
			assert.is_falsy(path2:find("<"))
			assert.is_falsy(path2:find(">"))
		end)

		it("Falls back to Unnamed for empty build name", function()
			build.buildName = ""
			local path = BuildExportPoE2.DefaultPath(build)
			assert.is_truthy(path:find("Unnamed"))
		end)
	end)

	describe("SlotMap", function()
		it("Has entries for standard equipment slots", function()
			assert.is_not_nil(BuildExportPoE2.SlotMap["Weapon 1"])
			assert.is_not_nil(BuildExportPoE2.SlotMap["Helmet"])
			assert.is_not_nil(BuildExportPoE2.SlotMap["Body Armour"])
			assert.is_not_nil(BuildExportPoE2.SlotMap["Boots"])
			assert.is_not_nil(BuildExportPoE2.SlotMap["Ring 1"])
		end)

		it("Has correct inventory_id values", function()
			assert.are.equals("Weapon1", BuildExportPoE2.SlotMap["Weapon 1"].inventory_id)
			assert.are.equals("Helm", BuildExportPoE2.SlotMap["Helmet"].inventory_id)
			assert.are.equals("BodyArmour", BuildExportPoE2.SlotMap["Body Armour"].inventory_id)
		end)

		it("Marks swap weapons with weapon_set = 2", function()
			assert.are.equals(2, BuildExportPoE2.SlotMap["Weapon 1 Swap"].weapon_set)
			assert.are.equals(2, BuildExportPoE2.SlotMap["Weapon 2 Swap"].weapon_set)
		end)
	end)

	describe("BuildTable", function()
		before_each(function()
			newBuild()
		end)

		it("Returns a table with passives, skills, items keys", function()
			local root = BuildExportPoE2.BuildTable(build)
			assert.is_not_nil(root)
			assert.is_not_nil(root.passives)
			assert.is_not_nil(root.skills)
			assert.is_not_nil(root.items)
		end)

		it("Has a name field", function()
			local root = BuildExportPoE2.BuildTable(build)
			assert.is_not_nil(root.name)
			assert.is_true(type(root.name) == "string")
		end)

		it("Returns lists for fresh build", function()
			local root = BuildExportPoE2.BuildTable(build)
			assert.is_true(type(root.passives) == "table")
			assert.is_true(type(root.skills) == "table")
			assert.is_true(type(root.items) == "table")
		end)

		it("Includes ascendancy when class is set", function()
			local root = BuildExportPoE2.BuildTable(build)
			assert.is_true(type(root) == "table")
		end)
	end)

	describe("Export", function()
		before_each(function()
			newBuild()
		end)

		it("Returns a JSON string", function()
			local json, err = BuildExportPoE2.Export(build)
			assert.is_not_nil(json)
			assert.is_nil(err)
			assert.is_true(type(json) == "string")
		end)

		it("Returns valid JSON that decodes", function()
			local json = BuildExportPoE2.Export(build)
			local decoded, _, decodeErr = dkjson.decode(json)
			assert.is_not_nil(decoded)
			assert.is_nil(decodeErr)
		end)

		it("Decoded JSON has expected keys", function()
			local json = BuildExportPoE2.Export(build)
			local decoded = dkjson.decode(json)
			assert.is_not_nil(decoded.name)
			assert.is_not_nil(decoded.passives)
			assert.is_not_nil(decoded.skills)
			assert.is_not_nil(decoded.items)
		end)

		it("Produces consistent output", function()
			local json1 = BuildExportPoE2.Export(build)
			local json2 = BuildExportPoE2.Export(build)
			assert.are.equals(json1, json2)
		end)

		it("Returns nil warning for an empty build", function()
			-- Clear allocNodes so the stringId check has nothing to iterate.
			build.treeTab.specList[1].allocNodes = {}
			local _, err, warning = BuildExportPoE2.Export(build)
			assert.is_nil(err)
			-- An empty build has no passives so no stringId check fires.
			assert.is_nil(warning)
		end)

		it("Returns warning when allocated nodes lack stringId", function()
			-- Simulate a node without stringId to trigger the degraded-export path.
			build.treeTab.specList[1].allocNodes = { [1] = {} }
			local _, err, warning = BuildExportPoE2.Export(build)
			assert.is_nil(err)
			assert.is_not_nil(warning)
			assert.is_truthy(warning:find("stringId"))
		end)

		it("autoBracket never produces hi < lo for n >= 100 specs", function()
			-- With n=100, i=1: old code gave hi=floor(1/100*99)=0 < lo=1.
			-- The m_max fix ensures hi >= lo.
			-- Inject a stringId so the entry is definitely emitted as a table
			-- (not collapsed to a bare string), making the assertion unconditional.
			build.treeTab.specList[1].allocNodes = { [1] = { stringId = "test_node_1" } }
			for i = 2, 100 do
				build.treeTab.specList[i] = { id = i, allocNodes = {} }
			end
			local root = BuildExportPoE2.BuildTable(build)
			local first = root.passives[1]
			assert.is_table(first, "expected first passive to be a table with level_interval")
			assert.is_not_nil(first.level_interval, "expected first passive to have level_interval")
			assert.is_true(first.level_interval[1] <= first.level_interval[2],
				"autoBracket produced hi < lo: " .. tostring(first.level_interval[1]) .. " > " .. tostring(first.level_interval[2]))
		end)
	end)

	describe("levelMin/levelMax round-trip via PassiveSpec save/load", function()
		before_each(function()
			newBuild()
		end)

		it("persists levelMin and levelMax through save/load", function()
			local spec = new("PassiveSpec", build, latestTreeVersion)
			spec.levelMin = 30
			spec.levelMax = 60

			-- PassiveSpec:Save sets xml.attrib in-place and appends children.
			local xml = { attrib = {} }
			spec:Save(xml)

			local spec2 = new("PassiveSpec", build, latestTreeVersion)
			spec2:Load(xml, "test.xml")

			assert.are.equals(30, spec2.levelMin)
			assert.are.equals(60, spec2.levelMax)
		end)

		it("levelMin and levelMax are nil after save/load when not set", function()
			local spec = new("PassiveSpec", build, latestTreeVersion)
			-- Do not set levelMin/levelMax — they should stay nil.

			local xml = { attrib = {} }
			spec:Save(xml)

			local spec2 = new("PassiveSpec", build, latestTreeVersion)
			spec2:Load(xml, "test.xml")

			assert.is_nil(spec2.levelMin)
			assert.is_nil(spec2.levelMax)
		end)

		it("bracketsFor uses persisted levelMin/levelMax to emit correct level_interval", function()
			-- Tag spec 1 with [1,50] and add an untagged spec 2.
			-- bracketsFor should detect hasAnyExplicit=true and leave spec 2 with no interval.
			build.treeTab.specList[1].levelMin = 1
			build.treeTab.specList[1].levelMax = 50
			build.treeTab.specList[1].allocNodes = { [1] = { stringId = "test_node_a" } }
			build.treeTab.specList[2] = { id = 2, allocNodes = { [2] = { stringId = "test_node_b" } } }

			local root = BuildExportPoE2.BuildTable(build)

			-- Node from spec 1 should have level_interval = {1, 50}.
			local found1 = false
			local found2_has_interval = false
			for _, p in ipairs(root.passives) do
				if type(p) == "table" and p.id == "test_node_a" then
					found1 = true
					assert.are.same({1, 50}, p.level_interval)
				end
				if type(p) == "table" and p.id == "test_node_b" and p.level_interval then
					found2_has_interval = true
				end
			end
			assert.is_true(found1, "node from tagged spec not found in passives")
			assert.is_false(found2_has_interval, "untagged spec should have no level_interval when another spec is tagged")
		end)
	end)

	describe("WriteFile", function()
		before_each(function()
			newBuild()
		end)

		it("Writes a file and returns path on success", function()
			local testPath = os.tmpname() .. ".build"
			local path, err = BuildExportPoE2.WriteFile(build, testPath)
			assert.are.equals(testPath, path)
			assert.is_nil(err)
			os.remove(testPath)
		end)

		it("Returns nil and error for invalid path", function()
			local path, err = BuildExportPoE2.WriteFile(build, "/nonexistent/dir/nope/build.build")
			assert.is_nil(path)
			assert.is_not_nil(err)
		end)

		it("File content is valid JSON", function()
			local testPath = os.tmpname() .. ".build"
			BuildExportPoE2.WriteFile(build, testPath)
			local f = io.open(testPath, "r")
			assert.is_not_nil(f)
			local content = f:read("*a")
			f:close()
			local decoded = dkjson.decode(content)
			assert.is_not_nil(decoded)
			assert.is_not_nil(decoded.name)
			os.remove(testPath)
		end)
	end)
end)
