-- Handle both Factorio and testing environments
if ... ~= "__khaoslib__.list" and ... ~= "list" then
  -- In testing environment, just continue with this file
  local _ = ... -- luacheck: ignore 211
end

-- Load dependencies with shared module loader
local module_loader
if type(data) == "nil" or _G.util ~= nil then
  -- Testing environment
  module_loader = require("module_loader")
else
  -- Factorio environment
  --- @diagnostic disable-next-line: different-requires
  module_loader = require("__khaoslib__.module_loader")
end

local util = module_loader.load_util()

--- Reusable utilities for list manipulation to provide a consistent list manipulation behavior.
---
--- This module provides common operations for working with lists/arrays in Factorio mods,
--- supporting both string-based and function-based comparison logic. All functions that add
--- or modify items use deep copying to prevent unintended reference sharing.
---
--- The comparison system supports two modes:
--- - String comparison: Direct equality check against item values
--- - Function comparison: Custom logic for complex matching (e.g., matching by property)
---
--- Example usage:
--- ```lua
--- local khaoslib_list = require("__khaoslib__.list")
---
--- local my_list = {"apple", "banana"}
---
--- -- Add with duplicate prevention (default)
--- khaoslib_list.add(my_list, "cherry", "cherry")
---
--- -- Add allowing duplicates
--- khaoslib_list.add(my_list, "apple", nil, {allow_duplicates = true})
---
--- -- Check if item exists
--- local has_banana = khaoslib_list.has(my_list, "banana")
---
--- -- Remove item
--- khaoslib_list.remove(my_list, "apple")
---
--- -- Replace item
--- khaoslib_list.replace(my_list, "orange", "banana")
--- ```
---
--- @class khaoslib_list
local khaoslib_list = {}

--- Internal helper to normalize comparison logic for consistent behavior across all list operations.
--- Converts string comparisons to functions, enabling uniform handling throughout the module.
--- @param compare function|string A comparison function or string to match
--- @return function compare_fn The comparison function to use
local function make_compare_fn(compare)
  if type(compare) == "string" then
    return function(item) return item == compare end
  elseif type(compare) == "function" then
    return compare
  else
    error("compare parameter: Expected string or function, got " .. type(compare), 3)
  end
end

--- Internal helper to validate and prepare common parameters for list operations.
--- @param list table|nil The list parameter
--- @param compare function|string The comparison parameter
--- @param empty_return_value any The value to return if list is nil
--- @return table list The validated list (or empty table)
--- @return function|nil compare_fn The normalized comparison function (nil if list was nil)
local function validate_and_prepare(list, compare, empty_return_value)
  if not list then return empty_return_value or {}, nil end
  if not compare then error("compare parameter is required", 3) end

  local compare_fn = make_compare_fn(compare)
  return list, compare_fn
end

--- Internal helper to perform list operations that can work on first match or all matches.
--- @param list table The validated list
--- @param compare_fn function The comparison function
--- @param operation_fn function Function that performs the operation on a single item (i, item) -> should_continue
--- @param all boolean Whether to process all matches or just the first
local function perform_list_operation(list, compare_fn, operation_fn, all)
  if all then
    -- Process all matching items (backwards for removal operations)
    for i = #list, 1, -1 do
      if compare_fn(list[i]) then
        operation_fn(i, list[i])
      end
    end
  else
    -- Process only the first matching item
    for i, item in ipairs(list) do
      if compare_fn(item) then
        operation_fn(i, item)
        break
      end
    end
  end
end

--- Checks if a list contains an item matching a comparison function or string.
---
--- This function searches through the list using the provided comparison logic.
--- For string comparisons, it performs direct equality checks. For function
--- comparisons, it calls the function with each item and returns true if any
--- invocation returns a truthy value.
---
--- ```lua
--- -- String comparison
--- local has_item = khaoslib_list.has({"a", "b", "c"}, "b") -- true
---
--- -- Function comparison
--- local has_item = khaoslib_list.has({{name="iron"}, {name="copper"}}, function(item) return item.name == "iron" end) -- true
--- ```
---
--- @param list table The list to search in (can be nil, returns false)
--- @param compare function|string A comparison function that receives an item and returns boolean, or a string for direct equality comparison
--- @return boolean has_item True if the list contains a matching item, false otherwise
function khaoslib_list.has(list, compare)
  local validated_list, compare_fn = validate_and_prepare(list, compare, false)
  if not compare_fn then return false end

  for _, item in ipairs(validated_list) do
    if compare_fn(item) then
      return true
    end
  end

  return false
end

--- Adds an item to a list, with optional duplicate prevention.
---
--- By default, this function prevents duplicates by checking if an equivalent item
--- already exists in the list. When `allow_duplicates` is true, items are added
--- directly without any duplicate checking. All added items are deep copied to
--- prevent unintended reference sharing.
---
--- ```lua
--- local my_list = {"apple", "banana"}
---
--- -- Add with duplicate prevention (default behavior)
--- khaoslib_list.add(my_list, "cherry", "cherry") -- Adds "cherry" if not already present
---
--- -- Add allowing duplicates
--- khaoslib_list.add(my_list, "apple", nil, {allow_duplicates = true}) -- Always adds "apple"
---
--- -- Function comparison for complex objects
--- local recipes = {{name = "iron-plate"}}
--- khaoslib_list.add(recipes, {name = "copper-plate"}, function(r) return r.name == "copper-plate" end)
--- ```
---
--- @param list table|nil The list to add to (will be created if nil)
--- @param item any The item to add (will be deep copied)
--- @param compare function|string|nil A comparison function that receives an item and returns boolean, or a string for direct equality comparison. Required when allow_duplicates is false, ignored when allow_duplicates is true.
--- @param options table? Options table with the following fields:
---   - `allow_duplicates` (boolean, default false): If true, skips duplicate checking and adds the item directly
--- @return table list The modified list (same reference as input, or new table if input was nil)
function khaoslib_list.add(list, item, compare, options)
  list = list or {}
  options = options or {}
  local allow_duplicates = options.allow_duplicates or false

  if allow_duplicates then
    -- When allowing duplicates, just add the item directly (compare is ignored)
    table.insert(list, util.table.deepcopy(item))
  else
    -- When preventing duplicates, we need a comparison function
    if not compare then error("compare parameter is required when allow_duplicates is false", 2) end

    if not khaoslib_list.has(list, compare) then
      table.insert(list, util.table.deepcopy(item))
    end
  end

  return list
end

--- Removes matching items from a list.
---
--- By default, removes only the first item that matches the comparison criteria.
--- When `all` is true, removes all matching items in a single call.
---
--- ```lua
--- local my_list = {"apple", "banana", "apple", "cherry"}
---
--- -- Remove first matching item (default behavior)
--- khaoslib_list.remove(my_list, "apple") -- Removes first "apple", list becomes {"banana", "apple", "cherry"}
---
--- -- Remove all matching items
--- khaoslib_list.remove(my_list, "apple", {all = true}) -- Removes all "apple", list becomes {"banana", "cherry"}
---
--- -- Remove by function comparison
--- local recipes = {{name = "iron-plate"}, {name = "copper-plate"}}
--- khaoslib_list.remove(recipes, function(r) return r.name == "iron-plate" end) -- Removes iron-plate recipe
--- ```
---
--- @param list table|nil The list to remove from (returns empty table if nil)
--- @param compare function|string A comparison function that receives an item and returns boolean, or a string for direct equality comparison
--- @param options table? Options table with the following fields:
---   - `all` (boolean, default false): If true, removes all matching items instead of just the first
--- @return table list The modified list (same reference as input, or empty table if input was nil)
function khaoslib_list.remove(list, compare, options)
  local validated_list, compare_fn = validate_and_prepare(list, compare, {})
  if not compare_fn then return validated_list end

  options = options or {}
  local remove_all = options.all or false

  perform_list_operation(validated_list, compare_fn, function(i, item) --luacheck: ignore 212
    table.remove(validated_list, i)
  end, remove_all)

  return validated_list
end

--- Replaces matching items in a list with a new item.
---
--- By default, replaces only the first item that matches the comparison criteria.
--- When `all` is true, replaces all matching items in a single call. The new item
--- is deep copied to prevent unintended reference sharing.
---
--- ```lua
--- local my_list = {"apple", "banana", "apple", "cherry"}
---
--- -- Replace first matching item (default behavior)
--- khaoslib_list.replace(my_list, "orange", "apple") -- Replaces first "apple", list becomes {"orange", "banana", "apple", "cherry"}
---
--- -- Replace all matching items
--- khaoslib_list.replace(my_list, "orange", "apple", {all = true}) -- Replaces all "apple", list becomes {"orange", "banana", "orange", "cherry"}
---
--- -- Replace by function comparison
--- local recipes = {{name = "iron-plate", amount = 1}, {name = "copper-plate", amount = 1}}
--- khaoslib_list.replace(recipes, {name = "iron-plate", amount = 2}, function(r) return r.name == "iron-plate" end)
--- ```
---
--- @param list table|nil The list to modify (returns empty table if nil)
--- @param new_item any The new item to replace with (will be deep copied)
--- @param compare function|string A comparison function that receives an item and returns boolean, or a string for direct equality comparison
--- @param options table? Options table with the following fields:
---   - `all` (boolean, default false): If true, replaces all matching items instead of just the first
--- @return table list The modified list (same reference as input, or empty table if input was nil)
function khaoslib_list.replace(list, new_item, compare, options)
  local validated_list, compare_fn = validate_and_prepare(list, compare, {})
  if not compare_fn then return validated_list end

  options = options or {}
  local replace_all = options.all or false

  perform_list_operation(validated_list, compare_fn, function(i, item) --luacheck: ignore 212
    validated_list[i] = util.table.deepcopy(new_item)
  end, replace_all)

  return validated_list
end

return khaoslib_list
