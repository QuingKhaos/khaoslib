if ... ~= "__khaoslib__.list" then
  return require("__khaoslib__.list")
end

local util = require("util")

--- Reusable utilities for list manipulation to provide a consistent list manipulation behavior.
---
--- This module provides common operations for working with lists/arrays,
--- supporting both string-based and function-based comparison logic.
---
--- ```lua
--- local khaoslib_list = require("__khaoslib__.list")
--- ```
--- @class khaoslib_list
local khaoslib_list = {}

--- Internal helper to normalize comparison logic for consistent behavior across all list operations.
--- Converts string comparisons to functions, enabling uniform handling throughout the module.
--- @param compare function|string A comparison function or string to match
--- @return function compare_fn The comparison function to use
local function make_compare_fn(compare)
  if type(compare) == "string" then
    return function(item) return item == compare end
  end

  return compare
end

--- Checks if a list contains an item matching a comparison function or string.
--- @param list table The list to search in
--- @param compare function|string A comparison function or string to match
--- @return boolean has_item True if the list contains a matching item
function khaoslib_list.has(list, compare)
  if not list then return false end

  local compare_fn = make_compare_fn(compare)

  for _, item in pairs(list) do
    if compare_fn(item) then
      return true
    end
  end

  return false
end

--- Adds an item to a list if it doesn't already exist, preventing duplicates.
--- @param list table The list to add to
--- @param item any The item to add
--- @param compare function|string A comparison function or string to check for duplicates
--- @return table list The modified list
function khaoslib_list.add(list, item, compare)
  list = list or {}

  if not khaoslib_list.has(list, compare) then
    table.insert(list, util.table.deepcopy(item))
  end

  return list
end

--- Removes the first matching item from a list.
--- @param list table The list to remove from
--- @param compare function|string A comparison function or string to match
--- @return table list The modified list
function khaoslib_list.remove(list, compare)
  if not list then return {} end

  local compare_fn = make_compare_fn(compare)

  for i, item in ipairs(list) do
    if compare_fn(item) then
      table.remove(list, i)
      break
    end
  end

  return list
end

--- Replaces the first matching item in a list with a new item.
--- @param list table The list to modify
--- @param compare function|string A comparison function or string to match
--- @param new_item any The new item to replace with
--- @return table list The modified list
function khaoslib_list.replace(list, compare, new_item)
  if not list then return {} end

  local compare_fn = make_compare_fn(compare)

  for i, item in ipairs(list) do
    if compare_fn(item) then
      list[i] = util.table.deepcopy(new_item)
      break
    end
  end

  return list
end

return khaoslib_list
