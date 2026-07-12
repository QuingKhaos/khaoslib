local khaoslib_list = require("__khaoslib__.common.list")
local util = require("util")

--#region Basic manipulation methods
-- A set of basic methods for creating and working with item subgroup manipulation objects.

--- Item subgroup manipulation utilities for Factorio data stage.
---
--- This module provides a fluent API for creating, modifying, and managing item subgroup prototypes
--- during the data stage. It supports method chaining and uses the list utility module for
--- consistent prerequisite and effect manipulation.
--- @class khaoslib.ItemSubGroupManipulator
--- @field private item_subgroup data.ItemSubGroup The item sub-group currently being manipulated.
--- @operator add(khaoslib.ItemSubGroupManipulator): khaoslib.ItemSubGroupManipulator
local khaoslib_item_subgroup = {}

--- Loads a given item subgroup for manipulation or creates a new one if a table is passed.
--- @param item_subgroup data.ItemSubGroupID|data.ItemSubGroup The name of an existing item subgroup or a new item subgroup prototype table.
--- @return khaoslib.ItemSubGroupManipulator manipulator An item subgroup manipulation object for the given item subgroup.
--- @throws If the item subgroup name doesn't exist or if a table is passed with a name that already exists or without a valid name field.
function khaoslib_item_subgroup:load(item_subgroup)
  local item_subgroup_type = type(item_subgroup)
  if item_subgroup_type ~= "string" and item_subgroup_type ~= "table" then error("item_subgroup parameter: Expected string or table , got " .. item_subgroup_type, 2) end

  if item_subgroup_type == "string" then
    if not khaoslib_item_subgroup.exists(item_subgroup) then error("No such item subgroup: " .. item_subgroup, 2) end
  else -- item_subgroup_type == "table"
    if item_subgroup.type and type(item_subgroup.type) ~= "string" then error("item_subgroup table type field should be a string if set", 2) end
    if item_subgroup.type and item_subgroup.type ~= "item-subgroup" then error("item_subgroup table type field should be 'item-subgroup' if set", 2) end
    if not item_subgroup.name or type(item_subgroup.name) ~= "string" then error("item_subgroup table must have a name field of type string", 2) end
    if khaoslib_item_subgroup.exists(item_subgroup.name) then error("An item subgroup with the name " .. item_subgroup.name .. " already exists", 2) end
  end

  local _item_subgroup = item_subgroup --luacheck: ignore 311
  if item_subgroup_type == "string" then
    _item_subgroup = util.table.deepcopy(data.raw["item-subgroup"][item_subgroup])
  else
    _item_subgroup = util.table.deepcopy(item_subgroup)
    _item_subgroup.type = "item-subgroup"
  end

  --- @cast _item_subgroup data.ItemSubGroup
  --- @type khaoslib.ItemSubGroupManipulator
  local obj = {item_subgroup = _item_subgroup}
  setmetatable(obj, self)
  self.__index = self

  return obj
end

--- @diagnostic disable: invisible

--- Internal helper function to resolve the item subgroup from a string, item subgroup prototype data or a item subgroup manipulation object.
--- @param item_subgroup data.ItemSubGroupID|data.ItemSubGroup|khaoslib.ItemSubGroupManipulator The item subgroup to resolve.
--- @return data.ItemSubGroup resolved_item_subgroup The resolved item subgroup prototype.
--- @throws If the item subgroup cannot be resolved.
local function resolve(item_subgroup)
  if type(item_subgroup) == "string" then
    local result = data.raw["item-subgroup"][item_subgroup]
    if not result then
      error("No such item subgroup: " .. item_subgroup, 3)
    end

    return result
  elseif type(item_subgroup) == "table" then
    if getmetatable(item_subgroup) == khaoslib_item_subgroup and item_subgroup.item_subgroup then
      return item_subgroup.item_subgroup
    elseif item_subgroup.type == "item-subgroup" and item_subgroup.name then
      return item_subgroup --[[@as data.ItemSubGroup]]
    else
      error("Invalid item subgroup table: expected manipulator or prototype with type='item-subgroup' and name", 3)
    end
  else
    error("Invalid item subgroup parameter: expected item subgroup name, prototype table, or item subgroup manipulator", 3)
  end
end

--- @diagnostic enable: invisible

--- Gets the raw data table of the item subgroup.
--- @param item_subgroup data.ItemSubGroupID|data.ItemSubGroup|khaoslib.ItemSubGroupManipulator The item subgroup.
--- @return data.ItemSubGroup item_subgroup A deep copy of the item subgroup data.
--- @nodiscard
function khaoslib_item_subgroup.get(item_subgroup)
  return util.table.deepcopy(resolve(item_subgroup)) --[[@as data.ItemSubGroup]]
end

--- @class khaoslib.SetItemSubGroupFields : data.ItemSubGroup
--- @field type? string
--- @field name? string
--- @field group? data.ItemGroupID

--- Merges the given fields into the item subgroup.
--- @param fields khaoslib.SetItemSubGroupFields A table of fields to merge into the item subgroup. See `data.ItemSubGroup` for valid fields.
--- @return khaoslib.ItemSubGroupManipulator self The same item subgroup manipulation object for method chaining.
--- @throws If fields is not a table or if it contains a name field.
function khaoslib_item_subgroup:set(fields)
  if type(fields) ~= "table" then error("fields parameter: Expected table, got " .. type(fields), 2) end
  if fields.type then error("Cannot change the type of an item subgroup.", 2) end
  if fields.name then error("Cannot change the name of an item subgroup using set(). Use copy() to create a new item subgroup with a different name.", 2) end

  self.item_subgroup = util.merge({self.item_subgroup, util.table.deepcopy(fields)})

  return self
end

--- Unsets the given field in the item subgroup currently being manipulated.
--- @param field string The field to unset in the item subgroup. See `data.ItemSubGroup` for valid fields.
--- @return khaoslib.ItemSubGroupManipulator self The same item subgroup manipulation object for method chaining.
--- @throws If field is not a string, or if it is the type or name field.
function khaoslib_item_subgroup:unset(field)
  if type(field) ~= "string" then error("field parameter: Expected string, got " .. type(field), 2) end
  if field == "type" then error("Cannot unset the type of an item group.", 2) end
  if field == "name" then error("Cannot unset the name of an item subgroup.", 2) end

  self.item_subgroup[field] = nil

  return self
end

--- Creates a deep copy of the item subgroup.
--- @param item_subgroup data.ItemSubGroupID|data.ItemSubGroup|khaoslib.ItemSubGroupManipulator The item subgroup.
--- @param new_name data.ItemSubGroupID The name of the new item subgroup. Must not already exist.
--- @return khaoslib.ItemSubGroupManipulator item_subgroup A new item subgroup manipulation object with a deep copy of the item subgroup.
--- @throws If an item subgroup with the new name already exists.
--- @nodiscard
function khaoslib_item_subgroup.copy(item_subgroup, new_name)
  local copy = util.table.deepcopy(resolve(item_subgroup))
  copy.name = new_name

  return khaoslib_item_subgroup:load(copy)
end

--- Commits the changes to the data stage.
--- If the item subgroup already exists, it is overwritten.
--- @return khaoslib.ItemSubGroupManipulator self The same item subgroup manipulation object for method chaining.
function khaoslib_item_subgroup:commit()
  self:remove()
  data:extend({self:get()})

  return self
end

--- Deletes the item subgroup from the data stage instantly. Use with caution, as this works without a commit.
--- @param item_subgroup data.ItemSubGroupID|data.ItemSubGroup The item subgroup.
--- @return nil
--- @overload fun(self: khaoslib.ItemSubGroupManipulator): khaoslib.ItemSubGroupManipulator
function khaoslib_item_subgroup.remove(item_subgroup)
  data.raw["item-subgroup"][resolve(item_subgroup).name] = nil

  if type(item_subgroup) == "table" and getmetatable(item_subgroup) == khaoslib_item_subgroup then
    return item_subgroup --[[@as khaoslib.ItemSubGroupManipulator]]
  end
end

--- Merges another item subgroup manipulation object into this one, excluding the name field.
--- @param other khaoslib.ItemSubGroupManipulator The other item subgroup manipulation object to merge into this one
--- @return khaoslib.ItemSubGroupManipulator self The same item subgroup manipulation object for method chaining.
--- @throws If other is not an item subgroup manipulation object.
function khaoslib_item_subgroup:__add(other)
  if type(other) ~= "table" or getmetatable(other) ~= khaoslib_item_subgroup then
    error("Can only concatenate with another khaoslib.ItemSubGroupManipulator object", 2)
  end

  local other_copy = other:get()
  other_copy.type = nil
  other_copy.name = nil

  return self:set(other_copy --[[@as khaoslib.SetItemSubGroupFields]])
end

--- Compares two item subgroup manipulation objects for equality based on the item subgroup name.
--- @param other khaoslib.ItemSubGroupManipulator The other item subgroup manipulation object to compare with.
--- @return boolean is_equal True if the two item subgroup manipulation objects represent the same item subgroup, false otherwise.
function khaoslib_item_subgroup:__eq(other)
  if type(other) ~= "table" or getmetatable(other) ~= khaoslib_item_subgroup then return false end

  return self.item_subgroup.name == other.item_subgroup.name
end

--- Returns a string representation of the item subgroup manipulation object.
--- @return string representation A string representation of the item subgroup manipulation object.
function khaoslib_item_subgroup:__tostring()
  return "[khaoslib_item_subgroup: " .. self.item_subgroup.name .. "]"
end

--#endregion

--#region Item subgroup manipulation methods
-- A set of utility functions for manipulating item subgroups.

--#endregion

--#region Utility functions
-- Module-level utility functions for item subgroup discovery and analysis.

--- Checks if an item subgroup exists in the data stage.
--- @param name data.ItemSubGroupID The item subgroup name to check.
--- @return boolean exists True if the item subgroup exists, false otherwise.
--- @nodiscard
function khaoslib_item_subgroup.exists(name)
  if type(name) ~= "string" then error("name parameter: Expected string, got " .. type(name), 2) end

  return data.raw["item-subgroup"][name] ~= nil
end

--- Finds all item subgroups that match a custom compare function.
--- @param compare_fn fun(item_subgroup: data.ItemSubGroup): boolean A function that returns true for item subgroups to include.
--- @return data.ItemSubGroupID[] item_subgroups A list of item subgroup names that match the compare function.
--- @throws If compare_fn is not a function.
--- @nodiscard
function khaoslib_item_subgroup.find(compare_fn)
  if type(compare_fn) ~= "function" then error("compare_fn parameter: Expected function, got " .. type(compare_fn), 2) end

  local result = {}
  for _, item_subgroup in pairs(data.raw["item-subgroup"] or {}) do
    if compare_fn(item_subgroup) then
      table.insert(result, item_subgroup.name)
    end
  end

  return result
end

--#endregion

return khaoslib_item_subgroup
