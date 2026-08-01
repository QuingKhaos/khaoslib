local khaoslib_list = require("__khaoslib__.common.list")

--#region Basic manipulation methods
-- A set of basic methods for creating and working with fluid manipulation objects.

--- Fluid manipulation utilities for Factorio data stage.
---
--- This module provides a fluent API for creating, modifying, and managing fluid prototypes
--- during the data stage. It supports method chaining and uses the list utility module for
--- consistent prerequisite and effect manipulation.
--- @class khaoslib.FluidManipulator
--- @field private fluid data.FluidPrototype The fluid currently being manipulated.
--- @operator add(khaoslib.FluidManipulator): khaoslib.FluidManipulator
local khaoslib_fluid = {}

--- Loads a given fluid for manipulation or creates a new one if a table is passed.
--- @param fluid data.FluidID|data.FluidPrototype The name of an existing fluid or a new fluid prototype table.
--- @return khaoslib.FluidManipulator manipulator A fluid manipulation object for the given fluid.
--- @throws If the fluid name doesn't exist or if a table is passed with a name that already exists or without a valid name field.
function khaoslib_fluid:load(fluid)
  local fluid_type = type(fluid)
  if fluid_type ~= "string" and fluid_type ~= "table" then error("fluid parameter: Expected string or table , got " .. fluid_type, 2) end

  if fluid_type == "string" then
    if not khaoslib_fluid.exists(fluid) then error("No such fluid: " .. fluid, 2) end
  else -- fluid_type == "table"
    if fluid.type and type(fluid.type) ~= "string" then error("fluid table type field should be a string if set", 2) end
    if fluid.type and fluid.type ~= "fluid" then error("fluid table type field should be 'fluid' if set", 2) end
    if not fluid.name or type(fluid.name) ~= "string" then error("fluid table must have a name field of type string", 2) end
    if khaoslib_fluid.exists(fluid.name) then error("A fluid with the name " .. fluid.name .. " already exists", 2) end
  end

  local _fluid = fluid --luacheck: ignore 311
  if fluid_type == "string" then
    _fluid = util.table.deepcopy(data.raw.fluid[fluid])
  else
    _fluid = util.table.deepcopy(fluid)
    _fluid.type = "fluid"
  end

  --- @diagnostic disable-next-line: missing-fields
  --- @cast _fluid data.FluidPrototype
  --- @type khaoslib.FluidManipulator
  local obj = {fluid = _fluid}
  setmetatable(obj, self)
  self.__index = self

  return obj
end

--- Internal helper function to resolve the fluid from a string, fluid prototype data or a fluid manipulation object.
--- @param fluid data.ItemID|data.FluidPrototype|khaoslib.FluidManipulator The fluid to resolve.
--- @return data.FluidPrototype resolved_fluid The resolved fluid prototype.
--- @throws If the fluid cannot be resolved.
local resolve = function(fluid)
  if type(fluid) == "string" then
    local result = data.raw.fluid[fluid]
    if not result then
      error("No such fluid: " .. fluid, 3)
    end

    return result
  elseif type(fluid) == "table" then
    --- @diagnostic disable: access-invisible
    if getmetatable(fluid) == khaoslib_fluid and fluid.fluid then
      return fluid.fluid
    elseif fluid.type == "fluid" and fluid.name then
      return fluid --[[@as data.FluidPrototype]]
    else
      error("Invalid fluid table: expected manipulator or prototype with type='fluid' and name", 3)
    end
    --- @diagnostic enable: access-invisible
  else
    error("Invalid fluid parameter: expected fluid name, prototype table, or fluid manipulator", 3)
  end
end


--- Gets the raw data table of the fluid.
--- @param fluid data.ItemID|data.FluidPrototype|khaoslib.FluidManipulator The fluid.
--- @return data.FluidPrototype fluid A deep copy of the fluid data.
--- @nodiscard
function khaoslib_fluid.get(fluid)
  return util.table.deepcopy(resolve(fluid)) --[[@as data.FluidPrototype]]
end

--- @class khaoslib_fluid.FluidPrototype : data.FluidPrototype
--- @field type? string
--- @field name? string
--- @field stack_size? data.ItemCountType

--- Merges the given fields into the fluid.
--- @param fields khaoslib_fluid.FluidPrototype A table of fields to merge into the fluid. See `data.FluidPrototype` for valid fields.
--- @return khaoslib.FluidManipulator self The same fluid manipulation object for method chaining.
--- @throws If fields is not a table or if it contains a name field.
function khaoslib_fluid:set(fields)
  if type(fields) ~= "table" then error("fields parameter: Expected table, got " .. type(fields), 2) end
  if fields.type then error("Cannot change the type of a fluid.", 2) end
  if fields.name then error("Cannot change the name of a fluid using set(). Use copy() to create a new fluid with a different name.", 2) end

  self.fluid = util.merge({self.fluid, util.table.deepcopy(fields)})

  return self
end

--- Unsets the given field in the fluid currently being manipulated.
--- @param field string The field to unset in the fluid. See `data.FluidPrototype` for valid fields.
--- @return khaoslib.FluidManipulator self The same fluid manipulation object for method chaining.
--- @throws If field is not a string, or if it is the type or name field.
function khaoslib_fluid:unset(field)
  if type(field) ~= "string" then error("field parameter: Expected string, got " .. type(field), 2) end
  if field == "type" then error("Cannot unset the type of a fluid.", 2) end
  if field == "name" then error("Cannot unset the name of a fluid.", 2) end

  --- @diagnostic disable-next-line: undefined-field
  local fields_iter = field:gmatch("[^%.]+")
  local current = self.fluid
  local idx = 0
  local field_part = fields_iter()
  while field_part do
    idx = idx + 1
    if current[field_part] == nil then
      return self -- Field doesn't exist, nothing to unset
    end

    local next_field_part = fields_iter()
    if not next_field_part then
      current[field_part] = nil
    else
      if type(current[field_part]) ~= "table" then
        error("Cannot unset field '" .. field .. "' because '" .. tostring(current[field_part]) .. "' is not a table.", 2)
      end
    end

    current = current[field_part]
    field_part = next_field_part
  end

  return self
end

--- Creates a deep copy of the fluid.
--- @param fluid data.ItemID|data.FluidPrototype|khaoslib.FluidManipulator The fluid.
--- @param new_name data.ItemID The name of the new fluid. Must not already exist.
--- @return khaoslib.FluidManipulator fluid A new fluid manipulation object with a deep copy of the fluid.
--- @throws If a fluid with the new name already exists.
--- @nodiscard
function khaoslib_fluid.copy(fluid, new_name)
  local copy = util.table.deepcopy(resolve(fluid))
  copy.name = new_name

  return khaoslib_fluid:load(copy)
end

--- Commits the changes to the data stage.
--- If the fluid already exists, it is overwritten.
--- @return khaoslib.FluidManipulator self The same fluid manipulation object for method chaining.
function khaoslib_fluid:commit()
  self:remove()
  data:extend({self:get()})

  return self
end

--- Deletes the fluid from the data stage instantly. Use with caution, as this works without a commit.
--- @param fluid data.ItemID|data.FluidPrototype The fluid.
--- @return khaoslib.FluidManipulator? manipulator The same fluid manipulation object for method chaining, or nil if the fluid was not a manipulation object.
--- @overload fun(fluid: data.ItemID|data.FluidPrototype)
--- @overload fun(self: khaoslib.FluidManipulator): khaoslib.FluidManipulator
function khaoslib_fluid.remove(fluid)
  data.raw.fluid[resolve(fluid).name] = nil

  if type(fluid) == "table" and getmetatable(fluid) == khaoslib_fluid then
    return fluid --[[@as khaoslib.FluidManipulator]]
  end
end

--- Merges another fluid manipulation object into this one, excluding the name field.
--- @param other khaoslib.FluidManipulator The other fluid manipulation object to merge into this one
--- @return khaoslib.FluidManipulator self The same fluid manipulation object for method chaining.
--- @throws If other is not a fluid manipulation object.
function khaoslib_fluid:__add(other)
  if type(other) ~= "table" or getmetatable(other) ~= khaoslib_fluid then
    error("Can only concatenate with another khaoslib.FluidManipulator object", 2)
  end

  local other_copy = other:get()
  other_copy.type = nil
  other_copy.name = nil

  return self:set(other_copy --[[@as khaoslib_fluid.FluidPrototype]])
end

--- Compares two fluid manipulation objects for equality based on the fluid name.
--- @param other khaoslib.FluidManipulator The other fluid manipulation object to compare with.
--- @return boolean is_equal True if the two fluid manipulation objects represent the same fluid, false otherwise.
function khaoslib_fluid:__eq(other)
  if type(other) ~= "table" or getmetatable(other) ~= khaoslib_fluid then return false end

  return self.fluid.name == other.fluid.name
end

--- Returns a string representation of the fluid manipulation object.
--- @return string representation A string representation of the fluid manipulation object.
function khaoslib_fluid:__tostring()
  return "[khaoslib_fluid: " .. self.fluid.name .. "]"
end

--#endregion

--#region Fluid manipulation methods
-- A set of utility functions for manipulating fluids.

--- If the fluid has a single icon, it is converted to the icons list format. If the fluid already has an icons list, no changes are made.
--- @param fluid data.FluidPrototype The fluid reference to populate icons for.
local populate_icons = function(fluid)
  if fluid.icon and (not fluid.icons or #fluid.icons == 0) then
    fluid.icons = {{icon = fluid.icon, icon_size = fluid.icon_size or nil}}
    fluid.icon = nil
    fluid.icon_size = nil
  end
end

--- If just a single fluid exists in the icons list, and it has no special properties, depopulate the icons list and set the icon and icon_size fields instead.
--- @param fluid data.FluidPrototype The fluid reference to depopulate icons from.
local depopulate_icons = function(fluid)
  if fluid.icons and #fluid.icons == 1 then
    local icon = fluid.icons[1]
    if icon.tint == nil and icon.shift == nil and icon.scale == nil and icon.draw_background == nil and icon.floating == nil then
      fluid.icon = icon.icon
      fluid.icon_size = icon.icon_size or nil
      fluid.icons = nil
    end
  end
end

--- Returns a deepcopy of all icons for the given fluid. If the fluid has a single icon, it is returned as a single-element list.
--- @param fluid data.ItemID|data.FluidPrototype|khaoslib.FluidManipulator The fluid.
--- @return data.IconData[] icons A list of icons for the fluid.
--- @nodiscard
function khaoslib_fluid.get_icons(fluid)
  local resolved_fluid = resolve(fluid)
  if resolved_fluid.icons then
    return util.table.deepcopy(resolved_fluid.icons --[=[@as data.IconData[] ]=])
  elseif resolved_fluid.icon then
    return util.table.deepcopy({{icon = resolved_fluid.icon, icon_size = resolved_fluid.icon_size or nil}})
  else
    return {}
  end
end

--- Returns a deep-copied list of all icons for the given fluid that match the given criteria.
--- @param fluid data.ItemID|data.FluidPrototype|khaoslib.FluidManipulator The fluid.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @return data.IconData[] icons A list of matching icons.
--- @throws If compare is not a string or function.
--- @nodiscard
function khaoslib_fluid.find_icons(fluid, compare)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  local resolved_fluid = resolve(fluid)
  populate_icons(resolved_fluid)

  local result = khaoslib_list.find(resolved_fluid.icons, compare_fn)
  depopulate_icons(resolved_fluid)

  return result
end

--- Sets the list of icons for the fluid currently being manipulated, replacing any existing icons.
--- @param icons data.IconData[] A list of icons to set.
--- @return khaoslib.FluidManipulator self The same fluid manipulation object for method chaining.
--- @throws If icons is not a table.
function khaoslib_fluid:set_icons(icons)
  if type(icons) ~= "table" then error("icons parameter: Expected table, got " .. type(icons), 2) end

  self.fluid.icon = nil
  self.fluid.icon_size = nil
  self.fluid.icons = util.table.deepcopy(icons)
  depopulate_icons(self.fluid)

  return self
end

--- Returns the number of icons for the given fluid.
--- @param fluid data.ItemID|data.FluidPrototype|khaoslib.FluidManipulator The fluid.
--- @return integer count The number of icons.
--- @nodiscard
function khaoslib_fluid.count_icons(fluid)
  local resolved_fluid = resolve(fluid)
  return resolved_fluid.icon ~= nil and 1 or #(resolved_fluid.icons or {})
end

--- Checks if the fluid has an icon matching the given criteria.
--- Supports both string matching (by icon filename) and custom comparison functions.
--- @param fluid data.ItemID|data.FluidPrototype|khaoslib.FluidManipulator The fluid.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @return boolean has_icon True if the fluid has the icon, false otherwise.
--- @throws If compare is not a string or function.
--- @nodiscard
function khaoslib_fluid.has_icon(fluid, compare)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  local resolved_fluid = resolve(fluid)
  populate_icons(resolved_fluid)

  local result = khaoslib_list.has(resolved_fluid.icons, compare_fn)
  depopulate_icons(resolved_fluid)

  return result
end

--- Gets the first icon (deep-copy) that matches the given criteria.
--- Supports both string matching (by icon filename) and custom comparison functions.
--- @param fluid data.ItemID|data.FluidPrototype|khaoslib.FluidManipulator The fluid.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @return data.IconData? icon The first matching icon, or nil if no match is found.
--- @throws If compare is not a string or function.
--- @nodiscard
function khaoslib_fluid.get_icon(fluid, compare)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  local resolved_fluid = resolve(fluid)
  populate_icons(resolved_fluid)

  local result = khaoslib_list.get(resolved_fluid.icons, compare_fn)
  depopulate_icons(resolved_fluid)

  return result
end

--- Adds an icon to the fluid, allows duplicates.
--- @param icon data.IconData The icon data to add.
--- @param options ListAddIndexOptions? Options table with fields:
---   - `index` (integer, optional): If provided, inserts the icon at the specified index instead of appending to the end of the list.
--- @return khaoslib.FluidManipulator self The same fluid manipulation object for method chaining.
--- @throws If icon is not a table or doesn't have required fields.
function khaoslib_fluid:add_icon(icon, options)
  if type(icon) ~= "table" then error("icon parameter: Expected table, got " .. type(icon), 2) end
  if not icon.icon or type(icon.icon) ~= "string" then error("icon parameter: Must have an icon field of type string", 2) end

  options = options or {}
  --- @cast options ListAddOptions
  options.allow_duplicates = true

  populate_icons(self.fluid)
  self.fluid.icons = khaoslib_list.add(self.fluid.icons, icon, nil, options)
  depopulate_icons(self.fluid)

  return self
end

--- Removes matching icons from the fluid.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @param options ListRemoveOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, removes all matching icons instead of just the first.
--- @return khaoslib.FluidManipulator self The same fluid manipulation object for method chaining.
--- @throws If compare is not a string or function.
function khaoslib_fluid:remove_icon(compare, options)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  populate_icons(self.fluid)
  self.fluid.icons = khaoslib_list.remove(self.fluid.icons, compare_fn, options)
  depopulate_icons(self.fluid)

  return self
end

--- Replaces matching icons with a new icon.
--- If no matching icons are found, no changes are made.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @param replacement (fun(icon: data.IconData): data.IconData)|data.IconData The new icon data to replace with.
--- @param options ListReplaceOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, replaces all matching icons instead of just the first.
--- @return khaoslib.FluidManipulator self The same fluid manipulation object for method chaining.
--- @throws If compare is not a string or function, or replacement is not a table or function.
function khaoslib_fluid:replace_icon(compare, replacement, options)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  if type(replacement) ~= "table" and type(replacement) ~= "function" then error("replacement parameter: Expected table or function, got " .. type(replacement), 2) end
  if type(replacement) == "table" then
    if not replacement.icon or type(replacement.icon) ~= "string" then error("replacement parameter: Must have an icon field of type string", 2) end
  end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  populate_icons(self.fluid)
  --- @diagnostic disable-next-line: assign-type-mismatch, param-type-mismatch
  self.fluid.icons = khaoslib_list.replace(self.fluid.icons, replacement, compare_fn, options)
  depopulate_icons(self.fluid)

  return self
end

--- Removes all icons from the fluid.
--- @return khaoslib.FluidManipulator self The same fluid manipulation object for method chaining.
function khaoslib_fluid:clear_icons()
  self.fluid.icon = nil
  self.fluid.icon_size = nil
  self.fluid.icons = nil

  return self
end

--#endregion

--#region Utility functions
-- Module-level utility functions for fluid discovery and analysis.

--- Checks if a fluid exists in the data stage.
--- @param name data.ItemID The fluid name to check.
--- @return boolean exists True if the fluid exists, false otherwise.
--- @nodiscard
function khaoslib_fluid.exists(name)
  if type(name) ~= "string" then error("name parameter: Expected string, got " .. type(name), 2) end

  return data.raw.fluid[name] ~= nil
end

--- Finds all fluids that match a custom compare function.
--- @param compare_fn fun(fluid: data.FluidPrototype): boolean A function that returns true for fluids to include.
--- @return data.ItemID[] fluids A list of fluid names that match the compare function.
--- @throws If compare_fn is not a function.
--- @nodiscard
function khaoslib_fluid.find(compare_fn)
  if type(compare_fn) ~= "function" then error("compare_fn parameter: Expected function, got " .. type(compare_fn), 2) end

  local result = {}
  for _, fluid in pairs(data.raw.fluid or {}) do
    if compare_fn(fluid) then
      table.insert(result, fluid.name)
    end
  end

  return result
end

--#endregion

return khaoslib_fluid
