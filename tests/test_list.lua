-- Test file for khaoslib list module
-- Handle both running from tests/ directory and from workspace root
package.path = "tests/?.lua;" .. package.path .. ";?.lua"
local luaunit = require('luaunit')
local test_utils = require('test_utils')

local khaoslib_list = test_utils.load_module('list')

-- Test suite
TestListModule = {}

function TestListModule:setUp()
  -- Reset any state if needed
end

--#region has() function tests

function TestListModule:test_has_with_string_comparison()
  -- Test basic string comparison
  local list = {"apple", "banana", "cherry"}

  luaunit.assertTrue(khaoslib_list.has(list, "banana"))
  luaunit.assertFalse(khaoslib_list.has(list, "orange"))
end

function TestListModule:test_has_with_function_comparison()
  -- Test function comparison
  local list = {
    {name = "iron-plate", amount = 1},
    {name = "copper-plate", amount = 2}
  }

  local has_iron = khaoslib_list.has(list, function(item)
    return item.name == "iron-plate"
  end)

  local has_steel = khaoslib_list.has(list, function(item)
    return item.name == "steel-plate"
  end)

  luaunit.assertTrue(has_iron)
  luaunit.assertFalse(has_steel)
end

function TestListModule:test_has_with_nil_list()
  -- Test with nil list should return false
  luaunit.assertFalse(khaoslib_list.has(nil, "anything"))
end

function TestListModule:test_has_with_empty_list()
  -- Test with empty list
  luaunit.assertFalse(khaoslib_list.has({}, "anything"))
end

function TestListModule:test_has_invalid_compare_parameter()
  -- Test error handling for invalid compare parameter
  local list = {"a", "b", "c"}

  luaunit.assertErrorMsgContains("compare parameter: Expected string or function", function()
    khaoslib_list.has(list, 123)
  end)
end

--#endregion

--#region add() function tests

function TestListModule:test_add_with_duplicate_prevention()
  -- Test default behavior (no duplicates)
  local list = {"apple", "banana"}

  -- Add new item
  khaoslib_list.add(list, "cherry", "cherry")
  luaunit.assertEquals(#list, 3)
  luaunit.assertEquals(list[3], "cherry")

  -- Try to add duplicate
  khaoslib_list.add(list, "apple", "apple")
  luaunit.assertEquals(#list, 3) -- Should not change
end

function TestListModule:test_add_with_allow_duplicates()
  -- Test allowing duplicates
  local list = {"apple", "banana"}

  khaoslib_list.add(list, "apple", nil, {allow_duplicates = true})
  luaunit.assertEquals(#list, 3)
  luaunit.assertEquals(list[3], "apple")
end

function TestListModule:test_add_with_function_comparison()
  -- Test function comparison for complex objects
  local list = {{name = "iron-plate", amount = 1}}

  -- Add new item
  khaoslib_list.add(list, {name = "copper-plate", amount = 2}, function(item)
    return item.name == "copper-plate"
  end)
  luaunit.assertEquals(#list, 2)

  -- Try to add duplicate
  khaoslib_list.add(list, {name = "iron-plate", amount = 5}, function(item)
    return item.name == "iron-plate"
  end)
  luaunit.assertEquals(#list, 2) -- Should not change
  luaunit.assertEquals(list[1].amount, 1) -- Original should be unchanged
end

function TestListModule:test_add_to_nil_list()
  -- Test adding to nil list creates new list
  local list = nil
  list = khaoslib_list.add(list, "item", "item")

  luaunit.assertNotNil(list)
  luaunit.assertEquals(#list, 1)
  luaunit.assertEquals(list[1], "item")
end

function TestListModule:test_add_deep_copy()
  -- Test that added items are deep copied
  local original_item = {name = "test", nested = {value = 42}}
  local list = {}

  khaoslib_list.add(list, original_item, function(item) return item.name == "test" end)

  -- Modify original
  original_item.nested.value = 100

  -- List item should be unchanged
  luaunit.assertEquals(list[1].nested.value, 42)
end

function TestListModule:test_add_requires_compare_when_no_duplicates()
  -- Test error when compare is nil and allow_duplicates is false
  local list = {"item"}

  luaunit.assertErrorMsgContains("compare parameter is required", function()
    khaoslib_list.add(list, "new_item", nil)
  end)
end

--#endregion

--#region remove() function tests

function TestListModule:test_remove_first_match()
  -- Test removing first matching item (default behavior)
  local list = {"apple", "banana", "apple", "cherry"}

  khaoslib_list.remove(list, "apple")

  luaunit.assertEquals(#list, 3)
  luaunit.assertEquals(list[1], "banana")
  luaunit.assertEquals(list[2], "apple") -- Second apple should remain
  luaunit.assertEquals(list[3], "cherry")
end

function TestListModule:test_remove_all_matches()
  -- Test removing all matching items
  local list = {"apple", "banana", "apple", "cherry", "apple"}

  khaoslib_list.remove(list, "apple", {all = true})

  luaunit.assertEquals(#list, 2)
  luaunit.assertEquals(list[1], "banana")
  luaunit.assertEquals(list[2], "cherry")
end

function TestListModule:test_remove_with_function_comparison()
  -- Test removing with function comparison
  local list = {
    {name = "iron-plate", amount = 1},
    {name = "copper-plate", amount = 2},
    {name = "iron-plate", amount = 3}
  }

  khaoslib_list.remove(list, function(item)
    return item.name == "iron-plate"
  end)

  luaunit.assertEquals(#list, 2)
  luaunit.assertEquals(list[1].name, "copper-plate")
  luaunit.assertEquals(list[2].name, "iron-plate") -- Second iron-plate remains
end

function TestListModule:test_remove_all_with_function_comparison()
  -- Test removing all with function comparison
  local list = {
    {name = "iron-plate", amount = 1},
    {name = "copper-plate", amount = 2},
    {name = "iron-plate", amount = 3}
  }

  khaoslib_list.remove(list, function(item)
    return item.name == "iron-plate"
  end, {all = true})

  luaunit.assertEquals(#list, 1)
  luaunit.assertEquals(list[1].name, "copper-plate")
end

function TestListModule:test_remove_nonexistent_item()
  -- Test removing item that doesn't exist
  local list = {"apple", "banana"}
  local original_length = #list

  khaoslib_list.remove(list, "orange")

  luaunit.assertEquals(#list, original_length)
end

function TestListModule:test_remove_from_nil_list()
  -- Test removing from nil list returns empty table
  local result = khaoslib_list.remove(nil, "anything")

  luaunit.assertNotNil(result)
  luaunit.assertEquals(#result, 0)
end

function TestListModule:test_remove_from_empty_list()
  -- Test removing from empty list
  local list = {}
  khaoslib_list.remove(list, "anything")

  luaunit.assertEquals(#list, 0)
end

--#endregion

--#region replace() function tests

function TestListModule:test_replace_first_match()
  -- Test replacing first matching item (default behavior)
  local list = {"apple", "banana", "apple", "cherry"}

  khaoslib_list.replace(list, "orange", "apple")

  luaunit.assertEquals(#list, 4)
  luaunit.assertEquals(list[1], "orange")
  luaunit.assertEquals(list[2], "banana")
  luaunit.assertEquals(list[3], "apple") -- Second apple should remain
  luaunit.assertEquals(list[4], "cherry")
end

function TestListModule:test_replace_all_matches()
  -- Test replacing all matching items
  local list = {"apple", "banana", "apple", "cherry", "apple"}

  khaoslib_list.replace(list, "orange", "apple", {all = true})

  luaunit.assertEquals(#list, 5)
  luaunit.assertEquals(list[1], "orange")
  luaunit.assertEquals(list[2], "banana")
  luaunit.assertEquals(list[3], "orange")
  luaunit.assertEquals(list[4], "cherry")
  luaunit.assertEquals(list[5], "orange")
end

function TestListModule:test_replace_with_function_comparison()
  -- Test replacing with function comparison
  local list = {
    {name = "iron-plate", amount = 1},
    {name = "copper-plate", amount = 2},
    {name = "iron-plate", amount = 3}
  }

  khaoslib_list.replace(list, {name = "steel-plate", amount = 1}, function(item)
    return item.name == "iron-plate"
  end)

  luaunit.assertEquals(#list, 3)
  luaunit.assertEquals(list[1].name, "steel-plate")
  luaunit.assertEquals(list[2].name, "copper-plate")
  luaunit.assertEquals(list[3].name, "iron-plate") -- Second iron-plate remains
end

function TestListModule:test_replace_all_with_function_comparison()
  -- Test replacing all with function comparison
  local list = {
    {name = "iron-plate", amount = 1},
    {name = "copper-plate", amount = 2},
    {name = "iron-plate", amount = 3}
  }

  khaoslib_list.replace(list, {name = "steel-plate", amount = 1}, function(item)
    return item.name == "iron-plate"
  end, {all = true})

  luaunit.assertEquals(#list, 3)
  luaunit.assertEquals(list[1].name, "steel-plate")
  luaunit.assertEquals(list[2].name, "copper-plate")
  luaunit.assertEquals(list[3].name, "steel-plate")
end

function TestListModule:test_replace_deep_copy()
  -- Test that replaced items are deep copied
  local original_item = {name = "test", nested = {value = 42}}
  local list = {{name = "old", nested = {value = 1}}}

  khaoslib_list.replace(list, original_item, function(item) return item.name == "old" end)

  -- Modify original
  original_item.nested.value = 100

  -- List item should be unchanged
  luaunit.assertEquals(list[1].nested.value, 42)
end

function TestListModule:test_replace_nonexistent_item()
  -- Test replacing item that doesn't exist
  local list = {"apple", "banana"}
  local original_list = util.table.deepcopy(list)

  khaoslib_list.replace(list, "orange", "cherry")

  luaunit.assertEquals(list, original_list)
end

function TestListModule:test_replace_in_nil_list()
  -- Test replacing in nil list returns empty table
  local result = khaoslib_list.replace(nil, "new_item", "old_item")

  luaunit.assertNotNil(result)
  luaunit.assertEquals(#result, 0)
end

--#endregion

--#region Edge cases and error handling

function TestListModule:test_complex_nested_objects()
  -- Test with complex nested objects
  local list = {
    {
      type = "recipe",
      name = "iron-plate",
      ingredients = {
        {type = "item", name = "iron-ore", amount = 1}
      },
      results = {
        {type = "item", name = "iron-plate", amount = 1}
      }
    }
  }

  -- Test has with complex comparison
  local has_recipe = khaoslib_list.has(list, function(recipe)
    return recipe.name == "iron-plate" and recipe.ingredients[1].name == "iron-ore"
  end)
  luaunit.assertTrue(has_recipe)

  -- Test add with complex comparison
  local new_recipe = {
    type = "recipe",
    name = "copper-plate",
    ingredients = {{type = "item", name = "copper-ore", amount = 1}},
    results = {{type = "item", name = "copper-plate", amount = 1}}
  }

  khaoslib_list.add(list, new_recipe, function(recipe)
    return recipe.name == "copper-plate"
  end)

  luaunit.assertEquals(#list, 2)
  luaunit.assertEquals(list[2].name, "copper-plate")
end

function TestListModule:test_comparison_function_error_handling()
  -- Test that comparison functions that error are handled properly
  local list = {"a", "b", "c"}

  luaunit.assertError(function()
    khaoslib_list.has(list, function(item)
      error("Intentional error in comparison function")
    end)
  end)
end

function TestListModule:test_empty_string_and_nil_values()
  -- Test handling of empty strings and nil values
  local list = {"", "actual_value", ""}

  luaunit.assertTrue(khaoslib_list.has(list, ""))
  luaunit.assertFalse(khaoslib_list.has(list, function(item) return item == nil end))

  -- Remove empty strings
  khaoslib_list.remove(list, "", {all = true})
  luaunit.assertEquals(#list, 1) -- only "actual_value" remains
  luaunit.assertEquals(list[1], "actual_value")
end

--#endregion

--#region Integration tests

function TestListModule:test_chained_operations()
  -- Test multiple operations on the same list
  local list = {"apple", "banana", "cherry", "apple"}

  -- Remove all apples, then add orange, then replace banana with grape
  khaoslib_list.remove(list, "apple", {all = true})
  khaoslib_list.add(list, "orange", "orange")
  khaoslib_list.replace(list, "grape", "banana")

  luaunit.assertEquals(#list, 3)
  luaunit.assertEquals(list[1], "grape")
  luaunit.assertEquals(list[2], "cherry")
  luaunit.assertEquals(list[3], "orange")
end

function TestListModule:test_list_as_return_value_consistency()
  -- Test that all functions return the list for chaining
  local list = {"item"}

  local result1 = khaoslib_list.add(list, "new", "new")
  local result2 = khaoslib_list.remove(list, "item")
  local result3 = khaoslib_list.replace(list, "replaced", "new")

  luaunit.assertEquals(result1, list)
  luaunit.assertEquals(result2, list)
  luaunit.assertEquals(result3, list)
end

--#endregion

-- Run the tests
os.exit(luaunit.LuaUnit.run())