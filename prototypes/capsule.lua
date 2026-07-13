local khaoslib_list = require("__khaoslib__.common.list")
local util = require("util")

--#region Basic manipulation methods
-- A set of basic methods for creating and working with capsule manipulation objects.

--- Capsule manipulation utilities for Factorio data stage.
---
--- This module provides a fluent API for creating, modifying, and managing capsule prototypes
--- during the data stage. It supports method chaining and uses the list utility module for
--- consistent prerequisite and effect manipulation.
--- @class khaoslib.CapsuleManipulator
--- @field private capsule data.CapsulePrototype The capsule currently being manipulated.
--- @operator add(khaoslib.CapsuleManipulator): khaoslib.CapsuleManipulator
local khaoslib_capsule = {}

--- Loads a given capsule for manipulation or creates a new one if a table is passed.
--- @param capsule data.ItemID|data.CapsulePrototype The name of an existing capsule or a new capsule prototype table.
--- @return khaoslib.CapsuleManipulator manipulator A capsule manipulation object for the given capsule.
--- @throws If the capsule name doesn't exist or if a table is passed with a name that already exists or without a valid name field.
function khaoslib_capsule:load(capsule)
  local capsule_type = type(capsule)
  if capsule_type ~= "string" and capsule_type ~= "table" then error("capsule parameter: Expected string or table , got " .. capsule_type, 2) end

  if capsule_type == "string" then
    if not khaoslib_capsule.exists(capsule) then error("No such capsule: " .. capsule, 2) end
  else -- capsule_type == "table"
    if capsule.type and type(capsule.type) ~= "string" then error("capsule table type field should be a string if set", 2) end
    if capsule.type and capsule.type ~= "capsule" then error("capsule table type field should be 'capsule' if set", 2) end
    if not capsule.name or type(capsule.name) ~= "string" then error("capsule table must have a name field of type string", 2) end
    if khaoslib_capsule.exists(capsule.name) then error("A capsule with the name " .. capsule.name .. " already exists", 2) end
  end

  local _capsule = capsule --luacheck: ignore 311
  if capsule_type == "string" then
    _capsule = util.table.deepcopy(data.raw["capsule"][capsule])
  else
    _capsule = util.table.deepcopy(capsule)
    _capsule.type = "capsule"
  end

  --- @cast _capsule data.CapsulePrototype
  --- @type khaoslib.CapsuleManipulator
  local obj = {capsule = _capsule}
  setmetatable(obj, self)
  self.__index = self

  return obj
end

--- @diagnostic disable: invisible

--- Internal helper function to resolve the capsule from a string, capsule prototype data or a capsule manipulation object.
--- @param capsule data.ItemID|data.CapsulePrototype|khaoslib.CapsuleManipulator The capsule to resolve.
--- @return data.CapsulePrototype resolved_capsule The resolved capsule prototype.
--- @throws If the capsule cannot be resolved.
local resolve = function(capsule)
  if type(capsule) == "string" then
    local result = data.raw["capsule"][capsule]
    if not result then
      error("No such capsule: " .. capsule, 3)
    end

    return result
  elseif type(capsule) == "table" then
    if getmetatable(capsule) == khaoslib_capsule and capsule.capsule then
      return capsule.capsule
    elseif capsule.type == "capsule" and capsule.name then
      return capsule --[[@as data.CapsulePrototype]]
    else
      error("Invalid capsule table: expected manipulator or prototype with type='capsule' and name", 3)
    end
  else
    error("Invalid capsule parameter: expected capsule name, prototype table, or capsule manipulator", 3)
  end
end

--- @diagnostic enable: invisible

--- Gets the raw data table of the capsule.
--- @param capsule data.ItemID|data.CapsulePrototype|khaoslib.CapsuleManipulator The capsule.
--- @return data.CapsulePrototype capsule A deep copy of the capsule data.
--- @nodiscard
function khaoslib_capsule.get(capsule)
  return util.table.deepcopy(resolve(capsule)) --[[@as data.CapsulePrototype]]
end

--- @class khaoslib_capsule.CapsulePrototype : data.CapsulePrototype
--- @field type? string
--- @field name? string
--- @field stack_size? data.ItemCountType

--- Merges the given fields into the capsule.
--- @param fields khaoslib_capsule.CapsulePrototype A table of fields to merge into the capsule. See `data.CapsulePrototype` for valid fields.
--- @return khaoslib.CapsuleManipulator self The same capsule manipulation object for method chaining.
--- @throws If fields is not a table or if it contains a name field.
function khaoslib_capsule:set(fields)
  if type(fields) ~= "table" then error("fields parameter: Expected table, got " .. type(fields), 2) end
  if fields.type then error("Cannot change the type of a capsule.", 2) end
  if fields.name then error("Cannot change the name of a capsule using set(). Use copy() to create a new capsule with a different name.", 2) end

  self.capsule = util.merge({self.capsule, util.table.deepcopy(fields)})

  return self
end

--- Unsets the given field in the capsule currently being manipulated.
--- @param field string The field to unset in the capsule. See `data.CapsulePrototype` for valid fields.
--- @return khaoslib.CapsuleManipulator self The same capsule manipulation object for method chaining.
--- @throws If field is not a string, or if it is the type or name field.
function khaoslib_capsule:unset(field)
  if type(field) ~= "string" then error("field parameter: Expected string, got " .. type(field), 2) end
  if field == "type" then error("Cannot unset the type of a capsule.", 2) end
  if field == "name" then error("Cannot unset the name of a capsule.", 2) end

  self.capsule[field] = nil

  return self
end

--- Creates a deep copy of the capsule.
--- @param capsule data.ItemID|data.CapsulePrototype|khaoslib.CapsuleManipulator The capsule.
--- @param new_name data.ItemID The name of the new capsule. Must not already exist.
--- @return khaoslib.CapsuleManipulator capsule A new capsule manipulation object with a deep copy of the capsule.
--- @throws If a capsule with the new name already exists.
--- @nodiscard
function khaoslib_capsule.copy(capsule, new_name)
  local copy = util.table.deepcopy(resolve(capsule))
  copy.name = new_name

  return khaoslib_capsule:load(copy)
end

--- Commits the changes to the data stage.
--- If the capsule already exists, it is overwritten.
--- @return khaoslib.CapsuleManipulator self The same capsule manipulation object for method chaining.
function khaoslib_capsule:commit()
  self:remove()
  data:extend({self:get()})

  return self
end

--- Deletes the capsule from the data stage instantly. Use with caution, as this works without a commit.
--- @param capsule data.ItemID|data.CapsulePrototype The capsule.
--- @return nil
--- @overload fun(self: khaoslib.CapsuleManipulator): khaoslib.CapsuleManipulator
function khaoslib_capsule.remove(capsule)
  data.raw.capsule[resolve(capsule).name] = nil

  if type(capsule) == "table" and getmetatable(capsule) == khaoslib_capsule then
    return capsule --[[@as khaoslib.CapsuleManipulator]]
  end
end

--- Merges another capsule manipulation object into this one, excluding the name field.
--- @param other khaoslib.CapsuleManipulator The other capsule manipulation object to merge into this one
--- @return khaoslib.CapsuleManipulator self The same capsule manipulation object for method chaining.
--- @throws If other is not a capsule manipulation object.
function khaoslib_capsule:__add(other)
  if type(other) ~= "table" or getmetatable(other) ~= khaoslib_capsule then
    error("Can only concatenate with another khaoslib.CapsuleManipulator object", 2)
  end

  local other_copy = other:get()
  other_copy.type = nil
  other_copy.name = nil

  return self:set(other_copy --[[@as khaoslib_capsule.CapsulePrototype]])
end

--- Compares two capsule manipulation objects for equality based on the capsule name.
--- @param other khaoslib.CapsuleManipulator The other capsule manipulation object to compare with.
--- @return boolean is_equal True if the two capsule manipulation objects represent the same capsule, false otherwise.
function khaoslib_capsule:__eq(other)
  if type(other) ~= "table" or getmetatable(other) ~= khaoslib_capsule then return false end

  return self.capsule.name == other.capsule.name
end

--- Returns a string representation of the capsule manipulation object.
--- @return string representation A string representation of the capsule manipulation object.
function khaoslib_capsule:__tostring()
  return "[khaoslib_capsule: " .. self.capsule.name .. "]"
end

--#endregion

--#region Capsule manipulation methods
-- A set of utility functions for manipulating capsules.

--- If the capsule has a single icon, it is converted to the icons list format. If the capsule already has an icons list, no changes are made.
--- @param capsule data.CapsulePrototype The capsule reference to populate icons for.
local populate_icons = function(capsule)
  if capsule.icon and (not capsule.icons or #capsule.icons == 0) then
    capsule.icons = {{icon = capsule.icon, icon_size = capsule.icon_size or nil}}
    capsule.icon = nil
    capsule.icon_size = nil
  end
end

--- If just a single capsule exists in the icons list, and it has no special properties, depopulate the icons list and set the icon and icon_size fields instead.
--- @param capsule data.CapsulePrototype The capsule reference to depopulate icons from.
local depopulate_icons = function(capsule)
  if #capsule.icons == 1 then
    local icon = capsule.icons[1]
    if icon.tint == nil and icon.shift == nil and icon.scale == nil and icon.draw_background == nil and icon.floating == nil then
      capsule.icon = icon.icon
      capsule.icon_size = icon.icon_size or nil
      capsule.icons = nil
    end
  end
end

--- Returns a deepcopy of all icons for the given capsule. If the capsule has a single icon, it is returned as a single-element list.
--- @param capsule data.ItemID|data.CapsulePrototype|khaoslib.CapsuleManipulator The capsule.
--- @return data.IconData[] icons A list of icons for the capsule.
--- @nodiscard
function khaoslib_capsule.get_icons(capsule)
  local resolved_capsule = resolve(capsule)
  if resolved_capsule.icons then
    return util.table.deepcopy(resolved_capsule.icons --[=[@as data.IconData[]]=])
  elseif resolved_capsule.icon then
    return util.table.deepcopy({{icon = resolved_capsule.icon, icon_size = resolved_capsule.icon_size or nil}})
  else
    return {}
  end
end

--- Returns a deep-copied list of all icons for the given capsule that match the given criteria.
--- @param capsule data.ItemID|data.CapsulePrototype|khaoslib.CapsuleManipulator The capsule.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @return data.IconData[] icons A list of matching icons.
--- @throws If compare is not a string or function.
--- @nodiscard
function khaoslib_capsule.find_icons(capsule, compare)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  local resolved_capsule = resolve(capsule)
  populate_icons(resolved_capsule)

  local result = khaoslib_list.find(resolved_capsule.icons, compare_fn)
  depopulate_icons(resolved_capsule)

  return result
end

--- Sets the list of icons for the capsule currently being manipulated, replacing any existing icons.
--- @param icons data.IconData[] A list of icons to set.
--- @return khaoslib.CapsuleManipulator self The same capsule manipulation object for method chaining.
--- @throws If icons is not a table.
function khaoslib_capsule:set_icons(icons)
  if type(icons) ~= "table" then error("icons parameter: Expected table, got " .. type(icons), 2) end

  self.capsule.icon = nil
  self.capsule.icon_size = nil
  self.capsule.icons = util.table.deepcopy(icons)
  depopulate_icons(self.capsule)

  return self
end

--- Returns the number of icons for the given capsule.
--- @param capsule data.ItemID|data.CapsulePrototype|khaoslib.CapsuleManipulator The capsule.
--- @return integer count The number of icons.
--- @nodiscard
function khaoslib_capsule.count_icons(capsule)
  local resolved_capsule = resolve(capsule)
  return resolved_capsule.icon ~= nil and 1 or #(resolved_capsule.icons or {})
end

--- Checks if the capsule has an icon matching the given criteria.
--- Supports both string matching (by icon filename) and custom comparison functions.
--- @param capsule data.ItemID|data.CapsulePrototype|khaoslib.CapsuleManipulator The capsule.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @return boolean has_icon True if the capsule has the icon, false otherwise.
--- @throws If compare is not a string or function.
--- @nodiscard
function khaoslib_capsule.has_icon(capsule, compare)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  local resolved_capsule = resolve(capsule)
  populate_icons(resolved_capsule)

  local result = khaoslib_list.has(resolved_capsule.icons, compare_fn)
  depopulate_icons(resolved_capsule)

  return result
end

--- Gets the first icon (deep-copy) that matches the given criteria.
--- Supports both string matching (by icon filename) and custom comparison functions.
--- @param capsule data.ItemID|data.CapsulePrototype|khaoslib.CapsuleManipulator The capsule.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @return data.IconData? icon The first matching icon, or nil if no match is found.
--- @throws If compare is not a string or function.
--- @nodiscard
function khaoslib_capsule.get_icon(capsule, compare)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  local resolved_capsule = resolve(capsule)
  populate_icons(resolved_capsule)

  local result = khaoslib_list.get(resolved_capsule.icons, compare_fn)
  depopulate_icons(resolved_capsule)

  return result
end

--- Adds an icon to the capsule, allows duplicates.
--- @param icon data.IconData The icon data to add.
--- @param options ListAddIndexOptions? Options table with fields:
---   - `index` (integer, optional): If provided, inserts the icon at the specified index instead of appending to the end of the list.
--- @return khaoslib.CapsuleManipulator self The same capsule manipulation object for method chaining.
--- @throws If icon is not a table or doesn't have required fields.
function khaoslib_capsule:add_icon(icon, options)
  if type(icon) ~= "table" then error("icon parameter: Expected table, got " .. type(icon), 2) end
  if not icon.icon or type(icon.icon) ~= "string" then error("icon parameter: Must have an icon field of type string", 2) end

  options = options or {}
  --- @cast options ListAddOptions
  options.allow_duplicates = true

  populate_icons(self.capsule)
  self.capsule.icons = khaoslib_list.add(self.capsule.icons, icon, nil, options)
  depopulate_icons(self.capsule)

  return self
end

--- Removes matching icons from the capsule.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @param options ListRemoveOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, removes all matching icons instead of just the first.
--- @return khaoslib.CapsuleManipulator self The same capsule manipulation object for method chaining.
--- @throws If compare is not a string or function.
function khaoslib_capsule:remove_icon(compare, options)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  populate_icons(self.capsule)
  self.capsule.icons = khaoslib_list.remove(self.capsule.icons, compare_fn, options)
  depopulate_icons(self.capsule)

  return self
end

--- Replaces matching icons with a new icon.
--- If no matching icons are found, no changes are made.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @param replacement (fun(icon: data.IconData): data.IconData)|data.IconData The new icon data to replace with.
--- @param options ListReplaceOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, replaces all matching icons instead of just the first.
--- @return khaoslib.CapsuleManipulator self The same capsule manipulation object for method chaining.
--- @throws If compare is not a string or function, or replacement is not a table or function.
function khaoslib_capsule:replace_icon(compare, replacement, options)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  if type(replacement) ~= "table" and type(replacement) ~= "function" then error("replacement parameter: Expected table or function, got " .. type(replacement), 2) end
  if type(replacement) == "table" then
    if not replacement.icon or type(replacement.icon) ~= "string" then error("replacement parameter: Must have an icon field of type string", 2) end
  end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  populate_icons(self.capsule)
  self.capsule.icons = khaoslib_list.replace(self.capsule.icons, replacement, compare_fn, options)
  depopulate_icons(self.capsule)

  return self
end

--- Removes all icons from the capsule.
--- @return khaoslib.CapsuleManipulator self The same capsule manipulation object for method chaining.
function khaoslib_capsule:clear_icons()
  self.capsule.icon = nil
  self.capsule.icon_size = nil
  self.capsule.icons = nil

  return self
end

--#endregion

--#region Utility functions
-- Module-level utility functions for capsule discovery and analysis.

--- Checks if a capsule exists in the data stage.
--- @param name data.ItemID The capsule name to check.
--- @return boolean exists True if the capsule exists, false otherwise.
--- @nodiscard
function khaoslib_capsule.exists(name)
  if type(name) ~= "string" then error("name parameter: Expected string, got " .. type(name), 2) end

  return data.raw["capsule"][name] ~= nil
end

--- Finds all capsules that match a custom compare function.
--- @param compare_fn fun(capsule: data.CapsulePrototype): boolean A function that returns true for capsules to include.
--- @return data.ItemID[] capsules A list of capsule names that match the compare function.
--- @throws If compare_fn is not a function.
--- @nodiscard
function khaoslib_capsule.find(compare_fn)
  if type(compare_fn) ~= "function" then error("compare_fn parameter: Expected function, got " .. type(compare_fn), 2) end

  local result = {}
  for _, capsule in pairs(data.raw["capsule"] or {}) do
    if compare_fn(capsule) then
      table.insert(result, capsule.name)
    end
  end

  return result
end

--#endregion

return khaoslib_capsule
