local khaoslib_list = require("__khaoslib__.common.list")
local util = require("util")

--#region Basic manipulation methods
-- A set of basic methods for creating and working with item group manipulation objects.

--- Item manipulation utilities for Factorio data stage.
---
--- This module provides a fluent API for creating, modifying, and managing item group prototypes
--- during the data stage. It supports method chaining and uses the list utility module for
--- consistent prerequisite and effect manipulation.
--- @class khaoslib.ItemGroupManipulator
--- @field private item_group data.ItemGroup The item group currently being manipulated.
--- @operator add(khaoslib.ItemGroupManipulator): khaoslib.ItemGroupManipulator
local khaoslib_item_group = {}

--- Loads a given item group for manipulation or creates a new one if a table is passed.
--- @param item_group data.ItemGroupID|data.ItemGroup The name of an existing item group or a new item group prototype table.
--- @return khaoslib.ItemGroupManipulator manipulator An item group manipulation object for the given item group.
--- @throws If the item group name doesn't exist or if a table is passed with a name that already exists or without a valid name field.
function khaoslib_item_group:load(item_group)
  local item_group_type = type(item_group)
  if item_group_type ~= "string" and item_group_type ~= "table" then error("item_group parameter: Expected string or table , got " .. item_group_type, 2) end

  if item_group_type == "string" then
    if not khaoslib_item_group.exists(item_group) then error("No such item group: " .. item_group, 2) end
  else -- item_group_type == "table"
    if item_group.type and type(item_group.type) ~= "string" then error("item_group table type field should be a string if set", 2) end
    if item_group.type and item_group.type ~= "item-group" then error("item_group table type field should be 'item-group' if set", 2) end
    if not item_group.name or type(item_group.name) ~= "string" then error("item_group table must have a name field of type string", 2) end
    if khaoslib_item_group.exists(item_group.name) then error("An item group with the name " .. item_group.name .. " already exists", 2) end
  end

  local _item_group = item_group --luacheck: ignore 311
  if item_group_type == "string" then
    _item_group = util.table.deepcopy(data.raw["item-group"][item_group])
  else
    _item_group = util.table.deepcopy(item_group)
    _item_group.type = "item-group"
  end

  --- @cast _item_group data.ItemGroup
  --- @type khaoslib.ItemGroupManipulator
  local obj = {item_group = _item_group}
  setmetatable(obj, self)
  self.__index = self

  return obj
end

--- @diagnostic disable: invisible

--- Internal helper function to resolve the item group from a string, item group prototype data or a item group manipulation object.
--- @param item_group data.ItemGroupID|data.ItemGroup|khaoslib.ItemGroupManipulator The item group to resolve.
--- @return data.ItemGroup resolved_item_group The resolved item group prototype.
--- @throws If the item group cannot be resolved.
local resolve = function(item_group)
  if type(item_group) == "string" then
    local result = data.raw["item-group"][item_group]
    if not result then
      error("No such item group: " .. item_group, 3)
    end

    return result
  elseif type(item_group) == "table" then
    if getmetatable(item_group) == khaoslib_item_group and item_group.item_group then
      return item_group.item_group
    elseif item_group.type == "item-group" and item_group.name then
      return item_group --[[@as data.ItemGroup]]
    else
      error("Invalid item group table: expected manipulator or prototype with type='item-group' and name", 3)
    end
  else
    error("Invalid item group parameter: expected item group name, prototype table, or item group manipulator", 3)
  end
end

--- @diagnostic enable: invisible

--- Gets the raw data table of the item group.
--- @param item_group data.ItemGroupID|data.ItemGroup|khaoslib.ItemGroupManipulator The item group.
--- @return data.ItemGroup item_group A deep copy of the item group data.
--- @nodiscard
function khaoslib_item_group.get(item_group)
  return util.table.deepcopy(resolve(item_group)) --[[@as data.ItemGroup]]
end

--- @class khaoslib.SetItemGroupFields : data.ItemGroup
--- @field type? string
--- @field name? string

--- Merges the given fields into the item group.
--- @param fields khaoslib.SetItemGroupFields A table of fields to merge into the item group. See `data.ItemGroup` for valid fields.
--- @return khaoslib.ItemGroupManipulator self The same item group manipulation object for method chaining.
--- @throws If fields is not a table or if it contains a name field.
function khaoslib_item_group:set(fields)
  if type(fields) ~= "table" then error("fields parameter: Expected table, got " .. type(fields), 2) end
  if fields.type then error("Cannot change the type of an item group.", 2) end
  if fields.name then error("Cannot change the name of an item group using set(). Use copy() to create a new item group with a different name.", 2) end

  self.item_group = util.merge({self.item_group, util.table.deepcopy(fields)})

  return self
end

--- Unsets the given field in the item group currently being manipulated.
--- @param field string The field to unset in the item group. See `data.ItemGroup` for valid fields.
--- @return khaoslib.ItemGroupManipulator self The same item group manipulation object for method chaining.
--- @throws If field is not a string, or if it is the type or name field.
function khaoslib_item_group:unset(field)
  if type(field) ~= "string" then error("field parameter: Expected string, got " .. type(field), 2) end
  if field == "type" then error("Cannot unset the type of an item group.", 2) end
  if field == "name" then error("Cannot unset the name of an item group.", 2) end

  self.item_group[field] = nil

  return self
end

--- Creates a deep copy of the item group.
--- @param item_group data.ItemGroupID|data.ItemGroup|khaoslib.ItemGroupManipulator The item group.
--- @param new_name data.ItemGroupID The name of the new item group. Must not already exist.
--- @return khaoslib.ItemGroupManipulator item_group A new item group manipulation object with a deep copy of the item group.
--- @throws If an item group with the new name already exists.
--- @nodiscard
function khaoslib_item_group.copy(item_group, new_name)
  local copy = util.table.deepcopy(resolve(item_group))
  copy.name = new_name

  return khaoslib_item_group:load(copy)
end

--- Commits the changes to the data stage.
--- If the item group already exists, it is overwritten.
--- @return khaoslib.ItemGroupManipulator self The same item group manipulation object for method chaining.
function khaoslib_item_group:commit()
  self:remove()
  data:extend({self:get()})

  return self
end

--- Deletes the item group from the data stage instantly. Use with caution, as this works without a commit.
--- @param item_group data.ItemGroupID|data.ItemGroup The item group.
--- @return nil
--- @overload fun(self: khaoslib.ItemGroupManipulator): khaoslib.ItemGroupManipulator
function khaoslib_item_group.remove(item_group)
  data.raw["item-group"][resolve(item_group).name] = nil

  if type(item_group) == "table" and getmetatable(item_group) == khaoslib_item_group then
    return item_group --[[@as khaoslib.ItemGroupManipulator]]
  end
end

--- Merges another item group manipulation object into this one, excluding the name field.
--- @param other khaoslib.ItemGroupManipulator The other item group manipulation object to merge into this one
--- @return khaoslib.ItemGroupManipulator self The same item group manipulation object for method chaining.
--- @throws If other is not an item group manipulation object.
function khaoslib_item_group:__add(other)
  if type(other) ~= "table" or getmetatable(other) ~= khaoslib_item_group then
    error("Can only concatenate with another khaoslib.ItemGroupManipulator object", 2)
  end

  local other_copy = other:get()
  other_copy.type = nil
  other_copy.name = nil

  return self:set(other_copy --[[@as khaoslib.SetItemGroupFields]])
end

--- Compares two item group manipulation objects for equality based on the item group name.
--- @param other khaoslib.ItemGroupManipulator The other item group manipulation object to compare with.
--- @return boolean is_equal True if the two item group manipulation objects represent the same item group, false otherwise.
function khaoslib_item_group:__eq(other)
  if type(other) ~= "table" or getmetatable(other) ~= khaoslib_item_group then return false end

  return self.item_group.name == other.item_group.name
end

--- Returns a string representation of the item group manipulation object.
--- @return string representation A string representation of the item group manipulation object.
function khaoslib_item_group:__tostring()
  return "[khaoslib_item_group: " .. self.item_group.name .. "]"
end

--#endregion

--#region Item group manipulation methods
-- A set of utility functions for manipulating item groups.

--- If the item group has a single icon, it is converted to the icons list format. If the item group already has an icons list, no changes are made.
--- @param item_group data.ItemGroup The item group reference to populate icons for.
local populate_icons = function(item_group)
  if item_group.icon and (not item_group.icons or #item_group.icons == 0) then
    item_group.icons = {{icon = item_group.icon, icon_size = item_group.icon_size or nil}}
    item_group.icon = nil
    item_group.icon_size = nil
  end
end

--- If just a single item exists in the icons list, and it has no special properties, depopulate the icons list and set the icon and icon_size fields instead.
--- @param item_group data.ItemGroup The item group reference to depopulate icons from.
local depopulate_icons = function(item_group)
  if #item_group.icons == 1 then
    local icon = item_group.icons[1]
    if icon.tint == nil and icon.shift == nil and icon.scale == nil and icon.draw_background == nil and icon.floating == nil then
      item_group.icon = icon.icon
      item_group.icon_size = icon.icon_size or nil
      item_group.icons = nil
    end
  end
end

--- Returns a deepcopy of all icons for the given item group. If the item group has a single icon, it is returned as a single-element list.
--- @param item_group data.ItemGroupID|data.ItemGroup|khaoslib.ItemGroupManipulator The item group.
--- @return data.IconData[] icons A list of icons for the item group.
--- @nodiscard
function khaoslib_item_group.get_icons(item_group)
  local resolved_item_group = resolve(item_group)
  if resolved_item_group.icons then
    return util.table.deepcopy(resolved_item_group.icons --[=[@as data.IconData[]]=])
  elseif resolved_item_group.icon then
    return util.table.deepcopy({{icon = resolved_item_group.icon, icon_size = resolved_item_group.icon_size or nil}})
  else
    return {}
  end
end

--- Returns a deep-copied list of all icons for the given item group that match the given criteria.
--- @param item_group data.ItemGroupID|data.ItemGroup|khaoslib.ItemGroupManipulator The item group.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @return data.IconData[] icons A list of matching icons.
--- @throws If compare is not a string or function.
--- @nodiscard
function khaoslib_item_group.find_icons(item_group, compare)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  local resolved_item_group = resolve(item_group)
  populate_icons(resolved_item_group)

  local result = khaoslib_list.find(resolved_item_group.icons, compare_fn)
  depopulate_icons(resolved_item_group)

  return result
end

--- Sets the list of icons for the item group currently being manipulated, replacing any existing icons.
--- @param icons data.IconData[] A list of icons to set.
--- @return khaoslib.ItemGroupManipulator self The same item group manipulation object for method chaining.
--- @throws If icons is not a table.
function khaoslib_item_group:set_icons(icons)
  if type(icons) ~= "table" then error("icons parameter: Expected table, got " .. type(icons), 2) end

  self.item_group.icon = nil
  self.item_group.icon_size = nil
  self.item_group.icons = util.table.deepcopy(icons)
  depopulate_icons(self.item_group)

  return self
end

--- Returns the number of icons for the given item group.
--- @param item_group data.ItemGroupID|data.ItemGroup|khaoslib.ItemGroupManipulator The item group.
--- @return integer count The number of icons.
--- @nodiscard
function khaoslib_item_group.count_icons(item_group)
  local resolved_item_group = resolve(item_group)
  return resolved_item_group.icon ~= nil and 1 or #(resolved_item_group.icons or {})
end

--- Checks if the item group has an icon matching the given criteria.
--- Supports both string matching (by icon filename) and custom comparison functions.
--- @param item_group data.ItemGroupID|data.ItemGroup|khaoslib.ItemGroupManipulator The item group.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @return boolean has_icon True if the item group has the icon, false otherwise.
--- @throws If compare is not a string or function.
--- @nodiscard
function khaoslib_item_group.has_icon(item_group, compare)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  local resolved_item_group = resolve(item_group)
  populate_icons(resolved_item_group)

  local result = khaoslib_list.has(resolved_item_group.icons, compare_fn)
  depopulate_icons(resolved_item_group)

  return result
end

--- Gets the first icon (deep-copy) that matches the given criteria.
--- Supports both string matching (by icon filename) and custom comparison functions.
--- @param item_group data.ItemGroupID|data.ItemGroup|khaoslib.ItemGroupManipulator The item group.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @return data.IconData? icon The first matching icon, or nil if no match is found.
--- @throws If compare is not a string or function.
--- @nodiscard
function khaoslib_item_group.get_icon(item_group, compare)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  local resolved_item_group = resolve(item_group)
  populate_icons(resolved_item_group)

  local result = khaoslib_list.get(resolved_item_group.icons, compare_fn)
  depopulate_icons(resolved_item_group)

  return result
end

--- Adds an icon to the item group, allows duplicates.
--- @param icon data.IconData The icon data to add.
--- @param options ListAddIndexOptions? Options table with fields:
---   - `index` (integer, optional): If provided, inserts the icon at the specified index instead of appending to the end of the list.
--- @return khaoslib.ItemGroupManipulator self The same item group manipulation object for method chaining.
--- @throws If icon is not a table or doesn't have required fields.
function khaoslib_item_group:add_icon(icon, options)
  if type(icon) ~= "table" then error("icon parameter: Expected table, got " .. type(icon), 2) end
  if not icon.icon or type(icon.icon) ~= "string" then error("icon parameter: Must have an icon field of type string", 2) end

  options = options or {}
  --- @cast options ListAddOptions
  options.allow_duplicates = true

  populate_icons(self.item_group)
  self.item_group.icons = khaoslib_list.add(self.item_group.icons, icon, nil, options)
  depopulate_icons(self.item_group)

  return self
end

--- Removes matching icons from the item group.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @param options ListRemoveOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, removes all matching icons instead of just the first.
--- @return khaoslib.ItemGroupManipulator self The same item group manipulation object for method chaining.
--- @throws If compare is not a string or function.
function khaoslib_item_group:remove_icon(compare, options)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  populate_icons(self.item_group)
  self.item_group.icons = khaoslib_list.remove(self.item_group.icons, compare_fn, options)
  depopulate_icons(self.item_group)

  return self
end

--- Replaces matching icons with a new icon.
--- If no matching icons are found, no changes are made.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @param replacement (fun(icon: data.IconData): data.IconData)|data.IconData The new icon data to replace with.
--- @param options ListReplaceOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, replaces all matching icons instead of just the first.
--- @return khaoslib.ItemGroupManipulator self The same item group manipulation object for method chaining.
--- @throws If compare is not a string or function, or replacement is not a table or function.
function khaoslib_item_group:replace_icon(compare, replacement, options)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  if type(replacement) ~= "table" and type(replacement) ~= "function" then error("replacement parameter: Expected table or function, got " .. type(replacement), 2) end
  if type(replacement) == "table" then
    if not replacement.icon or type(replacement.icon) ~= "string" then error("replacement parameter: Must have an icon field of type string", 2) end
  end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  populate_icons(self.item_group)
  self.item_group.icons = khaoslib_list.replace(self.item_group.icons, replacement, compare_fn, options)
  depopulate_icons(self.item_group)

  return self
end

--- Removes all icons from the item group.
--- @return khaoslib.ItemGroupManipulator self The same item group manipulation object for method chaining.
function khaoslib_item_group:clear_icons()
  self.item_group.icon = nil
  self.item_group.icon_size = nil
  self.item_group.icons = nil

  return self
end

--#endregion

--#region Utility functions
-- Module-level utility functions for item group discovery and analysis.

--- Checks if an item group exists in the data stage.
--- @param name data.ItemGroupID The item group name to check.
--- @return boolean exists True if the item group exists, false otherwise.
--- @nodiscard
function khaoslib_item_group.exists(name)
  if type(name) ~= "string" then error("name parameter: Expected string, got " .. type(name), 2) end

  return data.raw["item-group"][name] ~= nil
end

--- Finds all item groups that match a custom compare function.
--- @param compare_fn fun(item_group: data.ItemGroup): boolean A function that returns true for item groups to include.
--- @return data.ItemGroupID[] item_groups A list of item group names that match the compare function.
--- @throws If compare_fn is not a function.
--- @nodiscard
function khaoslib_item_group.find(compare_fn)
  if type(compare_fn) ~= "function" then error("compare_fn parameter: Expected function, got " .. type(compare_fn), 2) end

  local result = {}
  for _, item_group in pairs(data.raw["item-group"] or {}) do
    if compare_fn(item_group) then
      table.insert(result, item_group.name)
    end
  end

  return result
end

--#endregion

return khaoslib_item_group
