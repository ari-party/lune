local roblox = require("@lune/roblox") :: any
local Instance = roblox.Instance

-- Basic ByteSize function tests
do
	local part = Instance.new("Part")

	local size = roblox.getByteSize(part)
	assert(size ~= nil, "getByteSize should return a value for Part")
	assert(type(size) == "number", "getByteSize should return a number")
	assert(size > 0, "getByteSize should return a value greater than 0")

	local folder = Instance.new("Folder")
	local script = Instance.new("Script")
	local stringValue = Instance.new("StringValue")

	assert(roblox.getByteSize(folder) > 0, "Folder should have ByteSize > 0")
	assert(roblox.getByteSize(script) > 0, "Script should have ByteSize > 0")
	assert(roblox.getByteSize(stringValue) > 0, "StringValue should have ByteSize > 0")
end

-- Parent-child relationship tests
do
	local model = Instance.new("Model")
	model.Name = "TestModel"

	local childPart = Instance.new("Part")
	childPart.Name = "ChildPart"
	childPart.Parent = model

	local childScript = Instance.new("Script")
	childScript.Name = "ChildScript"
	childScript.Parent = model

	local modelSize = roblox.getByteSize(model)
	local childPartSize = roblox.getByteSize(childPart)
	local childScriptSize = roblox.getByteSize(childScript)

	assert(modelSize > childPartSize, "Model size should include children")
	assert(modelSize > childScriptSize, "Model size should include children")
end

-- Complex vs simple instance comparison
do
	local complexPart = Instance.new("Part")
	complexPart.Name = "ComplexPart"
	complexPart.Position = roblox.Vector3.new(10, 20, 30)
	complexPart.Size = roblox.Vector3.new(5, 10, 15)
	complexPart.BrickColor = roblox.BrickColor.new("Really blue")
	complexPart.Material = roblox.Enum.Material.Neon
	complexPart.Anchored = true
	complexPart.CanCollide = false

	local simplePart = Instance.new("Part")
	simplePart.Name = "SimplePart"

	assert(
		roblox.getByteSize(complexPart) > roblox.getByteSize(simplePart),
		"Complex part should have larger ByteSize"
	)
end

-- Attributes comparison
do
	local partWithAttributes = Instance.new("Part")
	partWithAttributes.Name = "PartWithAttributes"
	partWithAttributes:SetAttribute("CustomAttribute", "CustomValue")
	partWithAttributes:SetAttribute("NumberAttribute", 42)
	partWithAttributes:SetAttribute("BooleanAttribute", true)

	local partWithoutAttributes = Instance.new("Part")
	partWithoutAttributes.Name = "PartWithoutAttributes"

	assert(
		roblox.getByteSize(partWithAttributes) > roblox.getByteSize(partWithoutAttributes),
		"Part with attributes should have larger ByteSize"
	)
end

-- Tags comparison
do
	local partWithTags = Instance.new("Part")
	partWithTags.Name = "PartWithTags"
	partWithTags:AddTag("Tag1")
	partWithTags:AddTag("Tag2")
	partWithTags:AddTag("Tag3")

	local partWithoutTags = Instance.new("Part")
	partWithoutTags.Name = "PartWithoutTags"

	assert(
		roblox.getByteSize(partWithTags) > roblox.getByteSize(partWithoutTags),
		"Part with tags should have larger ByteSize"
	)
end

-- Consistency test
do
	local testPart = Instance.new("Part")
	testPart.Name = "TestPart"

	local size1 = roblox.getByteSize(testPart)
	local size2 = roblox.getByteSize(testPart)

	assert(size1 == size2, "getByteSize should be consistent for the same instance")
end

-- Multiple instance types test
do
	local instanceTypes = {
		"Part",
		"Folder",
		"Script",
		"LocalScript",
		"StringValue",
		"NumberValue",
		"BoolValue",
		"ObjectValue",
		"Model",
		"Decal",
		"Texture",
		"Sound",
		"Animation",
		"AnimationTrack",
		"Humanoid",
		"HumanoidRootPart",
	}

	for _, className in ipairs(instanceTypes) do
		local success, instance = pcall(function()
			return Instance.new(className)
		end)

		if success then
			local success2, size = pcall(function()
				return roblox.getByteSize(instance)
			end)

			assert(success2, "getByteSize should work for " .. className)
			assert(type(size) == "number", "getByteSize should return a number for " .. className)
			assert(size > 0, "getByteSize should return a value > 0 for " .. className)
		end
	end
end

-- Nested hierarchy test
do
	local root = Instance.new("Folder")
	root.Name = "Root"

	local level1 = Instance.new("Folder")
	level1.Name = "Level1"
	level1.Parent = root

	local level2 = Instance.new("Folder")
	level2.Name = "Level2"
	level2.Parent = level1

	local level3 = Instance.new("Part")
	level3.Name = "Level3"
	level3.Parent = level2

	local rootSize = roblox.getByteSize(root)
	local level1Size = roblox.getByteSize(level1)
	local level2Size = roblox.getByteSize(level2)
	local level3Size = roblox.getByteSize(level3)

	assert(rootSize > level1Size, "Root size should include all descendants")
	assert(level1Size > level2Size, "Level1 size should include its descendants")
	assert(level2Size > level3Size, "Level2 size should include its descendants")
end

-- Empty instances test
do
	local emptyFolder = Instance.new("Folder")
	local emptyPart = Instance.new("Part")

	assert(roblox.getByteSize(emptyFolder) > 0, "Empty folder should have ByteSize > 0")
	assert(roblox.getByteSize(emptyPart) > 0, "Empty part should have ByteSize > 0")
end

-- Long name test
do
	local longName = string.rep("A", 1000)
	local partWithLongName = Instance.new("Part")
	partWithLongName.Name = longName

	local emptyPart = Instance.new("Part")

	assert(roblox.getByteSize(partWithLongName) > 0, "Part with long name should have ByteSize > 0")
	assert(
		roblox.getByteSize(partWithLongName) > roblox.getByteSize(emptyPart),
		"Part with long name should have larger ByteSize"
	)
end

-- Many attributes test
do
	local partWithManyAttributes = Instance.new("Part")
	for i = 1, 100 do
		partWithManyAttributes:SetAttribute("Attribute" .. i, "Value" .. i)
	end

	local emptyPart = Instance.new("Part")

	assert(
		roblox.getByteSize(partWithManyAttributes) > 0,
		"Part with many attributes should have ByteSize > 0"
	)
	assert(
		roblox.getByteSize(partWithManyAttributes) > roblox.getByteSize(emptyPart),
		"Part with many attributes should have larger ByteSize"
	)
end

-- Many tags test
do
	local partWithManyTags = Instance.new("Part")
	for i = 1, 50 do
		partWithManyTags:AddTag("Tag" .. i)
	end

	local emptyPart = Instance.new("Part")

	assert(roblox.getByteSize(partWithManyTags) > 0, "Part with many tags should have ByteSize > 0")
	assert(
		roblox.getByteSize(partWithManyTags) > roblox.getByteSize(emptyPart),
		"Part with many tags should have larger ByteSize"
	)
end

-- Deep nesting test
do
	local function createDeepNest(depth)
		local current = Instance.new("Folder")
		current.Name = "Level" .. depth

		if depth > 1 then
			local child = createDeepNest(depth - 1)
			child.Parent = current
		end

		return current
	end

	local deepNest = createDeepNest(10)
	assert(roblox.getByteSize(deepNest) > 0, "Deeply nested instance should have ByteSize > 0")
end

-- Circular reference test
do
	local circular1 = Instance.new("Folder")
	local circular2 = Instance.new("Folder")

	local objValue1 = Instance.new("ObjectValue")
	objValue1.Name = "CircularRef1"
	objValue1.Value = circular2
	objValue1.Parent = circular1

	local objValue2 = Instance.new("ObjectValue")
	objValue2.Name = "CircularRef2"
	objValue2.Value = circular1
	objValue2.Parent = circular2

	local success, size = pcall(function()
		return roblox.getByteSize(circular1)
	end)

	assert(success, "Circular reference should not cause infinite loop")
	assert(type(size) == "number", "Circular reference should return valid ByteSize")
	assert(size > 0, "Circular reference should have ByteSize > 0")
end

-- Large string test
do
	local partWithLargeString = Instance.new("Part")
	local largeString =
		string.rep("This is a very long string that will take up many bytes when serialized. ", 100)
	partWithLargeString:SetAttribute("LargeString", largeString)

	local emptyPart = Instance.new("Part")

	assert(
		roblox.getByteSize(partWithLargeString) > 0,
		"Part with large string should have ByteSize > 0"
	)
	assert(
		roblox.getByteSize(partWithLargeString) > roblox.getByteSize(emptyPart),
		"Part with large string should have larger ByteSize"
	)
end

-- Extreme numbers test
do
	local partWithExtremeNumbers = Instance.new("Part")
	partWithExtremeNumbers:SetAttribute("VeryLargeNumber", 1e308)
	partWithExtremeNumbers:SetAttribute("VerySmallNumber", 1e-308)
	partWithExtremeNumbers:SetAttribute("NegativeInfinity", -math.huge)
	partWithExtremeNumbers:SetAttribute("PositiveInfinity", math.huge)

	assert(
		roblox.getByteSize(partWithExtremeNumbers) > 0,
		"Part with extreme numbers should have ByteSize > 0"
	)
end

-- Special characters test
do
	local partWithSpecialChars = Instance.new("Part")
	partWithSpecialChars.Name = "Part with spaces and special chars: !@#$%^&*()"
	partWithSpecialChars:SetAttribute("SpecialValue", 'Value with \n newlines \t tabs and "quotes"')

	assert(
		roblox.getByteSize(partWithSpecialChars) > 0,
		"Part with special characters should have ByteSize > 0"
	)
end

-- Modification test
do
	local part = Instance.new("Part")
	local originalSize = roblox.getByteSize(part)

	part.Name = "ModifiedPart"
	part:SetAttribute("NewAttribute", "NewValue")
	part:AddTag("NewTag")

	local modifiedSize = roblox.getByteSize(part)

	assert(modifiedSize > originalSize, "Modified part should have larger ByteSize")
	assert(modifiedSize > 0, "Modified part should have ByteSize > 0")
end

-- Multiple access consistency test
do
	local testPart = Instance.new("Part")
	local sizes = {}

	for i = 1, 10 do
		sizes[i] = roblox.getByteSize(testPart)
	end

	for i = 2, 10 do
		assert(sizes[i] == sizes[1], "getByteSize should be consistent across multiple accesses")
	end
end

-- Clone test
do
	local originalPart = Instance.new("Part")
	originalPart.Name = "OriginalPart"
	originalPart:SetAttribute("TestAttribute", "TestValue")

	local clonedPart = originalPart:Clone()

	assert(roblox.getByteSize(originalPart) > 0, "Original part should have ByteSize > 0")
	assert(roblox.getByteSize(clonedPart) > 0, "Cloned part should have ByteSize > 0")
	assert(
		roblox.getByteSize(originalPart) == roblox.getByteSize(clonedPart),
		"Cloned part should have same ByteSize as original"
	)
end
