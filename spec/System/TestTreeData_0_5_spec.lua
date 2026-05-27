describe("TreeData 0.5", function()
	it("loads the 0_5 tree version successfully", function()
		local tree = new("PassiveTree", "0_5")
		assert.is_not_nil(tree, "Tree should load without error")
		assert.are.equals("Default", tree.tree)
	end)

	it("has the expected node counts", function()
		local tree = new("PassiveTree", "0_5")
		local nodeCount = 0
		for _ in pairs(tree.nodes) do
			nodeCount = nodeCount + 1
		end
		-- 0.5 has 4863 nodes (183 new, 21 removed from 0.4's 4701)
		assert.are.equals(4863, nodeCount)
	end)

	it("has 12 base classes", function()
		local tree = new("PassiveTree", "0_5")
		local classCount = 0
		for _ in pairs(tree.classes) do
			classCount = classCount + 1
		end
		-- 12 base classes (Marauder, Witch, Ranger, Duelist, Shadow, Templar,
		-- Warrior, Sorceress, Huntress, Mercenary, Monk, Druid)
		assert.are.equals(12, classCount)
	end)

	it("has new ascendancies Spirit Walker, Martial Artist, and Amazon", function()
		local tree = new("PassiveTree", "0_5")
		assert.is_not_nil(tree.ascendNameMap["Spirit Walker"], "Spirit Walker should exist")
		assert.is_not_nil(tree.ascendNameMap["Martial Artist"], "Martial Artist should exist")
		assert.is_not_nil(tree.ascendNameMap["Amazon"], "Amazon should exist")
	end)

	it("has existing ascendancies Deadeye and Pathfinder", function()
		local tree = new("PassiveTree", "0_5")
		assert.is_not_nil(tree.ascendNameMap["Deadeye"], "Deadeye should exist")
		assert.is_not_nil(tree.ascendNameMap["Pathfinder"], "Pathfinder should exist")
	end)

	it("has the correct number of jewel sockets", function()
		local tree = new("PassiveTree", "0_5")
		local socketCount = 0
		for _ in pairs(tree.sockets) do
			socketCount = socketCount + 1
		end
		-- 0.5 has 18 jewel sockets (up from 12 in 0.4)
		assert.are.equals(18, socketCount)
	end)

	it("all nodes have valid connections to existing nodes", function()
		local tree = new("PassiveTree", "0_5")
		local brokenConnections = 0
		local totalConnections = 0
		for _, node in pairs(tree.nodes) do
			if node.linkedId then
				for _, linkedNodeId in ipairs(node.linkedId) do
					totalConnections = totalConnections + 1
					if not tree.nodes[linkedNodeId] then
						brokenConnections = brokenConnections + 1
					end
				end
			end
		end
		assert.are.equals(0, brokenConnections, "All connections should point to existing nodes")
		assert.is_true(totalConnections > 5000, "Should have many connections")
	end)

	it("has class start nodes for all 6 class pairs", function()
		local tree = new("PassiveTree", "0_5")
		local classStartCount = 0
		for _, node in pairs(tree.nodes) do
			if node.type == "ClassStart" then
				classStartCount = classStartCount + 1
			end
		end
		assert.are.equals(6, classStartCount, "Should have 6 class start nodes")
	end)

	it("has new notable nodes not in 0.4", function()
		local tree = new("PassiveTree", "0_5")
		-- Check for nodes that should be new in 0.5
		-- These are notable node names that were added
		assert.is_not_nil(tree.notableMap["fortified aegis"], "Fortified Aegis notable should exist")
	end)

	it("processes stats on nodes correctly", function()
		local tree = new("PassiveTree", "0_5")
		-- Verify a known existing node
		local shockChanceNode = tree.nodes[4]
		assert.is_not_nil(shockChanceNode, "Node 4 should exist")
		assert.are.equals("Shock Chance", shockChanceNode.dn)
		assert.is_not_nil(shockChanceNode.sd, "Node should have stats")
	end)

	it("handles ascendancy nodes properly", function()
		local tree = new("PassiveTree", "0_5")
		-- Find a known ascendancy notable
		local gatheringWinds = tree.nodes[30]
		assert.is_not_nil(gatheringWinds, "Node 30 (Gathering Winds) should exist")
		assert.are.equals("Gathering Winds", gatheringWinds.dn)
		assert.are.equals("Deadeye", gatheringWinds.ascendancyName)
		assert.are.equals("Notable", gatheringWinds.type)
	end)
end)
