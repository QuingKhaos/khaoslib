--- Reusable utilities for list manipulation to provide a consistent list manipulation behavior.
---
--- This module provides common operations for working with lists/arrays in Factorio mods,
--- supporting both string-based and function-based comparison logic. All functions that add
--- or modify items use deep copying of the input item to prevent unintended reference sharing.
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
--- @generic T
--- @param compare string|fun(item: T): boolean A comparison function or string to match
--- @return fun(item: T): boolean compare_fn The comparison function to use
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
--- @generic T
--- @param list T[]? The list parameter
--- @param compare string|fun(item: T): boolean The comparison parameter
--- @param empty_return_value any The value to return if list is nil
--- @return T[] list The validated list (or empty table)
--- @return (fun(item: T): boolean)? compare_fn The normalized comparison function (nil if list was nil)
--- @nodiscard
local function validate_and_prepare(list, compare, empty_return_value)
  if not list then return empty_return_value or {}, nil end
  if not compare then error("compare parameter is required", 3) end

  local compare_fn = make_compare_fn(compare)
  return list, compare_fn
end

--- Internal helper to perform list operations that can work on first match or all matches.
--- @generic T
--- @param list T[] The validated list
--- @param compare_fn fun(item: T): boolean The comparison function
--- @param operation_fn fun(i: integer, item: T) Function that performs the operation on a single item (i, item) -> should_continue
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
--- @generic T
--- @param list T[]? The list to search in (can be nil, returns false)
--- @param compare string|fun(item: T): boolean A comparison function that receives an item and returns boolean, or a string for direct equality comparison
--- @return boolean has_item True if the list contains a matching item, false otherwise´
--- @nodiscard
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

--- Retrieves the first item (deep-copy) from a list that matches a comparison function or string.
--- @generic T
--- @param list T[]? The list to search in (can be nil, returns nil)
--- @param compare string|fun(item: T): boolean A comparison function that receives an item and returns boolean, or a string for direct equality comparison
--- @return T? item The first matching item, or nil if no match is found
--- @nodiscard
function khaoslib_list.get(list, compare)
  local validated_list, compare_fn = validate_and_prepare(list, compare, nil)
  if not compare_fn then return nil end

  for _, item in ipairs(validated_list) do
    if compare_fn(item) then
      if type(item) == "table" then
        return util.table.deepcopy(item)
      else
        return item
      end
    end
  end

  return nil
end

--- Retrieve all items (deep-copy) from a list that match a comparison function or string.
--- @generic T
--- @param list T[]? The list to search in (can be nil, returns empty table)
--- @param compare string|fun(item: T): boolean A comparison function that receives an item and returns boolean, or a string for direct equality comparison
--- @return T[] list The modified list (same reference as input, or empty table if input was nil)
function khaoslib_list.find(list, compare)
  local validated_list, compare_fn = validate_and_prepare(list, compare, {})
  if not compare_fn then return validated_list end

  local results = {}
  perform_list_operation(validated_list, compare_fn, function(i, item) --luacheck: ignore 212
    table.insert(results, util.table.deepcopy(item))
  end, true)

  return results
end

--- @class ListAddIndexOptions
--- @field index integer? If provided, inserts the item at the specified index instead of appending to the end of the list

--- @class ListAddOptions : ListAddIndexOptions
--- @field allow_duplicates boolean? If true, skips duplicate checking and adds the item directly (default: false)

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
--- @generic T
--- @param list T[]? The list to add to (will be created if nil)
--- @param item T The item to add (will be deep copied)
--- @param compare (string|fun(item: T): boolean)? A comparison function that receives an item and returns boolean, or a string for direct equality comparison. Required when allow_duplicates is false, ignored when allow_duplicates is true.
--- @param options ListAddOptions? Options table with the following fields:
---   - `allow_duplicates` (boolean, default: false): If true, skips duplicate checking and adds the item directly
---   - `index` (integer, optional): If provided, inserts the item at the specified index instead of appending to the end of the list
--- @return T[] list The modified list (same reference as input, or new table if input was nil)
function khaoslib_list.add(list, item, compare, options)
  list = list or {}
  options = options or {}
  local allow_duplicates = options.allow_duplicates or false

  if options.index and (type(options.index) ~= "number" or options.index < 1 or options.index > #list + 1) then
    error("options.index parameter: Expected a valid index between 1 and " .. (#list + 1) .. ", got " .. tostring(options.index), 2)
  end

  if allow_duplicates then
    -- When allowing duplicates, just add the item directly (compare is ignored)
    if options.index then
      table.insert(list, options.index, util.table.deepcopy(item))
    else
      table.insert(list, util.table.deepcopy(item))
    end
  else
    -- When preventing duplicates, we need a comparison function
    if not compare then error("compare parameter is required when allow_duplicates is false", 2) end

    if not khaoslib_list.has(list, compare) then
      if options.index then
        table.insert(list, options.index, util.table.deepcopy(item))
      else
        table.insert(list, util.table.deepcopy(item))
      end
    end
  end

  return list
end

--- @class ListRemoveOptions
--- @field all boolean? If true, removes all matching items instead of just the first (default: false)

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
--- @generic T
--- @param list T[]? The list to remove from (returns empty table if nil)
--- @param compare string|fun(item: T): boolean A comparison function that receives an item and returns boolean, or a string for direct equality comparison
--- @param options ListRemoveOptions? Options table with the following fields:
---   - `all` (boolean, default: false): If true, removes all matching items instead of just the first
--- @return T[] list The modified list (same reference as input, or empty table if input was nil)
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

--- @class ListReplaceOptions
--- @field all boolean? If true, replaces all matching items instead of just the first (default: false)

--- Replaces matching items in a list with a new item or the result of a function callback, called with the old item.
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
--- local ingredients = {{name = "iron-plate", amount = 1}, {name = "copper-plate", amount = 1}}
--- khaoslib_list.replace(ingredients, {name = "steel-plate", amount = 2}, function(r) return r.name == "iron-plate" end)
---
--- -- Replace by function comparison and replacement function
--- khaoslib_list.replace(ingredients, function(r)
---   r.amount = r.amount * 2
---   return r
--- end, function(r) return r.name == "iron-plate" end)
--- ```
---
--- @generic T
--- @param list T[]? The list to modify (returns empty table if nil)
--- @param new_item T|fun(old_item: T): T The new item to replace with (will be deep copied)
--- @param compare string|fun(item: T): boolean A comparison function that receives an item and returns boolean, or a string for direct equality comparison
--- @param options ListReplaceOptions? Options table with the following fields:
---   - `all` (boolean, default: false): If true, replaces all matching items instead of just the first
--- @return T[] list The modified list (same reference as input, or empty table if input was nil)
function khaoslib_list.replace(list, new_item, compare, options)
  local validated_list, compare_fn = validate_and_prepare(list, compare, {})
  if not compare_fn then return validated_list end

  options = options or {}
  local replace_all = options.all or false

  perform_list_operation(validated_list, compare_fn, function(i, item) --luacheck: ignore 212
    if type(new_item) == "function" then
      validated_list[i] = util.table.deepcopy(new_item(util.table.deepcopy(item)))
    else
      validated_list[i] = util.table.deepcopy(new_item)
    end
  end, replace_all)

  return validated_list
end

return khaoslib_list
