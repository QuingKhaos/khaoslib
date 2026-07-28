local khaoslib_list = require("__khaoslib__.common.list")
local khaoslib_trigger_effect_item = require("__khaoslib__.prototypes.trigger-effect-item")

--#region Basic manipulation methods
-- A set of basic methods for creating and working with trigger delivery item manipulation objects.

--- Trigger delivery item manipulation utilities for Factorio data stage.
---
--- This module provides a fluent API for creating, modifying, and managing trigger delivery items
--- during the data stage. It supports method chaining and uses the list utility module for
--- consistent prerequisite and effect manipulation.
--- @class khaoslib.TriggerDeliveryItemManipulator
--- @field private trigger_delivery_item data.TriggerDeliveryItem The trigger delivery item currently being manipulated.
--- @operator add(khaoslib.TriggerDeliveryItemManipulator): khaoslib.TriggerDeliveryItemManipulator
local khaoslib_trigger_delivery_item = {}

--- Loads a given trigger delivery item for manipulation.
--- @param trigger_delivery_item data.TriggerDeliveryItem The trigger delivery item to manipulate.
--- @return khaoslib.TriggerDeliveryItemManipulator manipulator A trigger delivery item manipulation object for the given trigger delivery item.
--- @throws If the trigger delivery item is invalid.
function khaoslib_trigger_delivery_item:load(trigger_delivery_item)
  if type(trigger_delivery_item) ~= "table" then error("trigger_delivery_item parameter: Expected table, got " .. type(trigger_delivery_item), 2) end

  local _trigger_delivery_item = util.table.deepcopy(trigger_delivery_item)

  --- @diagnostic disable-next-line: missing-fields
  --- @type khaoslib.TriggerDeliveryItemManipulator
  local obj = {trigger_delivery_item = _trigger_delivery_item}
  setmetatable(obj, self)
  self.__index = self

  return obj
end

--- Internal helper function to resolve the trigger delivery item from data or a trigger delivery item manipulation object.
--- @param trigger_delivery_item data.TriggerDeliveryItem|khaoslib.TriggerDeliveryItemManipulator The trigger delivery item to resolve.
--- @return data.TriggerDeliveryItem resolved_trigger_delivery_item The resolved trigger delivery item.
--- @throws If the trigger delivery item cannot be resolved.
local resolve = function(trigger_delivery_item)
  if type(trigger_delivery_item) == "table" then
    --- @diagnostic disable: access-invisible
    if getmetatable(trigger_delivery_item) == khaoslib_trigger_delivery_item and trigger_delivery_item.trigger_delivery_item then
      return trigger_delivery_item.trigger_delivery_item
    else
      return trigger_delivery_item --[[@as data.TriggerDeliveryItem]]
    end
    --- @diagnostic enable: access-invisible
  else
    error("Invalid trigger delivery item parameter: expected trigger delivery item table or trigger delivery item manipulator", 3)
  end
end

--- Gets the raw data table of the trigger delivery item.
--- @param trigger_delivery_item data.TriggerDeliveryItem|khaoslib.TriggerDeliveryItemManipulator The trigger delivery item.
--- @return data.TriggerDeliveryItem trigger_delivery_item A deep copy of the trigger delivery item data.
--- @nodiscard
function khaoslib_trigger_delivery_item.get(trigger_delivery_item)
  return util.table.deepcopy(resolve(trigger_delivery_item))
end

--- Merges the given fields into the trigger delivery item.
--- @param fields data.TriggerDeliveryItem A table of fields to merge into the trigger delivery item. See `data.TriggerDeliveryItem` for valid fields.
--- @return khaoslib.TriggerDeliveryItemManipulator self The same trigger delivery item manipulation object for method chaining.
--- @throws If fields is not a table
function khaoslib_trigger_delivery_item:set(fields)
  if type(fields) ~= "table" then error("fields parameter: Expected table, got " .. type(fields), 2) end

  self.trigger_delivery_item = util.merge({self.trigger_delivery_item, util.table.deepcopy(fields)})

  return self
end

--- Unsets the given field in the trigger delivery item currently being manipulated.
--- @param field string The field to unset in the trigger delivery item. See `data.TriggerDeliveryItem` for valid fields.
--- @return khaoslib.TriggerDeliveryItemManipulator self The same trigger delivery item manipulation object for method chaining.
--- @throws If field is not a string
function khaoslib_trigger_delivery_item:unset(field)
  if type(field) ~= "string" then error("field parameter: Expected string, got " .. type(field), 2) end

  --- @diagnostic disable-next-line: undefined-field
  local fields_iter = field:gmatch("[^%.]+")
  local current = self.trigger_delivery_item
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

--- Merges another trigger delivery item manipulation object into this one, excluding the name field.
--- @param other khaoslib.TriggerDeliveryItemManipulator The other trigger delivery item manipulation object to merge into this one.
--- @return khaoslib.TriggerDeliveryItemManipulator self The same trigger delivery item manipulation object for method chaining.
--- @throws If other is not a trigger delivery item manipulation object.
function khaoslib_trigger_delivery_item:__add(other)
  if type(other) ~= "table" or getmetatable(other) ~= khaoslib_trigger_delivery_item then
    error("Can only concatenate with another khaoslib.TriggerDeliveryItemManipulator object", 2)
  end

  local other_copy = other:get()

  return self:set(other_copy)
end

--#endregion

--#region Trigger delivery manipulation methods
-- A set of utility functions for manipulating trigger delivery items.

--- If the trigger delivery item has a single source effect, it is converted to the list format. If the trigger delivery item already has a source effects list, no changes are made.
--- @param trigger_delivery_item data.TriggerDeliveryItem The trigger delivery item reference to populate the source effects for.
local function populate_source_effects(trigger_delivery_item)
  if trigger_delivery_item.source_effects and trigger_delivery_item.source_effects.type ~= nil then
    trigger_delivery_item.source_effects = {trigger_delivery_item.source_effects --[[@as data.TriggerEffectItem]]}
  end
end

--- If just a single source effect exists in the source effects list, depopulate the list.
--- @param trigger_delivery_item data.TriggerDeliveryItem The trigger delivery item reference to depopulate the source effects list from.
local function depopulate_source_effects(trigger_delivery_item)
  if trigger_delivery_item.source_effects and #trigger_delivery_item.source_effects == 1 then
    trigger_delivery_item.source_effects = trigger_delivery_item.source_effects[1]
  end
end

--- Returns a deepcopy of all source effects for the given trigger delivery item. If the trigger delivery item has a single source effect, it is returned as a single-element list.
--- @param trigger_delivery_item data.TriggerDeliveryItem|khaoslib.TriggerDeliveryItemManipulator The trigger delivery item.
--- @return khaoslib.TriggerEffectItemManipulator[] actions A list of source effects for the trigger delivery item.
--- @nodiscard
function khaoslib_trigger_delivery_item.get_source_effects(trigger_delivery_item)
  local resolved_trigger_delivery_item = resolve(trigger_delivery_item)
  if resolved_trigger_delivery_item.source_effects then
    populate_source_effects(resolved_trigger_delivery_item)

    --- @type khaoslib.TriggerEffectItemManipulator[]
    local result = {}

    if resolved_trigger_delivery_item.source_effects then
      for _, source_effect in ipairs(resolved_trigger_delivery_item.source_effects) do
        table.insert(result, khaoslib_trigger_effect_item:load(source_effect))
      end
    end

    depopulate_source_effects(resolved_trigger_delivery_item)
    return result
  else
    return {}
  end
end

--- Returns a deep-copied list of all source effects for the given trigger delivery item that match the given criteria.
--- @param trigger_delivery_item data.TriggerDeliveryItem|khaoslib.TriggerDeliveryItemManipulator The trigger delivery item.
--- @param compare fun(source_effect: data.TriggerEffectItem): boolean A comparison function
--- @return khaoslib.TriggerEffectItemManipulator[] source_effects A list of matching source effects.
--- @throws If compare is not a function.
--- @nodiscard
function khaoslib_trigger_delivery_item.find_source_effects(trigger_delivery_item, compare)
  if type(compare) ~= "function" then error("compare parameter: Expected function, got " .. type(compare), 2) end

  local resolved_trigger_delivery_item = resolve(trigger_delivery_item)
  populate_source_effects(resolved_trigger_delivery_item)

  --- @type khaoslib.TriggerEffectItemManipulator[]
  local result = {}
  local find_result = khaoslib_list.find(resolved_trigger_delivery_item.source_effects --[[@as data.TriggerEffectItem[] ]], compare)

  for _, source_effect in ipairs(find_result) do
    table.insert(result, khaoslib_trigger_effect_item:load(source_effect))
  end

  depopulate_source_effects(resolved_trigger_delivery_item)
  return result
end

--- Sets the list of source effects for the trigger delivery item currently being manipulated, replacing any existing source effects.
--- @param source_effects khaoslib.TriggerEffectItemManipulator[] A list of source effects to set.
--- @return khaoslib.TriggerDeliveryItemManipulator self The same trigger delivery item manipulation object for method chaining.
--- @throws If source_effects is not a table.
function khaoslib_trigger_delivery_item:set_source_effects(source_effects)
  if type(source_effects) ~= "table" then error("source_effects parameter: Expected table, got " .. type(source_effects), 2) end

  self.trigger_delivery_item.source_effects = {}
  for _, effect_manipulator in ipairs(source_effects) do
    table.insert(self.trigger_delivery_item.source_effects, effect_manipulator:get())
  end

  depopulate_source_effects(self.trigger_delivery_item)
  return self
end

--- Returns the number of source effects for the given trigger delivery item.
--- @param trigger_delivery_item data.TriggerDeliveryItem|khaoslib.TriggerDeliveryItemManipulator The trigger delivery item.
--- @return integer count The number of source effects.
--- @nodiscard
function khaoslib_trigger_delivery_item.count_source_effects(trigger_delivery_item)
  local resolved_trigger_delivery_item = resolve(trigger_delivery_item)
  if resolved_trigger_delivery_item.source_effects then
    populate_source_effects(resolved_trigger_delivery_item)
    local count = #resolved_trigger_delivery_item.source_effects

    depopulate_source_effects(resolved_trigger_delivery_item)
    return count
  else
    return 0
  end
end

--- Checks if the trigger item has a source effect matching the given criteria.
--- @param trigger_delivery_item data.TriggerDeliveryItem|khaoslib.TriggerDeliveryItemManipulator The trigger delivery item.
--- @param compare fun(source_effect: data.TriggerEffectItem): boolean A comparison function
--- @return boolean has_source_effect True if the trigger item has a matching source effect, false otherwise.
--- @throws If compare is not a function.
--- @nodiscard
function khaoslib_trigger_delivery_item.has_source_effect(trigger_delivery_item, compare)
  if type(compare) ~= "function" then error("compare parameter: Expected function, got " .. type(compare), 2) end

  local resolved_trigger_delivery_item = resolve(trigger_delivery_item)
  populate_source_effects(resolved_trigger_delivery_item)

  local result = khaoslib_list.has(resolved_trigger_delivery_item.source_effects --[[@as data.TriggerEffectItem[] ]], compare)
  depopulate_source_effects(resolved_trigger_delivery_item)

  return result
end

--- Gets the first source effect (deep-copy) that matches the given criteria.
--- @param trigger_delivery_item data.TriggerDeliveryItem|khaoslib.TriggerDeliveryItemManipulator The trigger delivery item.
--- @param compare fun(source_effect: data.TriggerEffectItem): boolean A comparison function
--- @return khaoslib.TriggerEffectItemManipulator? source_effect The first matching source effect, or nil if no match is found.
--- @throws If compare is not a function.
--- @nodiscard
function khaoslib_trigger_delivery_item.get_source_effect(trigger_delivery_item, compare)
  if type(compare) ~= "function" then error("compare parameter: Expected function, got " .. type(compare), 2) end

  local resolved_trigger_delivery_item = resolve(trigger_delivery_item)
  populate_source_effects(resolved_trigger_delivery_item)

  local found = khaoslib_list.get(resolved_trigger_delivery_item.source_effects --[[@as data.TriggerEffectItem[] ]], compare)
  depopulate_source_effects(resolved_trigger_delivery_item)

  if found then
    return khaoslib_trigger_effect_item:load(found)
  else
    return nil
  end
end

--- Adds a source effect to the trigger delivery item, allows duplicates.
--- @param source_effect khaoslib.TriggerEffectItemManipulator|data.TriggerEffectItem The source effect to add.
--- @param options ListAddIndexOptions? Options table with fields:
---   - `index` (integer, optional): If provided, inserts the source effect at the specified index instead of appending to the end of the list.
--- @return khaoslib.TriggerDeliveryItemManipulator self The same trigger delivery item manipulation object for method chaining.
function khaoslib_trigger_delivery_item:add_source_effect(source_effect, options)
  if type(source_effect) ~= "table" then error("source_effect parameter: Expected table, got " .. type(source_effect), 2) end

  options = options or {}
  --- @cast options ListAddOptions
  options.allow_duplicates = true

  populate_source_effects(self.trigger_delivery_item)
  self.trigger_delivery_item.source_effects = khaoslib_list.add(self.trigger_delivery_item.source_effects --[[@as data.TriggerEffectItem[] ]], (type(source_effect) == "table" and source_effect.get) and source_effect:get() or (source_effect --[[@as data.TriggerEffectItem]]), nil, options)

  depopulate_source_effects(self.trigger_delivery_item)
  return self
end

--- Removes matching source effect from the trigger item.
--- @param compare (fun(source_effect: data.TriggerEffectItem): boolean) A comparison function to match source effects.
--- @param options ListRemoveOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, removes all matching source effects instead of just the first.
--- @return khaoslib.TriggerDeliveryItemManipulator self The same trigger delivery item manipulation object for method chaining.
function khaoslib_trigger_delivery_item:remove_source_effect(compare, options)
  if type(compare) ~= "function" then error("compare parameter: Expected function, got " .. type(compare), 2) end

  populate_source_effects(self.trigger_delivery_item)
  self.trigger_delivery_item.source_effects = khaoslib_list.remove(self.trigger_delivery_item.source_effects --[[@as data.TriggerEffectItem[] ]], compare, options)

  depopulate_source_effects(self.trigger_delivery_item)
  return self
end

--- Replaces matching source effect with a new source effect.
--- If no matching source effects are found, no changes are made.
--- @param compare fun(source_effect: data.TriggerEffectItem): boolean A comparison function to match source effects.
--- @param replacement khaoslib.TriggerEffectItemManipulator|data.TriggerEffectItem|fun(source_effect: data.TriggerEffectItem): data.TriggerEffectItem The new source effect to replace with.
--- @param options ListReplaceOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, replaces all matching source effects instead of just the first.
--- @return khaoslib.TriggerDeliveryItemManipulator self The same trigger delivery item manipulation object for method chaining.
function khaoslib_trigger_delivery_item:replace_source_effect(compare, replacement, options)
  if type(compare) ~= "function" then error("compare parameter: Expected function, got " .. type(compare), 2) end
  if type(replacement) ~= "table" and type(replacement) ~= "function" then error("replacement parameter: Expected table or function, got " .. type(replacement), 2) end

  populate_source_effects(self.trigger_delivery_item)
  --- @diagnostic disable-next-line: assign-type-mismatch, param-type-mismatch
  self.trigger_delivery_item.source_effects = khaoslib_list.replace(self.trigger_delivery_item.source_effects --[[@as data.TriggerEffectItem[] ]], (type(replacement) == "table" and replacement.get) and replacement:get() or replacement, compare, options)

  depopulate_source_effects(self.trigger_delivery_item)
  return self
end

--- Removes all source effects from the trigger item.
--- @return khaoslib.TriggerDeliveryItemManipulator self The same trigger delivery item manipulation object for method chaining.
function khaoslib_trigger_delivery_item:clear_source_effects()
  self.trigger_delivery_item.source_effects = nil

  return self
end

--- If the trigger delivery item has a single target effect, it is converted to the list format. If the trigger delivery item already has a target effects list, no changes are made.
--- @param trigger_delivery_item data.TriggerDeliveryItem The trigger delivery item reference to populate the target effects for.
local function populate_target_effects(trigger_delivery_item)
  if trigger_delivery_item.target_effects and trigger_delivery_item.target_effects.type ~= nil then
    trigger_delivery_item.target_effects = {trigger_delivery_item.target_effects --[[@as data.TriggerEffectItem]]}
  end
end

--- If just a single target effect exists in the target effects list, depopulate the list.
--- @param trigger_delivery_item data.TriggerDeliveryItem The trigger delivery item reference to depopulate the target effects list from.
local function depopulate_target_effects(trigger_delivery_item)
  if trigger_delivery_item.target_effects and #trigger_delivery_item.target_effects == 1 then
    trigger_delivery_item.target_effects = trigger_delivery_item.target_effects[1]
  end
end

--- Returns a deepcopy of all target effects for the given trigger delivery item. If the trigger delivery item has a single target effect, it is returned as a single-element list.
--- @param trigger_delivery_item data.TriggerDeliveryItem|khaoslib.TriggerDeliveryItemManipulator The trigger delivery item.
--- @return khaoslib.TriggerEffectItemManipulator[] actions A list of target effects for the trigger delivery item.
--- @nodiscard
function khaoslib_trigger_delivery_item.get_target_effects(trigger_delivery_item)
  local resolved_trigger_delivery_item = resolve(trigger_delivery_item)
  if resolved_trigger_delivery_item.target_effects then
    populate_target_effects(resolved_trigger_delivery_item)

    --- @type khaoslib.TriggerEffectItemManipulator[]
    local result = {}

    if resolved_trigger_delivery_item.target_effects then
      for _, target_effect in ipairs(resolved_trigger_delivery_item.target_effects) do
        table.insert(result, khaoslib_trigger_effect_item:load(target_effect))
      end
    end

    depopulate_target_effects(resolved_trigger_delivery_item)
    return result
  else
    return {}
  end
end

--- Returns a deep-copied list of all target effects for the given trigger delivery item that match the given criteria.
--- @param trigger_delivery_item data.TriggerDeliveryItem|khaoslib.TriggerDeliveryItemManipulator The trigger delivery item.
--- @param compare fun(target_effect: data.TriggerEffectItem): boolean A comparison function
--- @return khaoslib.TriggerEffectItemManipulator[] target_effects A list of matching target effects.
--- @throws If compare is not a function.
--- @nodiscard
function khaoslib_trigger_delivery_item.find_target_effects(trigger_delivery_item, compare)
  if type(compare) ~= "function" then error("compare parameter: Expected function, got " .. type(compare), 2) end

  local resolved_trigger_delivery_item = resolve(trigger_delivery_item)
  populate_target_effects(resolved_trigger_delivery_item)

  --- @type khaoslib.TriggerEffectItemManipulator[]
  local result = {}
  local find_result = khaoslib_list.find(resolved_trigger_delivery_item.target_effects --[[@as data.TriggerEffectItem[] ]], compare)

  for _, target_effect in ipairs(find_result) do
    table.insert(result, khaoslib_trigger_effect_item:load(target_effect))
  end

  depopulate_target_effects(resolved_trigger_delivery_item)
  return result
end

--- Sets the list of target effects for the trigger delivery item currently being manipulated, replacing any existing target effects.
--- @param target_effects khaoslib.TriggerEffectItemManipulator[] A list of target effects to set.
--- @return khaoslib.TriggerDeliveryItemManipulator self The same trigger delivery item manipulation object for method chaining.
--- @throws If target_effects is not a table.
function khaoslib_trigger_delivery_item:set_target_effects(target_effects)
  if type(target_effects) ~= "table" then error("target_effects parameter: Expected table, got " .. type(target_effects), 2) end

  self.trigger_delivery_item.target_effects = {}
  for _, effect_manipulator in ipairs(target_effects) do
    table.insert(self.trigger_delivery_item.target_effects, effect_manipulator:get())
  end

  depopulate_target_effects(self.trigger_delivery_item)
  return self
end

--- Returns the number of target effects for the given trigger delivery item.
--- @param trigger_delivery_item data.TriggerDeliveryItem|khaoslib.TriggerDeliveryItemManipulator The trigger delivery item.
--- @return integer count The number of target effects.
--- @nodiscard
function khaoslib_trigger_delivery_item.count_target_effects(trigger_delivery_item)
  local resolved_trigger_delivery_item = resolve(trigger_delivery_item)
  if resolved_trigger_delivery_item.target_effects then
    populate_target_effects(resolved_trigger_delivery_item)
    local count = #resolved_trigger_delivery_item.target_effects

    depopulate_target_effects(resolved_trigger_delivery_item)
    return count
  else
    return 0
  end
end

--- Checks if the trigger item has a target effect matching the given criteria.
--- @param trigger_delivery_item data.TriggerDeliveryItem|khaoslib.TriggerDeliveryItemManipulator The trigger delivery item.
--- @param compare fun(target_effect: data.TriggerEffectItem): boolean A comparison function
--- @return boolean has_target_effect True if the trigger item has a matching target effect, false otherwise.
--- @throws If compare is not a function.
--- @nodiscard
function khaoslib_trigger_delivery_item.has_target_effect(trigger_delivery_item, compare)
  if type(compare) ~= "function" then error("compare parameter: Expected function, got " .. type(compare), 2) end

  local resolved_trigger_delivery_item = resolve(trigger_delivery_item)
  populate_target_effects(resolved_trigger_delivery_item)

  local result = khaoslib_list.has(resolved_trigger_delivery_item.target_effects --[[@as data.TriggerEffectItem[] ]], compare)
  depopulate_target_effects(resolved_trigger_delivery_item)

  return result
end

--- Gets the first target effect (deep-copy) that matches the given criteria.
--- @param trigger_delivery_item data.TriggerDeliveryItem|khaoslib.TriggerDeliveryItemManipulator The trigger delivery item.
--- @param compare fun(target_effect: data.TriggerEffectItem): boolean A comparison function
--- @return khaoslib.TriggerEffectItemManipulator? target_effect The first matching target effect, or nil if no match is found.
--- @throws If compare is not a function.
--- @nodiscard
function khaoslib_trigger_delivery_item.get_target_effect(trigger_delivery_item, compare)
  if type(compare) ~= "function" then error("compare parameter: Expected function, got " .. type(compare), 2) end

  local resolved_trigger_delivery_item = resolve(trigger_delivery_item)
  populate_target_effects(resolved_trigger_delivery_item)

  local found = khaoslib_list.get(resolved_trigger_delivery_item.target_effects --[[@as data.TriggerEffectItem[] ]], compare)
  depopulate_target_effects(resolved_trigger_delivery_item)

  if found then
    return khaoslib_trigger_effect_item:load(found)
  else
    return nil
  end
end

--- Adds a target effect to the trigger delivery item, allows duplicates.
--- @param target_effect khaoslib.TriggerEffectItemManipulator|data.TriggerEffectItem The target effect to add.
--- @param options ListAddIndexOptions? Options table with fields:
---   - `index` (integer, optional): If provided, inserts the target effect at the specified index instead of appending to the end of the list.
--- @return khaoslib.TriggerDeliveryItemManipulator self The same trigger delivery item manipulation object for method chaining.
function khaoslib_trigger_delivery_item:add_target_effect(target_effect, options)
  if type(target_effect) ~= "table" then error("target_effect parameter: Expected table, got " .. type(target_effect), 2) end

  options = options or {}
  --- @cast options ListAddOptions
  options.allow_duplicates = true

  populate_target_effects(self.trigger_delivery_item)
  self.trigger_delivery_item.target_effects = khaoslib_list.add(self.trigger_delivery_item.target_effects --[[@as data.TriggerEffectItem[] ]], (type(target_effect) == "table" and target_effect.get) and target_effect:get() or (target_effect --[[@as data.TriggerEffectItem]]), nil, options)

  depopulate_target_effects(self.trigger_delivery_item)
  return self
end

--- Removes matching target effect from the trigger item.
--- @param compare (fun(target_effect: data.TriggerEffectItem): boolean) A comparison function to match target effects.
--- @param options ListRemoveOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, removes all matching target effects instead of just the first.
--- @return khaoslib.TriggerDeliveryItemManipulator self The same trigger delivery item manipulation object for method chaining.
function khaoslib_trigger_delivery_item:remove_target_effect(compare, options)
  if type(compare) ~= "function" then error("compare parameter: Expected function, got " .. type(compare), 2) end

  populate_target_effects(self.trigger_delivery_item)
  self.trigger_delivery_item.target_effects = khaoslib_list.remove(self.trigger_delivery_item.target_effects --[[@as data.TriggerEffectItem[] ]], compare, options)

  depopulate_target_effects(self.trigger_delivery_item)
  return self
end

--- Replaces matching target effect with a new target effect.
--- If no matching target effects are found, no changes are made.
--- @param compare fun(target_effect: data.TriggerEffectItem): boolean A comparison function to match target effects.
--- @param replacement khaoslib.TriggerEffectItemManipulator|data.TriggerEffectItem|fun(target_effect: data.TriggerEffectItem): data.TriggerEffectItem The new target effect to replace with.
--- @param options ListReplaceOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, replaces all matching target effects instead of just the first.
--- @return khaoslib.TriggerDeliveryItemManipulator self The same trigger delivery item manipulation object for method chaining.
function khaoslib_trigger_delivery_item:replace_target_effect(compare, replacement, options)
  if type(compare) ~= "function" then error("compare parameter: Expected function, got " .. type(compare), 2) end
  if type(replacement) ~= "table" and type(replacement) ~= "function" then error("replacement parameter: Expected table or function, got " .. type(replacement), 2) end

  populate_target_effects(self.trigger_delivery_item)
  --- @diagnostic disable-next-line: assign-type-mismatch, param-type-mismatch
  self.trigger_delivery_item.target_effects = khaoslib_list.replace(self.trigger_delivery_item.target_effects --[[@as data.TriggerEffectItem[] ]], (type(replacement) == "table" and replacement.get) and replacement:get() or replacement, compare, options)

  depopulate_target_effects(self.trigger_delivery_item)
  return self
end

--- Removes all target effects from the trigger item.
--- @return khaoslib.TriggerDeliveryItemManipulator self The same trigger delivery item manipulation object for method chaining.
function khaoslib_trigger_delivery_item:clear_target_effects()
  self.trigger_delivery_item.target_effects = nil

  return self
end

--#endregion

return khaoslib_trigger_delivery_item
