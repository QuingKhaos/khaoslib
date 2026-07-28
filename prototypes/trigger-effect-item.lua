local khaoslib_list = require("__khaoslib__.common.list")

--#region Basic manipulation methods
-- A set of basic methods for creating and working with trigger effect item manipulation objects.

--- Trigger effect item manipulation utilities for Factorio data stage.
---
--- This module provides a fluent API for creating, modifying, and managing trigger effect items
--- during the data stage. It supports method chaining and uses the list utility module for
--- consistent prerequisite and effect manipulation.
--- @class khaoslib.TriggerEffectItemManipulator
--- @field private trigger_effect_item data.TriggerEffectItem The trigger effect item currently being manipulated.
--- @operator add(khaoslib.TriggerEffectItemManipulator): khaoslib.TriggerEffectItemManipulator
local khaoslib_trigger_effect_item = {}

--- Loads a given trigger effect item for manipulation.
--- @param trigger_effect_item data.TriggerEffectItem The trigger effect item to manipulate.
--- @return khaoslib.TriggerEffectItemManipulator manipulator A trigger effect item manipulation object for the given trigger effect item.
--- @throws If the trigger effect item is invalid.
function khaoslib_trigger_effect_item:load(trigger_effect_item)
  if type(trigger_effect_item) ~= "table" then error("trigger_effect_item parameter: Expected table, got " .. type(trigger_effect_item), 2) end

  local _trigger_effect_item = util.table.deepcopy(trigger_effect_item)

  --- @diagnostic disable-next-line: missing-fields
  --- @type khaoslib.TriggerEffectItemManipulator
  local obj = {trigger_effect_item = _trigger_effect_item}
  setmetatable(obj, self)
  self.__index = self

  return obj
end

--- Internal helper function to resolve the trigger effect item from data or a trigger effect item manipulation object.
--- @param trigger_effect_item data.TriggerEffectItem|khaoslib.TriggerEffectItemManipulator The trigger effect item to resolve.
--- @return data.TriggerEffectItem resolved_trigger_effect_item The resolved trigger effect item.
--- @throws If the trigger effect item cannot be resolved.
local resolve = function(trigger_effect_item)
  if type(trigger_effect_item) == "table" then
    --- @diagnostic disable: access-invisible
    if getmetatable(trigger_effect_item) == khaoslib_trigger_effect_item and trigger_effect_item.trigger_effect_item then
      return trigger_effect_item.trigger_effect_item
    else
      return trigger_effect_item --[[@as data.TriggerEffectItem]]
    end
    --- @diagnostic enable: access-invisible
  else
    error("Invalid trigger effect item parameter: expected trigger effect item table or trigger effect item manipulator", 3)
  end
end

--- Gets the raw data table of the trigger effect item.
--- @param trigger_effect_item data.TriggerEffectItem|khaoslib.TriggerEffectItemManipulator The trigger effect item.
--- @return data.TriggerEffectItem trigger_effect_item A deep copy of the trigger effect item data.
--- @nodiscard
function khaoslib_trigger_effect_item.get(trigger_effect_item)
  return util.table.deepcopy(resolve(trigger_effect_item))
end

--- Merges the given fields into the trigger effect item.
--- @param fields data.TriggerEffectItem A table of fields to merge into the trigger effect item. See `data.TriggerEffectItem` for valid fields.
--- @return khaoslib.TriggerEffectItemManipulator self The same trigger effect item manipulation object for method chaining.
--- @throws If fields is not a table
function khaoslib_trigger_effect_item:set(fields)
  if type(fields) ~= "table" then error("fields parameter: Expected table, got " .. type(fields), 2) end

  self.trigger_effect_item = util.merge({self.trigger_effect_item, util.table.deepcopy(fields)})

  return self
end

--- Unsets the given field in the trigger effect item currently being manipulated.
--- @param field string The field to unset in the trigger effect item. See `data.TriggerEffectItem` for valid fields.
--- @return khaoslib.TriggerEffectItemManipulator self The same trigger effect item manipulation object for method chaining.
--- @throws If field is not a string
function khaoslib_trigger_effect_item:unset(field)
  if type(field) ~= "string" then error("field parameter: Expected string, got " .. type(field), 2) end

  --- @diagnostic disable-next-line: undefined-field
  local fields_iter = field:gmatch("[^%.]+")
  local current = self.trigger_effect_item
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

--- Merges another trigger effect item manipulation object into this one, excluding the name field.
--- @param other khaoslib.TriggerEffectItemManipulator The other trigger effect item manipulation object to merge into this one.
--- @return khaoslib.TriggerEffectItemManipulator self The same trigger effect item manipulation object for method chaining.
--- @throws If other is not a trigger effect item manipulation object.
function khaoslib_trigger_effect_item:__add(other)
  if type(other) ~= "table" or getmetatable(other) ~= khaoslib_trigger_effect_item then
    error("Can only concatenate with another khaoslib.TriggerEffectItemManipulator object", 2)
  end

  local other_copy = other:get()

  return self:set(other_copy)
end

--#endregion

return khaoslib_trigger_effect_item
