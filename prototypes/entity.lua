local khaoslib_list = require("__khaoslib__.common.list")
local util = require("util")

--#region Basic manipulation methods
-- A set of basic methods for creating and working with entity manipulation objects.

--- Entity manipulation utilities for Factorio data stage.
---
--- This module provides a fluent API for creating, modifying, and managing entity prototypes
--- during the data stage. It supports method chaining and uses the list utility module for
--- consistent prerequisite and effect manipulation.
--- @class khaoslib.EntityManipulator
--- @field private entity data.EntityPrototype The entity currently being manipulated.
--- @operator add(khaoslib.EntityManipulator): khaoslib.EntityManipulator
local khaoslib_entity = {}

--- Loads a given entity for manipulation or creates a new one if a table is passed.
--- @param _type? string The type of the entity. Will be ignored if a table is passed with a type field.
--- @param entity data.EntityID|data.EntityPrototype The name of an existing entity or a new entity prototype table.
--- @return khaoslib.EntityManipulator manipulator An entity manipulation object for the given entity.
--- @overload fun(entity: data.EntityPrototype): khaoslib.EntityManipulator
--- @throws If the entity name doesn't exist or if a table is passed with a name that already exists or without a valid name field.
function khaoslib_entity:load(_type, entity)
  if type(_type) == "table" and entity == nil then
    entity = _type
    _type = nil
  end

  local entity_type = type(entity)
  if entity_type ~= "string" and entity_type ~= "table" then error("entity parameter: Expected string or table , got " .. entity_type, 2) end

  if entity_type == "string" then
    if type(_type) ~= "string" then error("_type parameter: Expected string, got " .. type(_type), 2) end
    if not khaoslib_entity.exists(_type, entity) then error("No such entity: " .. entity, 2) end
  else -- entity_type == "table"
    if entity.type and type(entity.type) ~= "string" then error("entity table type field should be a string if set", 2) end
    if not entity.name or type(entity.name) ~= "string" then error("entity table must have a name field of type string", 2) end
    if khaoslib_entity.exists(entity.type, entity.name) then error("An entity with the name " .. entity.name .. " already exists", 2) end
  end

  local _entity = entity --luacheck: ignore 311
  if entity_type == "string" then
    _entity = util.table.deepcopy(data.raw[_type][entity] --[[@as data.EntityPrototype]])
  else
    _entity = util.table.deepcopy(entity)
    _entity.type = _entity.type or _type
  end

  --- @cast _entity data.EntityPrototype
  --- @type khaoslib.EntityManipulator
  local obj = {entity = _entity}
  setmetatable(obj, self)
  self.__index = self

  return obj
end

--- @diagnostic disable: invisible

--- Internal helper function to resole the entity from a string, entity prototype data or a entity manipulation object.
--- @param _type? string The type of the entity. Required if entity is a string.
--- @param entity data.EntityID|data.EntityPrototype|khaoslib.EntityManipulator The entity to resolve.
--- @return data.EntityPrototype resolved_entity The resolved entity prototype.
--- @throws If the entity cannot be resolved.
local resolve = function(_type, entity)
  if type(entity) == "string" then
    if not _type then error("Type parameter is required when entity is a string", 3) end
    local result = data.raw[_type][entity]
    if not result then
      error("No such entity: " .. entity, 3)
    end

    return result --[[@as data.EntityPrototype]]
  elseif type(entity) == "table" then
    if getmetatable(entity) == khaoslib_entity and entity.entity then
      return entity.entity
    elseif entity.type and entity.name then
      return entity --[[@as data.EntityPrototype]]
    else
      error("Invalid entity table: expected manipulator or prototype with type and name", 3)
    end
  else
    error("Invalid entity parameter: expected entity type and name, prototype table, or entity manipulator", 3)
  end
end

--- @diagnostic enable: invisible

--- Gets the raw data table of the entity.
--- @param _type? string The type of the entity. Required if entity is a string.
--- @param entity data.EntityID|data.EntityPrototype|khaoslib.EntityManipulator The entity.
--- @return data.EntityPrototype entity A deep copy of the entity data.
--- @overload fun(entity: data.EntityPrototype|khaoslib.EntityManipulator): data.EntityPrototype
--- @nodiscard
function khaoslib_entity.get(_type, entity)
  if type(_type) == "table" and entity == nil then
    entity = _type
    _type = nil
  end

  return util.table.deepcopy(resolve(_type, entity))
end

--- @class khaoslib_entity.EntityPrototype : data.EntityPrototype
--- @field type? string
--- @field name? string

--- Merges the given fields into the entity.
--- @param fields khaoslib_entity.EntityPrototype A table of fields to merge into the entity. See `data.EntityPrototype` for valid fields.
--- @return khaoslib.EntityManipulator self The same entity manipulation object for method chaining.
--- @throws If fields is not a table or if it contains a name field.
function khaoslib_entity:set(fields)
  if type(fields) ~= "table" then error("fields parameter: Expected table, got " .. type(fields), 2) end
  if fields.type then error("Cannot change the type of an entity.", 2) end
  if fields.name then error("Cannot change the name of an entity using set(). Use copy() to create a new entity with a different name.", 2) end

  self.entity = util.merge({self.entity, util.table.deepcopy(fields)})

  return self
end

--- Unsets the given field in the entity currently being manipulated.
--- @param field string The field to unset in the entity. See `data.EntityPrototype` for valid fields.
--- @return khaoslib.EntityManipulator self The same entity manipulation object for method chaining.
--- @throws If field is not a string, or if it is the type or name field.
function khaoslib_entity:unset(field)
  if type(field) ~= "string" then error("field parameter: Expected string, got " .. type(field), 2) end
  if field == "type" then error("Cannot unset the type of an entity.", 2) end
  if field == "name" then error("Cannot unset the name of an entity.", 2) end

  self.entity[field] = nil

  return self
end

--- Creates a deep copy of the entity.
--- @param _type? string The type of the entity. Required if entity is a string.
--- @param entity data.EntityID|data.EntityPrototype|khaoslib.EntityManipulator The entity.
--- @param new_name data.EntityID The name of the new entity. Must not already exist.
--- @return khaoslib.EntityManipulator entity A new entity manipulation object with a deep copy of the entity.
--- @throws If an entity with the new name already exists.
--- @nodiscard
function khaoslib_entity.copy(_type, entity, new_name)
  if type(_type) == "table" and type(entity) == "string" and new_name == nil then
    new_name = entity
    entity = _type
    _type = nil
  end

  local copy = util.table.deepcopy(resolve(_type, entity))
  copy.name = new_name

  return khaoslib_entity:load(nil, copy)
end

--- Commits the changes to the data stage.
--- If the entity already exists, it is overwritten.
--- @return khaoslib.EntityManipulator self The same entity manipulation object for method chaining.
function khaoslib_entity:commit()
  self:remove()
  --- @diagnostic disable-next-line: assign-type-mismatch
  data:extend({self:get()})

  return self
end

--- Deletes the entity from the data stage instantly. Use with caution, as this works without a commit.
--- @param _type? string The type of the entity. Required if entity is a string.
--- @param entity data.EntityID|data.EntityPrototype|khaoslib.EntityManipulator The entity.
--- @return nil
--- @overload fun(self: khaoslib.EntityManipulator): khaoslib.EntityManipulator
function khaoslib_entity.remove(_type, entity)
  if type(_type) == "table" and entity == nil then
    entity = _type
    _type = nil
  end

  local resolved = resolve(_type, entity)
  data.raw[resolved.type][resolved.name] = nil

  if type(entity) == "table" and getmetatable(entity) == khaoslib_entity then
    return entity --[[@as khaoslib.EntityManipulator]]
  end
end

--- Merges another entity manipulation object into this one, excluding the name field.
--- @param other khaoslib.EntityManipulator The other entity manipulation object to merge into this one
--- @return khaoslib.EntityManipulator self The same entity manipulation object for method chaining.
--- @throws If other is not an entity manipulation object.
function khaoslib_entity:__add(other)
  if type(other) ~= "table" or getmetatable(other) ~= khaoslib_entity then
    error("Can only concatenate with another khaoslib.EntityManipulator object", 2)
  end

  if self.entity.type ~= other.entity.type then
    error("Cannot merge entities of different types: " .. self.entity.type .. " and " .. other.entity.type, 2)
  end

  local other_copy = other:get()
  other_copy.type = nil
  other_copy.name = nil

  return self:set(other_copy --[[@as khaoslib_entity.EntityPrototype]])
end

--- Compares two entity manipulation objects for equality based on the entity name.
--- @param other khaoslib.EntityManipulator The other entity manipulation object to compare with.
--- @return boolean is_equal True if the two entity manipulation objects represent the same entity, false otherwise.
function khaoslib_entity:__eq(other)
  if type(other) ~= "table" or getmetatable(other) ~= khaoslib_entity then return false end

  return self.entity.type == other.entity.type and self.entity.name == other.entity.name
end

--- Returns a string representation of the entity manipulation object.
--- @return string representation A string representation of the entity manipulation object.
function khaoslib_entity:__tostring()
  return "[khaoslib_entity: ".. self.entity.type .. "/" .. self.entity.name .. "]"
end

--#endregion

--#region Entity manipulation methods
-- A set of utility functions for manipulating entities.

--- If the entity has a single icon, it is converted to the icons list format. If the entity already has an icons list, no changes are made.
--- @param entity data.EntityPrototype The entity reference to populate icons for.
local populate_icons = function(entity)
  if entity.icon and (not entity.icons or #entity.icons == 0) then
    entity.icons = {{icon = entity.icon, icon_size = entity.icon_size or nil}}
    entity.icon = nil
    entity.icon_size = nil
  end
end

--- If just a single entity exists in the icons list, and it has no special properties, depopulate the icons list and set the icon and icon_size fields instead.
--- @param entity data.EntityPrototype The entity reference to depopulate icons from.
local depopulate_icons = function(entity)
  if #entity.icons == 1 then
    local icon = entity.icons[1]
    if icon.tint == nil and icon.shift == nil and icon.scale == nil and icon.draw_background == nil and icon.floating == nil then
      entity.icon = icon.icon
      entity.icon_size = icon.icon_size or nil
      entity.icons = nil
    end
  end
end

--- Returns a deepcopy of all icons for the given entity. If the entity has a single icon, it is returned as a single-element list.
--- @param _type? string The type of the entity. Required if entity is a string.
--- @param entity data.EntityID|data.EntityPrototype|khaoslib.EntityManipulator The entity.
--- @return data.IconData[] icons A list of icons for the entity.
--- @overload fun(entity: data.EntityPrototype|khaoslib.EntityManipulator): data.IconData[]
--- @nodiscard
function khaoslib_entity.get_icons(_type, entity)
  if type(_type) == "table" and entity == nil then
    entity = _type
    _type = nil
  end

  local resolved = resolve(_type, entity)
  if resolved.icons then
    return util.table.deepcopy(resolved.icons --[=[@as data.IconData[]]=])
  elseif resolved.icon then
    return util.table.deepcopy({{icon = resolved.icon, icon_size = resolved.icon_size or nil}})
  else
    return {}
  end
end

--- Returns a deep-copied list of all icons for the given entity that match the given criteria.
--- @param _type? string The type of the entity. Required if entity is a string.
--- @param entity data.EntityID|data.EntityPrototype|khaoslib.EntityManipulator The entity.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @return data.IconData[] icons A list of matching icons.
--- @overload fun(entity: data.EntityPrototype|khaoslib.EntityManipulator, compare: (fun(icon: data.IconData): boolean)|string): data.IconData[]
--- @throws If compare is not a string or function.
--- @nodiscard
function khaoslib_entity.find_icons(_type, entity, compare)
  if type(_type) == "table" and (type(entity) == "string" or type(entity) == "function") and compare == nil then
    compare = entity
    entity = _type
    _type = nil
  end

  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  local resolved = resolve(_type, entity)
  populate_icons(resolved)
  local result = khaoslib_list.find(resolved.icons, compare_fn)
  depopulate_icons(resolved)

  return result
end

--- Sets the list of icons for the entity currently being manipulated, replacing any existing icons.
--- @param icons data.IconData[] A list of icons to set.
--- @return khaoslib.EntityManipulator self The same entity manipulation object for method chaining.
--- @throws If icons is not a table.
function khaoslib_entity:set_icons(icons)
  if type(icons) ~= "table" then error("icons parameter: Expected table, got " .. type(icons), 2) end

  self.entity.icon = nil
  self.entity.icon_size = nil
  self.entity.icons = util.table.deepcopy(icons)
  depopulate_icons(self.entity)

  return self
end

--- Returns the number of icons for the given entity.
--- @param _type? string The type of the entity. Required if entity is a string.
--- @param entity data.EntityID|data.EntityPrototype|khaoslib.EntityManipulator The entity.
--- @return integer count The number of icons.
--- @overload fun(entity: data.EntityPrototype|khaoslib.EntityManipulator): integer
--- @nodiscard
function khaoslib_entity.count_icons(_type, entity)
  if type(_type) == "table" and entity == nil then
    entity = _type
    _type = nil
  end

  local resolved = resolve(_type, entity)
  return resolved.icons ~= nil and #resolved.icons or (resolved.icon ~= nil and 1 or 0)
end

--- Checks if the entity has an icon matching the given criteria.
--- Supports both string matching (by icon filename) and custom comparison functions.
--- @param _type? string The type of the entity. Required if entity is a string.
--- @param entity data.EntityID|data.EntityPrototype|khaoslib.EntityManipulator The entity.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @return boolean has_icon True if the entity has the icon, false otherwise.
--- @overload fun(entity: data.EntityPrototype|khaoslib.EntityManipulator, compare: (fun(icon: data.IconData): boolean)|string): boolean
--- @throws If compare is not a string or function.
--- @nodiscard
function khaoslib_entity.has_icon(_type, entity, compare)
  if type(_type) == "table" and (type(entity) == "string" or type(entity) == "function") and compare == nil then
    compare = entity
    entity = _type
    _type = nil
  end

  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  local resolved = resolve(_type, entity)
  populate_icons(resolved)
  local result = khaoslib_list.has(resolved.icons, compare_fn)
  depopulate_icons(resolved)

  return result
end

--- Gets the first icon (deep-copy) that matches the given criteria.
--- Supports both string matching (by icon filename) and custom comparison functions.
--- @param _type? string The type of the entity. Required if entity is a string.
--- @param entity data.EntityID|data.EntityPrototype|khaoslib.EntityManipulator The entity.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @return data.IconData? icon The first matching icon, or nil if no match is found.
--- @overload fun(entity: data.EntityPrototype|khaoslib.EntityManipulator, compare: (fun(icon: data.IconData): boolean)|string): data.IconData?
--- @throws If compare is not a string or function.
--- @nodiscard
function khaoslib_entity.get_icon(_type, entity, compare)
  if type(_type) == "table" and (type(entity) == "string" or type(entity) == "function") and compare == nil then
    compare = entity
    entity = _type
    _type = nil
  end

  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  local resolved = resolve(_type, entity)
  populate_icons(resolved)
  local result = khaoslib_list.get(resolved.icons, compare_fn)
  depopulate_icons(resolved)

  return result
end

--- Adds an icon to the entity, allows duplicates.
--- @param icon data.IconData The icon data to add.
--- @param options ListAddIndexOptions? Options table with fields:
---   - `index` (integer, optional): If provided, inserts the icon at the specified index instead of appending to the end of the list.
--- @return khaoslib.EntityManipulator self The same entity manipulation object for method chaining.
--- @throws If icon is not a table or doesn't have required fields.
function khaoslib_entity:add_icon(icon, options)
  if type(icon) ~= "table" then error("icon parameter: Expected table, got " .. type(icon), 2) end
  if not icon.icon or type(icon.icon) ~= "string" then error("icon parameter: Must have an icon field of type string", 2) end

  options = options or {}
  --- @cast options ListAddOptions
  options.allow_duplicates = true

  populate_icons(self.entity)
  self.entity.icons = khaoslib_list.add(self.entity.icons, icon, nil, options)
  depopulate_icons(self.entity)

  return self
end

--- Removes matching icons from the entity.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @param options ListRemoveOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, removes all matching icons instead of just the first.
--- @return khaoslib.EntityManipulator self The same entity manipulation object for method chaining.
--- @throws If compare is not a string or function.
function khaoslib_entity:remove_icon(compare, options)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  populate_icons(self.entity)
  self.entity.icons = khaoslib_list.remove(self.entity.icons, compare_fn, options)
  depopulate_icons(self.entity)

  return self
end

--- Replaces matching icons with a new icon.
--- If no matching icons are found, no changes are made.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @param replacement (fun(icon: data.IconData): data.IconData)|data.IconData The new icon data to replace with.
--- @param options ListReplaceOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, replaces all matching icons instead of just the first.
--- @return khaoslib.EntityManipulator self The same entity manipulation object for method chaining.
--- @throws If compare is not a string or function, or replacement is not a table or function.
function khaoslib_entity:replace_icon(compare, replacement, options)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  if type(replacement) ~= "table" and type(replacement) ~= "function" then error("replacement parameter: Expected table or function, got " .. type(replacement), 2) end
  if type(replacement) == "table" then
    if not replacement.icon or type(replacement.icon) ~= "string" then error("replacement parameter: Must have an icon field of type string", 2) end
  end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  populate_icons(self.entity)
  self.entity.icons = khaoslib_list.replace(self.entity.icons, replacement, compare_fn, options)
  depopulate_icons(self.entity)

  return self
end

--- Removes all icons from the entity.
--- @return khaoslib.EntityManipulator self The same entity manipulation object for method chaining.
function khaoslib_entity:clear_icons()
  self.entity.icon = nil
  self.entity.icon_size = nil
  self.entity.icons = nil

  return self
end

--- Checks if the entity has minable properties.
--- @param _type? string The type of the entity. Required if entity is a string.
--- @param entity data.EntityID|data.EntityPrototype|khaoslib.EntityManipulator The entity.
--- @return boolean has_minable True if the entity has minable properties, false otherwise.
--- @overload fun(entity: data.EntityPrototype|khaoslib.EntityManipulator): boolean
--- @nodiscard
function khaoslib_entity.has_minable(_type, entity)
  if type(_type) == "table" and entity == nil then
    entity = _type
    _type = nil
  end

  local resolved = resolve(_type, entity)
  return resolved.minable ~= nil
end

--- Returns a deep copy of the minable properties of the entity, or an empty table if none are set.
--- @param _type? string The type of the entity. Required if entity is a string.
--- @param entity data.EntityID|data.EntityPrototype|khaoslib.EntityManipulator The entity.
--- @return data.MinableProperties minable The minable properties of the entity, or an empty table if none are set.
--- @overload fun(entity: data.EntityPrototype|khaoslib.EntityManipulator): data.MinableProperties
--- @nodiscard
function khaoslib_entity.get_minable(_type, entity)
  if type(_type) == "table" and entity == nil then
    entity = _type
    _type = nil
  end

  return util.table.deepcopy(resolve(_type, entity).minable or {})
end

--- Sets the minable property of the entity, overwritting all properties.
--- @param minable data.MinableProperties The minable properties to set.
--- @return khaoslib.EntityManipulator self The same entity manipulation object for method chaining.
--- @throws If minable is not a table, or if minable.result is not a string, or if minable.results is not a table.
function khaoslib_entity:set_minable(minable)
  if type(minable) ~= "table" then error("minable parameter: Expected table, got " .. type(minable), 2) end
  if minable.result and type(minable.result) ~= "string" then error("minable.result field: Expected string, got " .. type(minable.result), 2) end
  if minable.results and type(minable.results) ~= "table" then error("minable.results field: Expected table, got " .. type(minable.results), 2) end

  self.entity.minable = util.table.deepcopy(minable)

  return self
end

--- @class khaoslib_entity.MinableProperties : data.MinableProperties
--- @field mining_time? double

--- Merges the given minable properties into the entity's existing minable properties.
--- If the entity does not have minable properties, it will be created.
--- @param minable khaoslib_entity.MinableProperties The minable properties to merge.
--- @return khaoslib.EntityManipulator self The same entity manipulation object for method chaining.
--- @throws If minable is not a table, or if minable.result is not a string, or if minable.results is not a table, or if the entity does not have minable properties and the provided minable properties do not have a mining_time field.
function khaoslib_entity:merge_minable(minable)
  if type(minable) ~= "table" then error("minable parameter: Expected table, got " .. type(minable), 2) end
  if minable.result and type(minable.result) ~= "string" then error("minable.result field: Expected string, got " .. type(minable.result), 2) end
  if minable.results and type(minable.results) ~= "table" then error("minable.results field: Expected table, got " .. type(minable.results), 2) end

  if not self.entity.minable then
    if not minable.mining_time then
      error("Cannot merge minable properties into an entity that does not have minable properties, and the provided minable properties do not have a mining_time field.", 2)
    end
  end

  self.entity.minable = util.merge({self.entity.minable or {}, util.table.deepcopy(minable)})

  return self
end

--- Clears the minable properties of the entity.
--- @return khaoslib.EntityManipulator self The same entity manipulation object for method chaining.
function khaoslib_entity:clear_minable()
  self.entity.minable = nil

  return self
end

--- Returns the emissions per minute for the entity's energy source, if applicable.
--- @param _type? string The type of the entity. Required if entity is a string.
--- @param entity data.EntityID|data.EntityPrototype|khaoslib.EntityManipulator The entity.
--- @return table<data.AirbornePollutantID, double> emissions_per_minute A deep copy of the emissions per minute table
--- @overload fun(entity: data.EntityPrototype|khaoslib.EntityManipulator): table<data.AirbornePollutantID, double>
--- @throws If the entity does not have an energy_source field.
--- @nodiscard
function khaoslib_entity.get_emissions(_type, entity)
  if type(_type) == "table" and entity == nil then
    entity = _type
    _type = nil
  end

  local resolved = resolve(_type, entity)
  --- @cast resolved data.AgriculturalTowerPrototype|data.BoilerPrototype|data.CraftingMachinePrototype|data.InserterPrototype|data.LabPrototype|data.MiningDrillPrototype|data.OffshorePumpPrototype|data.PumpPrototype|data.RadarPrototype|data.ReactorPrototype

  if not resolved.energy_source then
    error("Entity type " .. resolved.type .. " does not have an energy_source field.", 2)
  end

  return util.table.deepcopy(resolved.energy_source.emissions_per_minute  or {})
end

--- Sets the emissions per minute for the entity's energy source, if applicable.
--- @param emissions table<data.AirbornePollutantID, double> A table of emissions per minute to set.
--- @return khaoslib.EntityManipulator self The same entity manipulation object for method chaining.
--- @throws If the entity does not have an energy_source field.
function khaoslib_entity:set_emissions(emissions)
  local entity = self.entity
  --- @cast entity data.AgriculturalTowerPrototype|data.BoilerPrototype|data.CraftingMachinePrototype|data.InserterPrototype|data.LabPrototype|data.MiningDrillPrototype|data.OffshorePumpPrototype|data.PumpPrototype|data.RadarPrototype|data.ReactorPrototype

  if not entity.energy_source then
    error("Entity type " .. entity.type .. " does not have an energy_source field.", 2)
  end

  if type(emissions) ~= "table" then error("emissions parameter: Expected table, got " .. type(emissions), 2) end

  entity.energy_source.emissions_per_minute = util.table.deepcopy(emissions)

  return self
end

--- Returns the number of emissions entries for the entity's energy source, if applicable.
--- @param _type? string The type of the entity. Required if entity is a string.
--- @param entity data.EntityID|data.EntityPrototype|khaoslib.EntityManipulator The entity.
--- @return integer count The number of emissions entries.
--- @overload fun(entity: data.EntityPrototype|khaoslib.EntityManipulator): integer
--- @throws If the entity does not have an energy_source field.
function khaoslib_entity.count_emissions(_type, entity)
  if type(_type) == "table" and entity == nil then
    entity = _type
    _type = nil
  end

  local resolved = resolve(_type, entity)
  --- @cast resolved data.AgriculturalTowerPrototype|data.BoilerPrototype|data.CraftingMachinePrototype|data.InserterPrototype|data.LabPrototype|data.MiningDrillPrototype|data.OffshorePumpPrototype|data.PumpPrototype|data.RadarPrototype|data.ReactorPrototype

  if not resolved.energy_source then
    error("Entity type " .. resolved.type .. " does not have an energy_source field.", 2)
  end

  return #(resolved.energy_source.emissions_per_minute or {})
end

--- Checks if the entity has an emissions entry matching the given criteria.
--- Supports both string matching (by pollutant name) and custom comparison functions.
--- @param _type? string The type of the entity. Required if entity is a string.
--- @param entity data.EntityID|data.EntityPrototype|khaoslib.EntityManipulator The entity.
--- @param compare (fun(emissions_per_minute: double): boolean)|data.AirbornePollutantID A comparison function or pollutant name to match.
--- @return boolean has_emission True if the entity has the emissions entry, false otherwise.
--- @overload fun(entity: data.EntityPrototype|khaoslib.EntityManipulator, compare: (fun(emissions_per_minute: double): boolean)|data.AirbornePollutantID): boolean
--- @throws If compare is not a string or function.
function khaoslib_entity.has_emission(_type, entity, compare)
  if type(_type) == "table" and (type(entity) == "string" or type(entity) == "function") and compare == nil then
    compare = entity
    entity = _type
    _type = nil
  end

  local resolved = resolve(_type, entity)
  --- @cast resolved data.AgriculturalTowerPrototype|data.BoilerPrototype|data.CraftingMachinePrototype|data.InserterPrototype|data.LabPrototype|data.MiningDrillPrototype|data.OffshorePumpPrototype|data.PumpPrototype|data.RadarPrototype|data.ReactorPrototype

  if not resolved.energy_source then
    error("Entity type " .. resolved.type .. " does not have an energy_source field.", 2)
  end

  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  if type(compare) == "string" then
    return resolved.energy_source.emissions_per_minute and resolved.energy_source.emissions_per_minute[compare] ~= nil or false
  else
    return khaoslib_list.has(resolved.energy_source.emissions_per_minute or {}, compare)
  end
end

--- Adds an emissions entry to the entity's energy source, if applicable.
--- If the pollutant already exists, it will not be overwritten.
--- @param pollutant data.AirbornePollutantID The name of the pollutant to add.
--- @param amount double The amount of emissions per minute for the pollutant.
--- @return khaoslib.EntityManipulator self The same entity manipulation object for method chaining.
--- @throws If the entity does not have an energy_source field, or if pollutant is not a string, or if amount is not a number.
function khaoslib_entity:add_emission(pollutant, amount)
  local entity = self.entity
  --- @cast entity data.AgriculturalTowerPrototype|data.BoilerPrototype|data.CraftingMachinePrototype|data.InserterPrototype|data.LabPrototype|data.MiningDrillPrototype|data.OffshorePumpPrototype|data.PumpPrototype|data.RadarPrototype|data.ReactorPrototype

  if not entity.energy_source then
    error("Entity type " .. entity.type .. " does not have an energy_source field.", 2)
  end

  if type(pollutant) ~= "string" then error("pollutant parameter: Expected string, got " .. type(pollutant), 2) end
  if type(amount) ~= "number" then error("amount parameter: Expected number, got " .. type(amount), 2) end

  entity.energy_source.emissions_per_minute = entity.energy_source.emissions_per_minute or {}
  if entity.energy_source.emissions_per_minute[pollutant] == nil then
    entity.energy_source.emissions_per_minute[pollutant] = amount
  end

  return self
end

--- Removes an emissions entry from the entity's energy source, if applicable.
--- @param pollutant data.AirbornePollutantID The name of the pollutant to remove.
--- @return khaoslib.EntityManipulator self The same entity manipulation object for method chaining.
--- @throws If the entity does not have an energy_source field, or if pollutant is not a string.
function khaoslib_entity:remove_emission(pollutant)
  local entity = self.entity
  --- @cast entity data.AgriculturalTowerPrototype|data.BoilerPrototype|data.CraftingMachinePrototype|data.InserterPrototype|data.LabPrototype|data.MiningDrillPrototype|data.OffshorePumpPrototype|data.PumpPrototype|data.RadarPrototype|data.ReactorPrototype

  if not entity.energy_source then
    error("Entity type " .. entity.type .. " does not have an energy_source field.", 2)
  end

  if type(pollutant) ~= "string" then error("pollutant parameter: Expected string, got " .. type(pollutant), 2) end

  if entity.energy_source.emissions_per_minute then
    entity.energy_source.emissions_per_minute[pollutant] = nil
  end

  return self
end

--- Replaces an emissions entry in the entity's energy source, if applicable. If the pollutant does not exist, it will be added.
--- @param pollutant data.AirbornePollutantID The name of the pollutant to replace.
--- @param amount double The new amount of emissions per minute for the pollutant.
--- @return khaoslib.EntityManipulator self The same entity manipulation object for method chaining.
--- @throws If the entity does not have an energy_source field, or if pollutant is not a string, or if amount is not a number.
function khaoslib_entity:replace_emission(pollutant, amount)
  local entity = self.entity
  --- @cast entity data.AgriculturalTowerPrototype|data.BoilerPrototype|data.CraftingMachinePrototype|data.InserterPrototype|data.LabPrototype|data.MiningDrillPrototype|data.OffshorePumpPrototype|data.PumpPrototype|data.RadarPrototype|data.ReactorPrototype

  if not entity.energy_source then
    error("Entity type " .. entity.type .. " does not have an energy_source field.", 2)
  end

  if type(pollutant) ~= "string" then error("pollutant parameter: Expected string, got " .. type(pollutant), 2) end
  if type(amount) ~= "number" then error("amount parameter: Expected number, got " .. type(amount), 2) end

  entity.energy_source.emissions_per_minute = entity.energy_source.emissions_per_minute or {}
  entity.energy_source.emissions_per_minute[pollutant] = amount

  return self
end

--- Clears all emissions entries from the entity's energy source, if applicable.
--- @return khaoslib.EntityManipulator self The same entity manipulation object for method chaining.
--- @throws If the entity does not have an energy_source field.
function khaoslib_entity:clear_emissions()
  local entity = self.entity
  --- @cast entity data.AgriculturalTowerPrototype|data.BoilerPrototype|data.CraftingMachinePrototype|data.InserterPrototype|data.LabPrototype|data.MiningDrillPrototype|data.OffshorePumpPrototype|data.PumpPrototype|data.RadarPrototype|data.ReactorPrototype

  if not entity.energy_source then
    error("Entity type " .. entity.type .. " does not have an energy_source field.", 2)
  end

  entity.energy_source.emissions_per_minute = {}

  return self
end

--#endregion

--#region Utility functions
-- Module-level utility functions for entity discovery and analysis.

--- Checks if an entity exists in the data stage.
--- @param _type string The type of the entity to check.
--- @param name data.EntityID The entity name to check.
--- @return boolean exists True if the entity exists, false otherwise.
--- @nodiscard
function khaoslib_entity.exists(_type, name)
  if type(name) ~= "string" then error("name parameter: Expected string, got " .. type(name), 2) end

  return data.raw[_type] and data.raw[_type][name] ~= nil
end

--- Finds all entities that match a custom compare function.
--- @param _type string The type of the entities to search.
--- @param compare_fn fun(entity: data.EntityPrototype): boolean A function that returns true for entities to include.
--- @return data.EntityID[] entities A list of entity names that match the compare function.
--- @throws If compare_fn is not a function.
--- @nodiscard
function khaoslib_entity.find(_type, compare_fn)
  if type(compare_fn) ~= "function" then error("compare_fn parameter: Expected function, got " .. type(compare_fn), 2) end

  local result = {}
  for _, entity in pairs(data.raw[_type] or {}) do
    if compare_fn(entity --[[@as data.EntityPrototype]]) then
      table.insert(result, entity.name)
    end
  end

  return result
end

--#endregion

return khaoslib_entity
