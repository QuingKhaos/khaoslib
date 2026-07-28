local khaoslib_ammo_type = require("__khaoslib__.prototypes.ammo-type")
local khaoslib_list = require("__khaoslib__.common.list")

--#region Basic manipulation methods
-- A set of basic methods for creating and working with ammo manipulation objects.

--- Ammo manipulation utilities for Factorio data stage.
---
--- This module provides a fluent API for creating, modifying, and managing ammo prototypes
--- during the data stage. It supports method chaining and uses the list utility module for
--- consistent prerequisite and effect manipulation.
--- @class khaoslib.AmmoManipulator
--- @field private ammo data.AmmoItemPrototype The ammo currently being manipulated.
--- @operator add(khaoslib.AmmoManipulator): khaoslib.AmmoManipulator
local khaoslib_ammo = {}

--- Loads a given ammo for manipulation or creates a new one if a table is passed.
--- @param ammo data.ItemID|data.AmmoItemPrototype The name of an existing ammo or a new ammo prototype table.
--- @return khaoslib.AmmoManipulator manipulator An ammo manipulation object for the given ammo.
--- @throws If the ammo name doesn't exist or if a table is passed with a name that already exists or without a valid name field.
function khaoslib_ammo:load(ammo)
  local ammo_type = type(ammo)
  if ammo_type ~= "string" and ammo_type ~= "table" then error("ammo parameter: Expected string or table , got " .. ammo_type, 2) end

  if ammo_type == "string" then
    if not khaoslib_ammo.exists(ammo) then error("No such ammo: " .. ammo, 2) end
  else -- ammo_type == "table"
    if ammo.type and type(ammo.type) ~= "string" then error("ammo table type field should be a string if set", 2) end
    if ammo.type and ammo.type ~= "ammo" then error("ammo table type field should be 'ammo' if set", 2) end
    if not ammo.name or type(ammo.name) ~= "string" then error("ammo table must have a name field of type string", 2) end
    if khaoslib_ammo.exists(ammo.name) then error("An ammo with the name " .. ammo.name .. " already exists", 2) end
  end

  local _ammo = ammo --luacheck: ignore 311
  if ammo_type == "string" then
    _ammo = util.table.deepcopy(data.raw["ammo"][ammo])
  else
    _ammo = util.table.deepcopy(ammo)
    _ammo.type = "ammo"
  end

  --- @diagnostic disable-next-line: missing-fields
  --- @cast _ammo data.AmmoItemPrototype
  --- @type khaoslib.AmmoManipulator
  local obj = {ammo = _ammo}
  setmetatable(obj, self)
  self.__index = self

  return obj
end

--- Internal helper function to resolve the ammo from a string, ammo prototype data or an ammo manipulation object.
--- @param ammo data.ItemID|data.AmmoItemPrototype|khaoslib.AmmoManipulator The ammo to resolve.
--- @return data.AmmoItemPrototype resolved_ammo The resolved ammo prototype.
--- @throws If the ammo cannot be resolved.
local resolve = function(ammo)
  if type(ammo) == "string" then
    local result = data.raw["ammo"][ammo]
    if not result then
      error("No such ammo: " .. ammo, 3)
    end

    return result
  elseif type(ammo) == "table" then
    --- @diagnostic disable: access-invisible
    if getmetatable(ammo) == khaoslib_ammo and ammo.ammo then
      return ammo.ammo
    elseif ammo.type == "ammo" and ammo.name then
      return ammo --[[@as data.AmmoItemPrototype]]
    else
      error("Invalid ammo table: expected manipulator or prototype with type='ammo' and name", 3)
    end
    --- @diagnostic enable: access-invisible
  else
    error("Invalid ammo parameter: expected ammo name, prototype table, or ammo manipulator", 3)
  end
end

--- Gets the raw data table of the ammo.
--- @param ammo data.ItemID|data.AmmoItemPrototype|khaoslib.AmmoManipulator The ammo.
--- @return data.AmmoItemPrototype ammo A deep copy of the ammo data.
--- @nodiscard
function khaoslib_ammo.get(ammo)
  return util.table.deepcopy(resolve(ammo)) --[[@as data.AmmoItemPrototype]]
end

--- @class khaoslib_ammo.AmmoItemPrototype : data.AmmoItemPrototype
--- @field type? string
--- @field name? string
--- @field stack_size? data.ItemCountType
--- @field ammo_category? data.AmmoCategoryID
--- @field ammo_type? data.AmmoType|data.AmmoType[]

--- Merges the given fields into the ammo.
--- @param fields khaoslib_ammo.AmmoItemPrototype A table of fields to merge into the ammo. See `data.AmmoItemPrototype` for valid fields.
--- @return khaoslib.AmmoManipulator self The same ammo manipulation object for method chaining.
--- @throws If fields is not a table or if it contains a name field.
function khaoslib_ammo:set(fields)
  if type(fields) ~= "table" then error("fields parameter: Expected table, got " .. type(fields), 2) end
  if fields.type then error("Cannot change the type of an ammo.", 2) end
  if fields.name then error("Cannot change the name of an ammo using set(). Use copy() to create a new ammo with a different name.", 2) end

  self.ammo = util.merge({self.ammo, util.table.deepcopy(fields)})

  return self
end

--- Unsets the given field in the ammo currently being manipulated.
--- @param field string The field to unset in the ammo. See `data.AmmoItemPrototype` for valid fields.
--- @return khaoslib.AmmoManipulator self The same ammo manipulation object for method chaining.
--- @throws If field is not a string, or if it is the type or name field.
function khaoslib_ammo:unset(field)
  if type(field) ~= "string" then error("field parameter: Expected string, got " .. type(field), 2) end
  if field == "type" then error("Cannot unset the type of an ammo.", 2) end
  if field == "name" then error("Cannot unset the name of an ammo.", 2) end

  self.ammo[field] = nil

  return self
end

--- Creates a deep copy of the ammo.
--- @param ammo data.ItemID|data.AmmoItemPrototype|khaoslib.AmmoManipulator The ammo.
--- @param new_name data.ItemID The name of the new ammo. Must not already exist.
--- @return khaoslib.AmmoManipulator ammo A new ammo manipulation object with a deep copy of the ammo.
--- @throws If an ammo with the new name already exists.
--- @nodiscard
function khaoslib_ammo.copy(ammo, new_name)
  local copy = util.table.deepcopy(resolve(ammo))
  copy.name = new_name

  return khaoslib_ammo:load(copy)
end

--- Commits the changes to the data stage.
--- If the ammo already exists, it is overwritten.
--- @return khaoslib.AmmoManipulator self The same ammo manipulation object for method chaining.
function khaoslib_ammo:commit()
  self:remove()
  data:extend({self:get()})

  return self
end

--- Deletes the ammo from the data stage instantly. Use with caution, as this works without a commit.
--- @param ammo data.ItemID|data.AmmoItemPrototype The ammo.
--- @return khaoslib.AmmoManipulator? self The same ammo manipulation object if used on manipulation object or nil if used on a string or prototype.
--- @overload fun(item: data.ItemID|data.AmmoItemPrototype)
--- @overload fun(self: khaoslib.AmmoManipulator): khaoslib.AmmoManipulator
function khaoslib_ammo.remove(ammo)
  data.raw.ammo[resolve(ammo).name] = nil

  if type(ammo) == "table" and getmetatable(ammo) == khaoslib_ammo then
    return ammo --[[@as khaoslib.AmmoManipulator]]
  end
end

--- Merges another ammo manipulation object into this one, excluding the name field.
--- @param other khaoslib.AmmoManipulator The other ammo manipulation object to merge into this one
--- @return khaoslib.AmmoManipulator self The same ammo manipulation object for method chaining.
--- @throws If other is not an ammo manipulation object.
function khaoslib_ammo:__add(other)
  if type(other) ~= "table" or getmetatable(other) ~= khaoslib_ammo then
    error("Can only concatenate with another khaoslib.AmmoManipulator object", 2)
  end

  local other_copy = other:get()
  other_copy.type = nil
  other_copy.name = nil

  return self:set(other_copy --[[@as khaoslib_ammo.AmmoItemPrototype]])
end

--- Compares two ammo manipulation objects for equality based on the ammo name.
--- @param other khaoslib.AmmoManipulator The other ammo manipulation object to compare with.
--- @return boolean is_equal True if the two ammo manipulation objects represent the same ammo, false otherwise.
function khaoslib_ammo:__eq(other)
  if type(other) ~= "table" or getmetatable(other) ~= khaoslib_ammo then return false end

  return self.ammo.name == other.ammo.name
end

--- Returns a string representation of the ammo manipulation object.
--- @return string representation A string representation of the ammo manipulation object.
function khaoslib_ammo:__tostring()
  return "[khaoslib_ammo: " .. self.ammo.name .. "]"
end

--#endregion

--#region Ammo manipulation methods
-- A set of utility functions for manipulating ammo.

--- If the ammo has a single icon, it is converted to the icons list format. If the ammo already has an icons list, no changes are made.
--- @param ammo data.AmmoItemPrototype The ammo reference to populate icons for.
local populate_icons = function(ammo)
  if ammo.icon and (not ammo.icons or #ammo.icons == 0) then
    ammo.icons = {{icon = ammo.icon, icon_size = ammo.icon_size or nil}}
    ammo.icon = nil
    ammo.icon_size = nil
  end
end

--- If just a single ammo exists in the icons list, and it has no special properties, depopulate the icons list and set the icon and icon_size fields instead.
--- @param ammo data.AmmoItemPrototype The ammo reference to depopulate icons from.
local depopulate_icons = function(ammo)
  if ammo.icons and #ammo.icons == 1 then
    local icon = ammo.icons[1]
    if icon.tint == nil and icon.shift == nil and icon.scale == nil and icon.draw_background == nil and icon.floating == nil then
      ammo.icon = icon.icon
      ammo.icon_size = icon.icon_size or nil
      ammo.icons = nil
    end
  end
end

--- Returns a deepcopy of all icons for the given ammo. If the ammo has a single icon, it is returned as a single-element list.
--- @param ammo data.ItemID|data.AmmoItemPrototype|khaoslib.AmmoManipulator The ammo.
--- @return data.IconData[] icons A list of icons for the ammo.
--- @nodiscard
function khaoslib_ammo.get_icons(ammo)
  local resolved_ammo = resolve(ammo)
  if resolved_ammo.icons then
    return util.table.deepcopy(resolved_ammo.icons --[[@as data.IconData[] ]])
  elseif resolved_ammo.icon then
    return util.table.deepcopy({{icon = resolved_ammo.icon, icon_size = resolved_ammo.icon_size or nil}})
  else
    return {}
  end
end

--- Returns a deep-copied list of all icons for the given ammo that match the given criteria.
--- @param ammo data.ItemID|data.AmmoItemPrototype|khaoslib.AmmoManipulator The ammo.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @return data.IconData[] icons A list of matching icons.
--- @throws If compare is not a string or function.
--- @nodiscard
function khaoslib_ammo.find_icons(ammo, compare)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  local resolved_ammo = resolve(ammo)
  populate_icons(resolved_ammo)

  local result = khaoslib_list.find(resolved_ammo.icons, compare_fn)
  depopulate_icons(resolved_ammo)

  return result
end

--- Sets the list of icons for the ammo currently being manipulated, replacing any existing icons.
--- @param icons data.IconData[] A list of icons to set.
--- @return khaoslib.AmmoManipulator self The same ammo manipulation object for method chaining.
--- @throws If icons is not a table.
function khaoslib_ammo:set_icons(icons)
  if type(icons) ~= "table" then error("icons parameter: Expected table, got " .. type(icons), 2) end

  self.ammo.icon = nil
  self.ammo.icon_size = nil
  self.ammo.icons = util.table.deepcopy(icons)
  depopulate_icons(self.ammo)

  return self
end

--- Returns the number of icons for the given ammo.
--- @param ammo data.ItemID|data.AmmoItemPrototype|khaoslib.AmmoManipulator The ammo.
--- @return integer count The number of icons.
--- @nodiscard
function khaoslib_ammo.count_icons(ammo)
  local resolved_ammo = resolve(ammo)
  return resolved_ammo.icon ~= nil and 1 or #(resolved_ammo.icons or {})
end

--- Checks if the ammo has an icon matching the given criteria.
--- Supports both string matching (by icon filename) and custom comparison functions.
--- @param ammo data.ItemID|data.AmmoItemPrototype|khaoslib.AmmoManipulator The ammo.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @return boolean has_icon True if the capsule has the icon, false otherwise.
--- @throws If compare is not a string or function.
--- @nodiscard
function khaoslib_ammo.has_icon(ammo, compare)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  local resolved_ammo = resolve(ammo)
  populate_icons(resolved_ammo)

  local result = khaoslib_list.has(resolved_ammo.icons, compare_fn)
  depopulate_icons(resolved_ammo)

  return result
end

--- Gets the first icon (deep-copy) that matches the given criteria.
--- Supports both string matching (by icon filename) and custom comparison functions.
--- @param ammo data.ItemID|data.AmmoItemPrototype|khaoslib.AmmoManipulator The ammo.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @return data.IconData? icon The first matching icon, or nil if no match is found.
--- @throws If compare is not a string or function.
--- @nodiscard
function khaoslib_ammo.get_icon(ammo, compare)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  local resolved_ammo = resolve(ammo)
  populate_icons(resolved_ammo)

  local result = khaoslib_list.get(resolved_ammo.icons, compare_fn)
  depopulate_icons(resolved_ammo)

  return result
end

--- Adds an icon to the ammo, allows duplicates.
--- @param icon data.IconData The icon data to add.
--- @param options ListAddIndexOptions? Options table with fields:
---   - `index` (integer, optional): If provided, inserts the icon at the specified index instead of appending to the end of the list.
--- @return khaoslib.AmmoManipulator self The same ammo manipulation object for method chaining.
function khaoslib_ammo:add_icon(icon, options)
  if type(icon) ~= "table" then error("icon parameter: Expected table, got " .. type(icon), 2) end
  if not icon.icon or type(icon.icon) ~= "string" then error("icon parameter: Must have an icon field of type string", 2) end

  options = options or {}
  --- @cast options ListAddOptions
  options.allow_duplicates = true

  populate_icons(self.ammo)
  self.ammo.icons = khaoslib_list.add(self.ammo.icons, icon, nil, options)
  depopulate_icons(self.ammo)

  return self
end

--- Removes matching icons from the ammo.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @param options ListRemoveOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, removes all matching icons instead of just the first.
--- @return khaoslib.AmmoManipulator self The same ammo manipulation object for method chaining.
function khaoslib_ammo:remove_icon(compare, options)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  populate_icons(self.ammo)
  self.ammo.icons = khaoslib_list.remove(self.ammo.icons, compare_fn, options)
  depopulate_icons(self.ammo)

  return self
end

--- Replaces matching icons with a new icon.
--- If no matching icons are found, no changes are made.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @param replacement (fun(icon: data.IconData): data.IconData)|data.IconData The new icon data to replace with.
--- @param options ListReplaceOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, replaces all matching icons instead of just the first.
--- @return khaoslib.AmmoManipulator self The same ammo manipulation object for method chaining.
--- @throws If compare is not a string or function, or replacement is not a table or function.
function khaoslib_ammo:replace_icon(compare, replacement, options)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  if type(replacement) ~= "table" and type(replacement) ~= "function" then error("replacement parameter: Expected table or function, got " .. type(replacement), 2) end
  if type(replacement) == "table" then
    if not replacement.icon or type(replacement.icon) ~= "string" then error("replacement parameter: Must have an icon field of type string", 2) end
  end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  populate_icons(self.ammo)
  --- @diagnostic disable-next-line: assign-type-mismatch, param-type-mismatch
  self.ammo.icons = khaoslib_list.replace(self.ammo.icons, replacement, compare_fn, options)
  depopulate_icons(self.ammo)

  return self
end

--- Removes all icons from the ammo.
--- @return khaoslib.AmmoManipulator self The same ammo manipulation object for method chaining.
function khaoslib_ammo:clear_icons()
  self.ammo.icon = nil
  self.ammo.icon_size = nil
  self.ammo.icons = nil

  return self
end

--- If the ammo has a single ammo type, it is converted to the list format. If the ammo already has an ammo type list, no changes are made.
--- @param ammo data.AmmoItemPrototype The ammo reference to populate the ammo type for.
local function populate_ammo_type(ammo)
  if ammo.ammo_type and (ammo.ammo_type.action ~= nil or ammo.ammo_type.clamp_position ~= nil or ammo.ammo_type.energy_consumption ~= nil or ammo.ammo_type.range_modifier ~= nil or ammo.ammo_type.cooldown_modifier ~= nil or ammo.ammo_type.consumption_modifier ~= nil or ammo.ammo_type.target_type ~= nil or ammo.ammo_type.source_type ~= nil or ammo.ammo_type.target_filter ~= nil) then
    ammo.ammo_type = {ammo.ammo_type}
  end
end

--- If just a single ammo type exists in the ammo type list, depopulate the list.
--- @param ammo data.AmmoItemPrototype The ammo reference to depopulate the ammo type from.
local function depopulate_ammo_type(ammo)
  if ammo.ammo_type and #ammo.ammo_type == 1 then
    ammo.ammo_type = ammo.ammo_type[1]
  end
end

--- Returns a deepcopy of all ammo types for the given ammo. If the ammo has a single ammo type, it is returned as a single-element list.
--- @param ammo data.ItemID|data.AmmoItemPrototype|khaoslib.AmmoManipulator The ammo.
--- @return khaoslib.AmmoTypeManipulator[] ammo_types A list of ammo types for the ammo.
--- @nodiscard
function khaoslib_ammo.get_ammo_types(ammo)
  local resolved_ammo = resolve(ammo)
  if resolved_ammo.ammo_type then
    populate_ammo_type(resolved_ammo)

    --- @type khaoslib.AmmoTypeManipulator[]
    local result = {}

    for _, ammo_type in ipairs(resolved_ammo.ammo_type) do
      table.insert(result, khaoslib_ammo_type:load(ammo_type))
    end

    depopulate_ammo_type(resolved_ammo)
    return result
  else
    return {}
  end
end

--- Returns a deep-copied list of all ammo types for the given ammo that match the given criteria.
--- @param ammo data.ItemID|data.AmmoItemPrototype|khaoslib.AmmoManipulator The ammo.
--- @param compare fun(ammo_type: data.AmmoType): boolean A comparison function
--- @return khaoslib.AmmoTypeManipulator[] ammo_types A list of matching ammo types.
--- @throws If compare is not a function.
--- @nodiscard
function khaoslib_ammo.find_ammo_types(ammo, compare)
  if type(compare) ~= "function" then error("compare parameter: Expected function, got " .. type(compare), 2) end

  local resolved_ammo = resolve(ammo)
  populate_ammo_type(resolved_ammo)

  --- @type khaoslib.AmmoTypeManipulator[]
  local result = {}
  local find_result = khaoslib_list.find(resolved_ammo.ammo_type --[[@as data.AmmoType[] ]], compare)

  for _, ammo_type in ipairs(find_result) do
    table.insert(result, khaoslib_ammo_type:load(ammo_type))
  end

  depopulate_ammo_type(resolved_ammo)
  return result
end

--- Sets the list of ammo types for the ammo currently being manipulated, replacing any existing ammo types.
--- @param ammo_types khaoslib.AmmoTypeManipulator[] A list of ammo types to set.
--- @return khaoslib.AmmoManipulator self The same ammo manipulation object for method chaining.
--- @throws If ammo_types is not a table.
function khaoslib_ammo:set_ammo_types(ammo_types)
  if type(ammo_types) ~= "table" then error("ammo_types parameter: Expected table, got " .. type(ammo_types), 2) end

  self.ammo.ammo_type = {}
  for _, ammo_type_manipulator in ipairs(ammo_types) do
    table.insert(self.ammo.ammo_type, ammo_type_manipulator:get())
  end

  depopulate_ammo_type(self.ammo)
  return self
end

--- Returns the number of ammo types for the given ammo.
--- @param ammo data.ItemID|data.AmmoItemPrototype|khaoslib.AmmoManipulator The ammo.
--- @return integer count The number of ammo types.
--- @nodiscard
function khaoslib_ammo.count_ammo_types(ammo)
  local resolved_ammo = resolve(ammo)
  if resolved_ammo.ammo_type then
    populate_ammo_type(resolved_ammo)
    local count = #resolved_ammo.ammo_type

    depopulate_ammo_type(resolved_ammo)
    return count
  else
    return 0
  end
end

--- Checks if the ammo has an ammo type matching the given criteria.
--- @param ammo data.ItemID|data.AmmoItemPrototype|khaoslib.AmmoManipulator The ammo.
--- @param compare fun(ammo_type: data.AmmoType): boolean A comparison function
--- @return boolean has_ammo_type True if the ammo has a matching ammo type, false otherwise.
--- @throws If compare is not a function.
--- @nodiscard
function khaoslib_ammo.has_ammo_type(ammo, compare)
  if type(compare) ~= "function" then error("compare parameter: Expected function, got " .. type(compare), 2) end

  local resolved_ammo = resolve(ammo)
  populate_ammo_type(resolved_ammo)

  local result = khaoslib_list.has(resolved_ammo.ammo_type --[[@as data.AmmoType[] ]], compare)
  depopulate_ammo_type(resolved_ammo)

  return result
end

--- Gets the first ammo type (deep-copy) that matches the given criteria.
--- @param ammo data.ItemID|data.AmmoItemPrototype|khaoslib.AmmoManipulator The ammo.
--- @param compare (fun(ammo_type: data.AmmoType): boolean) A comparison function
--- @return khaoslib.AmmoTypeManipulator? ammo_type The first matching ammo type, or nil if no match is found.
--- @throws If compare is not a function.
--- @nodiscard
function khaoslib_ammo.get_ammo_type(ammo, compare)
  if type(compare) ~= "function" then error("compare parameter: Expected function, got " .. type(compare), 2) end

  local resolved_ammo = resolve(ammo)
  populate_ammo_type(resolved_ammo)

  local found = khaoslib_list.get(resolved_ammo.ammo_type --[[@as data.AmmoType[] ]], compare)
  depopulate_ammo_type(resolved_ammo)

  if found then
    return khaoslib_ammo_type:load(found)
  else
    return nil
  end
end

--- Adds an ammo type to the ammo, allows duplicates.
--- @param ammo_type khaoslib.AmmoTypeManipulator|data.AmmoType The ammo type to add.
--- @param options ListAddIndexOptions? Options table with fields:
---   - `index` (integer, optional): If provided, inserts the ammo type at the specified index instead of appending to the end of the list.
--- @return khaoslib.AmmoManipulator self The same ammo manipulation object for method chaining.
function khaoslib_ammo:add_ammo_type(ammo_type, options)
  if type(ammo_type) ~= "table" then error("ammo_type parameter: Expected table, got " .. type(ammo_type), 2) end

  options = options or {}
  --- @cast options ListAddOptions
  options.allow_duplicates = true

  populate_ammo_type(self.ammo)
  self.ammo.ammo_type = khaoslib_list.add(self.ammo.ammo_type --[[@as data.AmmoType[] ]], (type(ammo_type) == "table" and ammo_type.get) and ammo_type:get() or (ammo_type --[[@as data.AmmoType]]), nil, options)

  depopulate_ammo_type(self.ammo)
  return self
end

--- Removes matching ammo type from the ammo.
--- @param compare (fun(ammo_type: data.AmmoType): boolean) A comparison function to match ammo types.
--- @param options ListRemoveOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, removes all matching ammo types instead of just the first.
--- @return khaoslib.AmmoManipulator self The same ammo manipulation object for method chaining.
function khaoslib_ammo:remove_ammo_type(compare, options)
  if type(compare) ~= "function" then error("compare parameter: Expected function, got " .. type(compare), 2) end

  populate_ammo_type(self.ammo)
  self.ammo.ammo_type = khaoslib_list.remove(self.ammo.ammo_type --[[@as data.AmmoType[] ]], compare, options)

  depopulate_ammo_type(self.ammo)
  return self
end

--- Replaces matching ammo types with a new ammo type.
--- If no matching ammo types are found, no changes are made.
--- @param compare fun(ammo_type: data.AmmoType): boolean A comparison function to match ammo types.
--- @param replacement khaoslib.AmmoTypeManipulator|data.AmmoType|fun(ammo_type: data.AmmoType): data.AmmoType The new ammo type to replace with.
--- @param options ListReplaceOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, replaces all matching ammo types instead of just the first.
--- @return khaoslib.AmmoManipulator self The same ammo manipulation object for method chaining.
--- @throws If compare is not a string or function, or replacement is not a table or function.
function khaoslib_ammo:replace_ammo_type(compare, replacement, options)
  if type(compare) ~= "function" then error("compare parameter: Expected function, got " .. type(compare), 2) end
  if type(replacement) ~= "table" and type(replacement) ~= "function" then error("replacement parameter: Expected table or function, got " .. type(replacement), 2) end

  populate_ammo_type(self.ammo)
  --- @diagnostic disable-next-line: assign-type-mismatch, param-type-mismatch
  self.ammo.ammo_type = khaoslib_list.replace(self.ammo.ammo_type --[[@as data.AmmoType[] ]], (type(replacement) == "table" and replacement.get) and replacement:get() or replacement, compare, options)

  depopulate_ammo_type(self.ammo)
  return self
end

--- Removes all ammo types from the ammo.
--- @return khaoslib.AmmoManipulator self The same ammo manipulation object for method chaining.
function khaoslib_ammo:clear_ammo_types()
  self.ammo.ammo_type = nil

  return self
end

--#endregion

--#region Utility functions
-- Module-level utility functions for ammo discovery and analysis.

--- Checks if an ammo exists in the data stage.
--- @param name data.ItemID The ammo name to check.
--- @return boolean exists True if the ammo exists, false otherwise.
function khaoslib_ammo.exists(name)
  if type(name) ~= "string" then error("name parameter: Expected string, got " .. type(name), 2) end

  return data.raw["ammo"][name] ~= nil
end

--- Finds all ammo that match a custom compare function.
--- @param compare_fn fun(ammo: data.AmmoItemPrototype): boolean A function that returns true for ammo to include.
--- @return data.ItemID[] ammo A list of ammo names that match the compare function.
--- @throws If compare_fn is not a function.
--- @nodiscard
function khaoslib_ammo.find(compare_fn)
  if type(compare_fn) ~= "function" then error("compare_fn parameter: Expected function, got " .. type(compare_fn), 2) end

  local result = {}
  for _, ammo in pairs(data.raw["ammo"] or {}) do
    if compare_fn(ammo) then
      table.insert(result, ammo.name)
    end
  end

  return result
end

--#endregion

return khaoslib_ammo
