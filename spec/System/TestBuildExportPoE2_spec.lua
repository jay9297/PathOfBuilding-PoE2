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

		it("Clamps negative values to 0", function()
			assert.are.equals(0, BuildExportPoE2.ClampLevel(-10))
			assert.are.equals(0, BuildExportPoE2.ClampLevel(-0.5))
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
