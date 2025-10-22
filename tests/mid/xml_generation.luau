--[[
	XML Generation Test - Validates core XML serialization functionality

	Tests the XML generation pipeline including instance serialization,
	property handling, and document generation.

	@author Aspecter
	@version 1.0.0
]]

local Types = require("@types")
local XML = require("@core/xml")
local Traversal = require("@core/traversal")

-- Test counter
local tests_passed = 0
local tests_failed = 0

--[=[
	Helper function to assert a condition
	@param condition boolean -- Condition to check
	@param message string -- Error message if false
]=]
local function assert_true(condition: boolean, message: string)
	if not condition then
		tests_failed += 1
		print(`[FAIL] {message}`)
		return false
	end
	tests_passed += 1
	return true
end

--[=[
	Test 1: Instance serialization
]=]
local function test_instance_serialization()
	print("\n[TEST] Instance Serialization")

	local part = Instance.new("Part")
	part.Name = "TestPart"
	part.Size = Vector3.new(1, 2, 3)
	part.BrickColor = BrickColor.new("Bright red")

	local serialized = XML.Instance.serialize(part, {
		mode = "full",
		ignoreProperties = nil,
		ignoreDefaultProperties = false,
		ignoreSpecialProperties = false,
	})

	assert_true(serialized.className == "Part", "Instance class name correct")
	assert_true(serialized.referent:match("^RBX"), "Referent format correct")
	assert_true(#serialized.properties > 0, "Properties collected")

	part:Destroy()
end

--[=[
	Test 2: Property type mapping
]=]
local function test_property_types()
	print("\n[TEST] Property Type Mapping")

	local folder = Instance.new("Folder")
	folder.Name = "TestFolder"

	local serialized = XML.Instance.serialize(folder, {
		mode = "full",
		ignoreProperties = nil,
		ignoreDefaultProperties = false,
		ignoreSpecialProperties = false,
	})

	-- Check that properties are present
	assert_true(#serialized.properties > 0, "Folder has properties")

	-- Verify XML structure
	local xml = XML.Instance.toXML(serialized, 0)
	assert_true(xml:match("<Item"), "XML starts with Item tag")
	assert_true(xml:match("</Item>"), "XML ends with Item tag")
	assert_true(xml:match('class="Folder"'), "Class attribute present")
	assert_true(xml:match('referent="RBX'), "Referent attribute present")

	folder:Destroy()
end

--[=[
	Test 3: Document generation
]=]
local function test_document_generation()
	print("\n[TEST] Document Generation")

	-- Create a simple test structure
	local function generateTestDoc()
		return XML.Document.generate({
			mode = "full",
			object = nil,
			isModel = false,
			nilInstances = false,
			extraInstances = nil,
			ignoreNotArchivable = false,
			removePlayerCharacters = false,
			ignoreProperties = nil,
			ignoreDefaultProperties = false,
			ignoreSpecialProperties = false,
		})
	end

	local promise = generateTestDoc()
	if promise then
		promise:andThen(function(result)
			assert_true(result.success, "Document generation successful")
			if result.success and result.data then
				assert_true(#result.data > 0, "Document has content")
				assert_true(result.data:match("<%?xml"), "XML declaration present")
				assert_true(result.data:match("<roblox"), "Roblox root element present")
				assert_true(result.data:match("</roblox>"), "Roblox root closes")
			end
		end):catch(function(err)
			tests_failed += 1
			print(`[FAIL] Document generation error: {tostring(err)}`)
		end)
	end
end

--[=[
	Test 4: Instance traversal
]=]
local function test_traversal()
	print("\n[TEST] Instance Traversal")

	local folder = Instance.new("Folder")
	folder.Name = "TestFolder"

	local part1 = Instance.new("Part")
	part1.Name = "Part1"
	part1.Parent = folder

	local part2 = Instance.new("Part")
	part2.Name = "Part2"
	part2.Parent = folder

	-- Traverse the test structure
	local instances = Traversal.traverse({
		mode = "full",
		object = folder,
		nilInstances = false,
		extraInstances = nil,
		ignoreNotArchivable = false,
		removePlayerCharacters = false,
	})

	assert_true(#instances >= 3, "All instances traversed")

	folder:Destroy()
end

--[=[
	Test 5: Property filtering
]=]
local function test_property_filtering()
	print("\n[TEST] Property Filtering")

	local part = Instance.new("Part")
	part.Name = "TestPart"

	-- Full mode
	local fullMode = XML.Instance.serialize(part, {
		mode = "full",
		ignoreProperties = { "Name" },
		ignoreDefaultProperties = false,
		ignoreSpecialProperties = false,
	})

	-- Check that Name is not in filtered properties
	local hasName = false
	for _, prop in fullMode.properties do
		if prop.name == "Name" then
			hasName = true
			break
		end
	end

	assert_true(not hasName, "Ignored properties filtered correctly")

	part:Destroy()
end

--[=[
	Run all tests
]=]
local function run_all_tests()
	print("================================")
	print("XML Generation Test Suite")
	print("================================")

	test_instance_serialization()
	test_property_types()
	test_document_generation()
	test_traversal()
	test_property_filtering()

	print("\n================================")
	print(`Tests Passed: {tests_passed}`)
	print(`Tests Failed: {tests_failed}`)
	print("================================")

	return tests_failed == 0
end

-- Run tests if this module is executed directly
if not script or script == nil then
	run_all_tests()
end

return {
	run = run_all_tests,
}
