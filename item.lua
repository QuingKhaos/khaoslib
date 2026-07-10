local khaoslib_list = require("__khaoslib__.list")
local util = require("util")

--#region Basic manipulation methods
-- A set of basic methods for creating and working with item manipulation objects.

--- Item manipulation utilities for Factorio data stage.
---
--- This module provides a fluent API for creating, modifying, and managing item prototypes
--- during the data stage. It supports method chaining and uses the list utility module for
--- consistent prerequisite and effect manipulation.
--- @class khaoslib.ItemManipulator
--- @field private item data.ItemPrototype The item currently being manipulated.
--- @operator add(khaoslib.ItemManipulator): khaoslib.ItemManipulator
local khaoslib_item = {}

--- Loads a given item for manipulation or creates a new one if a table is passed.
--- @param item data.ItemID|data.ItemPrototype The name of an existing item or a new item prototype table.
--- @return khaoslib.ItemManipulator manipulator An item manipulation object for the given item.
--- @throws If the item name doesn't exist or if a table is passed with a name that already exists or without a valid name field.
function khaoslib_item:load(item)
  local item_type = type(item)
  if item_type ~= "string" and item_type ~= "table" then error("item parameter: Expected string or table , got " .. item_type, 2) end

  if item_type == "string" then
    if not khaoslib_item.exists(item) then error("No such item: " .. item, 2) end
  else -- item_type == "table"
    if item.type and type(item.type) ~= "string" then error("item table type field should be a string if set", 2) end
    if item.type and item.type ~= "item" then error("item table type field should be 'item' if set", 2) end
    if not item.name or type(item.name) ~= "string" then error("item table must have a name field of type string", 2) end
    if khaoslib_item.exists(item.name) then error("An item with the name " .. item.name .. " already exists", 2) end
  end

  local _item = item --luacheck: ignore 311
  if item_type == "string" then
    _item = util.table.deepcopy(data.raw.item[item])
  else
    _item = util.table.deepcopy(item)
    _item.type = "item"
  end

  --- @cast _item data.ItemPrototype
  --- @type khaoslib.ItemManipulator
  local obj = {item = _item}
  setmetatable(obj, self)
  self.__index = self

  return obj
end

--- @diagnostic disable: invisible

--- Internal helper function to resolve the item from a string, item prototype data or a item manipulation object.
--- @param item data.ItemID|data.ItemPrototype|khaoslib.ItemManipulator The item to resolve.
--- @return data.ItemPrototype resolved_item The resolved item prototype.
--- @throws If the item cannot be resolved.
local resolve = function(item)
  if type(item) == "string" then
    local result = data.raw.item[item]
    if not result then
      error("No such item: " .. item, 3)
    end

    return result
  elseif type(item) == "table" then
    if getmetatable(item) == khaoslib_item and item.item then
      return item.item
    elseif item.type == "item" and item.name then
      return item --[[@as data.ItemPrototype]]
    else
      error("Invalid item table: expected manipulator or prototype with type='item' and name", 3)
    end
  else
    error("Invalid item parameter: expected item name, prototype table, or item manipulator", 3)
  end
end

--- @diagnostic enable: invisible

--- Gets the raw data table of the item.
--- @return data.ItemPrototype item A deep copy of the item data.
--- @nodiscard
function khaoslib_item:get()
  return util.table.deepcopy(self.item) --[[@as data.ItemPrototype]]
end

--- Merges the given fields into the item.
--- @param fields table A table of fields to merge into the item. See `data.ItemPrototype` for valid fields.
--- @return khaoslib.ItemManipulator self The same item manipulation object for method chaining.
--- @throws If fields is not a table or if it contains a name field.
function khaoslib_item:set(fields)
  if type(fields) ~= "table" then error("fields parameter: Expected table, got " .. type(fields), 2) end
  if fields.type then error("Cannot change the type of an item.", 2) end
  if fields.name then error("Cannot change the name of an item using set(). Use copy() to create a new item with a different name.", 2) end

  self.item = util.merge({self.item, fields})

  return self
end

--- Unsets the given field in the item currently being manipulated.
--- @param field string The field to unset in the item. See `data.ItemPrototype` for valid fields.
--- @return khaoslib.ItemManipulator self The same item manipulation object for method chaining.
--- @throws If field is not a string, or if it is the type or name field.
function khaoslib_item:unset(field)
  if type(field) ~= "string" then error("field parameter: Expected string, got " .. type(field), 2) end
  if field == "type" then error("Cannot unset the type of an item.", 2) end
  if field == "name" then error("Cannot unset the name of an item.", 2) end

  self.item[field] = nil

  return self
end

--- Creates a deep copy of the item.
--- @param item data.ItemID|data.ItemPrototype|khaoslib.ItemManipulator The item.
--- @param new_name data.ItemID The name of the new item. Must not already exist.
--- @return khaoslib.ItemManipulator item A new item manipulation object with a deep copy of the item.
--- @throws If an item with the new name already exists.
--- @nodiscard
function khaoslib_item.copy(item, new_name)
  local copy = util.table.deepcopy(resolve(item))
  copy.name = new_name

  return khaoslib_item:load(copy)
end

--- Commits the changes to the data stage.
--- If the item already exists, it is overwritten.
--- @return khaoslib.ItemManipulator self The same item manipulation object for method chaining.
function khaoslib_item:commit()
  self:remove()
  data:extend({self:get()})

  return self
end

--- Deletes the item from the data stage instantly. Use with caution, as this works without a commit.
--- @return khaoslib.ItemManipulator self The same item manipulation object for method chaining.
function khaoslib_item:remove()
  data.raw.item[self.item.name] = nil

  return self
end

--- Merges another item manipulation object into this one, excluding the name field.
--- @param other khaoslib.ItemManipulator The other item manipulation object to merge into this one
--- @return khaoslib.ItemManipulator self The same item manipulation object for method chaining.
--- @throws If other is not an item manipulation object.
function khaoslib_item:__add(other)
  if type(other) ~= "table" or getmetatable(other) ~= khaoslib_item then
    error("Can only concatenate with another khaoslib.ItemManipulator object", 2)
  end

  local other_copy = other:get()
  other_copy.type = nil
  other_copy.name = nil

  return self:set(other_copy)
end

--- Compares two item manipulation objects for equality based on the item name.
--- @param other khaoslib.ItemManipulator The other item manipulation object to compare with.
--- @return boolean is_equal True if the two item manipulation objects represent the same item, false otherwise.
function khaoslib_item:__eq(other)
  if type(other) ~= "table" or getmetatable(other) ~= khaoslib_item then return false end

  return self.item.name == other.item.name
end

--- Returns a string representation of the item manipulation object.
--- @return string representation A string representation of the item manipulation object.
function khaoslib_item:__tostring()
  return "[khaoslib_item: " .. self.item.name .. "]"
end

--#endregion

--#region Item manipulation methods
-- A set of utility functions for manipulating items.

--- If the item has a single icon, it is converted to the icons list format. If the item already has an icons list, no changes are made.
--- @param item data.ItemPrototype The item reference to populate icons for.
local populate_icons = function(item)
  if item.icon and (not item.icons or #item.icons == 0) then
    item.icons = {{icon = item.icon, icon_size = item.icon_size or nil}}
    item.icon = nil
    item.icon_size = nil
  end
end

--- If just a single item exists in the icons list, and it has no special properties, depopulate the icons list and set the icon and icon_size fields instead.
--- @param item data.ItemPrototype The item reference to depopulate icons from.
local depopulate_icons = function(item)
  if #item.icons == 1 then
    local icon = item.icons[1]
    if icon.tint == nil and icon.shift == nil and icon.scale == nil and icon.draw_background == nil and icon.floating == nil then
      item.icon = icon.icon
      item.icon_size = icon.icon_size or nil
      item.icons = nil
    end
  end
end

--- Returns a deepcopy of all icons for the given item. If the item has a single icon, it is returned as a single-element list.
--- @param item data.ItemID|data.ItemPrototype|khaoslib.ItemManipulator The item.
--- @return data.IconData[] icons A list of icons for the item.
--- @nodiscard
function khaoslib_item.get_icons(item)
  local resolved_item = resolve(item)
  if resolved_item.icon then
    return util.table.deepcopy({{icon = resolved_item.icon, icon_size = resolved_item.icon_size or nil}})
  elseif resolved_item.icons then
    return util.table.deepcopy(resolved_item.icons --[=[@as data.IconData[]]=])
  else
    return {}
  end
end

--- Sets the list of icons for the item currently being manipulated, replacing any existing icons.
--- @param icons data.IconData[] A list of icons to set.
--- @return khaoslib.ItemManipulator self The same item manipulation object for method chaining.
--- @throws If icons is not a table.
function khaoslib_item:set_icons(icons)
  if type(icons) ~= "table" then error("icons parameter: Expected table, got " .. type(icons), 2) end

  self.item.icon = nil
  self.item.icon_size = nil
  self.item.icons = util.table.deepcopy(icons)
  depopulate_icons(self.item)

  return self
end

--- Returns the number of icons for the given item.
--- @param item data.ItemID|data.ItemPrototype|khaoslib.ItemManipulator The item.
--- @return integer count The number of icons.
--- @nodiscard
function khaoslib_item.count_icons(item)
  local resolved_item = resolve(item)
  return resolved_item.icon ~= nil and 1 or #(resolved_item.icons or {})
end

--- Checks if the item has an icon matching the given criteria.
--- Supports both string matching (by icon filename) and custom comparison functions.
--- @param item data.ItemID|data.ItemPrototype|khaoslib.ItemManipulator The item.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @return boolean has_icon True if the item has the icon, false otherwise.
--- @throws If compare is not a string or function.
--- @nodiscard
function khaoslib_item.has_icon(item, compare)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  local resolved_item = resolve(item)
  populate_icons(resolved_item)

  local result = khaoslib_list.has(resolved_item.icons, compare_fn)
  depopulate_icons(resolved_item)

  return result
end

--- Adds an icon to the item, allows duplicates.
--- @param icon data.IconData The icon data to add.
--- @return khaoslib.ItemManipulator self The same item manipulation object for method chaining.
--- @throws If icon is not a table or doesn't have required fields.
function khaoslib_item:add_icon(icon)
  if type(icon) ~= "table" then error("icon parameter: Expected table, got " .. type(icon), 2) end
  if not icon.icon or type(icon.icon) ~= "string" then error("icon parameter: Must have an icon field of type string", 2) end

  populate_icons(self.item)
  self.item.icons = khaoslib_list.add(self.item.icons, icon, nil, {allow_duplicates = true})
  depopulate_icons(self.item)

  return self
end

--- Removes matching icons from the item.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @param options ListRemoveOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, removes all matching icons instead of just the first.
--- @return khaoslib.ItemManipulator self The same item manipulation object for method chaining.
--- @throws If compare is not a string or function.
function khaoslib_item:remove_icon(compare, options)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  populate_icons(self.item)
  self.item.icons = khaoslib_list.remove(self.item.icons, compare_fn, options)
  depopulate_icons(self.item)

  return self
end

--- Replaces matching icons with a new icon.
--- If no matching icons are found, no changes are made.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @param replacement (fun(icon: data.IconData): data.IconData)|data.IconData The new icon data to replace with.
--- @param options ListReplaceOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, replaces all matching icons instead of just the first.
--- @return khaoslib.ItemManipulator self The same item manipulation object for method chaining.
--- @throws If compare is not a string or function, or replacement is not a table or function.
function khaoslib_item:replace_icon(compare, replacement, options)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  if type(replacement) ~= "table" and type(replacement) ~= "function" then error("replacement parameter: Expected table or function, got " .. type(replacement), 2) end
  if type(replacement) == "table" then
    if not replacement.icon or type(replacement.icon) ~= "string" then error("replacement parameter: Must have an icon field of type string", 2) end
  end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  populate_icons(self.item)
  self.item.icons = khaoslib_list.replace(self.item.icons, replacement, compare_fn, options)
  depopulate_icons(self.item)

  return self
end

--- Removes all icons from the item.
--- @return khaoslib.ItemManipulator self The same item manipulation object for method chaining.
function khaoslib_item:clear_icons()
  self.item.icon = nil
  self.item.icon_size = nil
  self.item.icons = nil

  return self
end

--#endregion

--#region Utility functions
-- Module-level utility functions for item discovery and analysis.

--- Checks if an item exists in the data stage.
--- @param name data.ItemID The item name to check.
--- @return boolean exists True if the item exists, false otherwise.
--- @nodiscard
function khaoslib_item.exists(name)
  if type(name) ~= "string" then error("name parameter: Expected string, got " .. type(name), 2) end

  return data.raw.item[name] ~= nil
end

--- Finds all items that match a custom compare function.
--- @param compare_fn fun(item: data.ItemPrototype): boolean A function that returns true for items to include.
--- @return data.ItemID[] items A list of item names that match the compare function.
--- @throws If compare_fn is not a function.
--- @nodiscard
function khaoslib_item.find(compare_fn)
  if type(compare_fn) ~= "function" then error("compare_fn parameter: Expected function, got " .. type(compare_fn), 2) end

  local result = {}
  for _, item in pairs(data.raw.item or {}) do
    if compare_fn(item) then
      table.insert(result, item.name)
    end
  end

  return result
end

--#endregion

return khaoslib_item
