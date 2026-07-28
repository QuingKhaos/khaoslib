local khaoslib_list = require("__khaoslib__.common.list")
local khaoslib_trigger_item = require("__khaoslib__.prototypes.trigger-item")

--#region Basic manipulation methods
-- A set of basic methods for creating and working with ammo type manipulation objects.

--- Ammo manipulation utilities for Factorio data stage.
---
--- This module provides a fluent API for creating, modifying, and managing ammo types
--- during the data stage. It supports method chaining and uses the list utility module for
--- consistent prerequisite and effect manipulation.
--- @class khaoslib.AmmoTypeManipulator
--- @field private ammo_type data.AmmoType The ammo type currently being manipulated.
--- @operator add(khaoslib.AmmoTypeManipulator): khaoslib.AmmoTypeManipulator
local khaoslib_ammo_type = {}

--- Loads a given ammo type for manipulation.
--- @param ammo_type data.AmmoType The ammo type to manipulate.
--- @return khaoslib.AmmoTypeManipulator manipulator An ammo type manipulation object for the given ammo type.
--- @throws If the ammo type is invalid.
function khaoslib_ammo_type:load(ammo_type)
  if type(ammo_type) ~= "table" then error("ammo_type parameter: Expected table, got " .. type(ammo_type), 2) end

  local _ammo_type = util.table.deepcopy(ammo_type)

  --- @diagnostic disable-next-line: missing-fields
  --- @type khaoslib.AmmoTypeManipulator
  local obj = {ammo_type = _ammo_type}
  setmetatable(obj, self)
  self.__index = self

  return obj
end

--- Internal helper function to resolve the ammo type from data or an ammo type manipulation object.
--- @param ammo_type data.AmmoType|khaoslib.AmmoTypeManipulator The ammo type to resolve.
--- @return data.AmmoType resolved_ammo_type The resolved ammo type.
--- @throws If the ammo cannot be resolved.
local resolve = function(ammo_type)
  if type(ammo_type) == "table" then
    --- @diagnostic disable: access-invisible
    if getmetatable(ammo_type) == khaoslib_ammo_type and ammo_type.ammo_type then
      return ammo_type.ammo_type
    else
      return ammo_type --[[@as data.AmmoType]]
    end
    --- @diagnostic enable: access-invisible
  else
    error("Invalid ammo parameter: expected ammo type table or ammo type manipulator", 3)
  end
end

--- Gets the raw data table of the ammo type.
--- @param ammo_type data.AmmoType|khaoslib.AmmoTypeManipulator The ammo type.
--- @return data.AmmoType ammo_type A deep copy of the ammo type data.
--- @nodiscard
function khaoslib_ammo_type.get(ammo_type)
  return util.table.deepcopy(resolve(ammo_type))
end

--- Merges the given fields into the ammo type.
--- @param fields data.AmmoType A table of fields to merge into the ammo type. See `data.AmmoType` for valid fields.
--- @return khaoslib.AmmoTypeManipulator self The same ammo manipulation object for method chaining.
--- @throws If fields is not a table
function khaoslib_ammo_type:set(fields)
  if type(fields) ~= "table" then error("fields parameter: Expected table, got " .. type(fields), 2) end

  self.ammo_type = util.merge({self.ammo_type, util.table.deepcopy(fields)})

  return self
end

--- Unsets the given field in the ammo type currently being manipulated.
--- @param field string The field to unset in the ammo type. See `data.AmmoType` for valid fields.
--- @return khaoslib.AmmoTypeManipulator self The same ammo type manipulation object for method chaining.
--- @throws If field is not a string
function khaoslib_ammo_type:unset(field)
  if type(field) ~= "string" then error("field parameter: Expected string, got " .. type(field), 2) end

  --- @diagnostic disable-next-line: undefined-field
  local fields_iter = field:gmatch("[^%.]+")
  local current = self.ammo_type
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

--- Merges another ammo type manipulation object into this one, excluding the name field.
--- @param other khaoslib.AmmoTypeManipulator The other ammo type manipulation object to merge into this one.
--- @return khaoslib.AmmoTypeManipulator self The same ammo type manipulation object for method chaining.
--- @throws If other is not an ammo type manipulation object.
function khaoslib_ammo_type:__add(other)
  if type(other) ~= "table" or getmetatable(other) ~= khaoslib_ammo_type then
    error("Can only concatenate with another khaoslib.AmmoTypeManipulator object", 2)
  end

  local other_copy = other:get()

  return self:set(other_copy)
end

--#endregion

--#region Ammo type manipulation methods
-- A set of utility functions for manipulating ammo types.

--- If the ammo type has a single action, it is converted to the list format. If the ammo type already has an action list, no changes are made.
--- @param ammo_type data.AmmoType The ammo type reference to populate the actions for.
local function populate_actions(ammo_type)
  if ammo_type.action and ammo_type.action.type ~= nil then
    ammo_type.action = {ammo_type.action --[[@as data.TriggerItem]]}
  end
end

--- If just a single action exists in the actions list, depopulate the list.
--- @param ammo_type data.AmmoType The ammo type reference to depopulate the actions list from.
local function depopulate_actions(ammo_type)
  if ammo_type.action and #ammo_type.action == 1 then
    ammo_type.action = ammo_type.action[1]
  end
end

--- Returns a deepcopy of all actions for the given ammo type. If the ammo type has a single action, it is returned as a single-element list.
--- @param ammo_type data.AmmoType|khaoslib.AmmoTypeManipulator The ammo type.
--- @return khaoslib.TriggerItemManipulator[] actions A list of actions for the ammo type.
--- @nodiscard
function khaoslib_ammo_type.get_actions(ammo_type)
  local resolved_ammo_type = resolve(ammo_type)
  if resolved_ammo_type.action then
    populate_actions(resolved_ammo_type)

    --- @type khaoslib.TriggerItemManipulator[]
    local result = {}

    if resolved_ammo_type.action then
      for _, action in ipairs(resolved_ammo_type.action) do
        table.insert(result, khaoslib_trigger_item:load(action))
      end
    end

    depopulate_actions(resolved_ammo_type)
    return result
  else
    return {}
  end
end

--- Returns a deep-copied list of all actions for the given ammo type that match the given criteria.
--- @param ammo_type data.AmmoType|khaoslib.AmmoTypeManipulator The ammo type.
--- @param compare fun(action: data.TriggerItem): boolean A comparison function
--- @return khaoslib.TriggerItemManipulator[] actions A list of matching actions.
--- @throws If compare is not a function.
--- @nodiscard
function khaoslib_ammo_type.find_actions(ammo_type, compare)
  if type(compare) ~= "function" then error("compare parameter: Expected function, got " .. type(compare), 2) end

  local resolved_ammo_type = resolve(ammo_type)
  populate_actions(resolved_ammo_type)

  --- @type khaoslib.TriggerItemManipulator[]
  local result = {}
  local find_result = khaoslib_list.find(resolved_ammo_type.action --[[@as data.TriggerItem[] ]], compare)

  for _, action in ipairs(find_result) do
    table.insert(result, khaoslib_trigger_item:load(action))
  end

  depopulate_actions(resolved_ammo_type)
  return result
end

--- Sets the list of actions for the ammo type currently being manipulated, replacing any existing actions.
--- @param actions khaoslib.TriggerItemManipulator[] A list of actions to set.
--- @return khaoslib.AmmoTypeManipulator self The same ammo type manipulation object for method chaining.
--- @throws If actions is not a table.
function khaoslib_ammo_type:set_actions(actions)
  if type(actions) ~= "table" then error("actions parameter: Expected table, got " .. type(actions), 2) end

  self.ammo_type.action = {}
  for _, action_manipulator in ipairs(actions) do
    table.insert(self.ammo_type.action, action_manipulator:get())
  end

  depopulate_actions(self.ammo_type)
  return self
end

--- Returns the number of actions for the given ammo type.
--- @param ammo_type data.AmmoType|khaoslib.AmmoTypeManipulator The ammo type.
--- @return integer count The number of actions.
--- @nodiscard
function khaoslib_ammo_type.count_actions(ammo_type)
  local resolved_ammo_type = resolve(ammo_type)
  if resolved_ammo_type.action then
    populate_actions(resolved_ammo_type)
    local count = #resolved_ammo_type.action

    depopulate_actions(resolved_ammo_type)
    return count
  else
    return 0
  end
end

--- Checks if the ammo type has an action matching the given criteria.
--- @param ammo_type data.AmmoType|khaoslib.AmmoTypeManipulator The ammo type.
--- @param compare fun(action: data.TriggerItem): boolean A comparison function
--- @return boolean has_action True if the ammo type has a matching action, false otherwise.
--- @throws If compare is not a function.
--- @nodiscard
function khaoslib_ammo_type.has_action(ammo_type, compare)
  if type(compare) ~= "function" then error("compare parameter: Expected function, got " .. type(compare), 2) end

  local resolved_ammo_type = resolve(ammo_type)
  populate_actions(resolved_ammo_type)

  local result = khaoslib_list.has(resolved_ammo_type.action --[[@as data.TriggerItem[] ]], compare)
  depopulate_actions(resolved_ammo_type)

  return result
end

--- Gets the first action (deep-copy) that matches the given criteria.
--- @param ammo_type data.AmmoType|khaoslib.AmmoTypeManipulator The ammo type.
--- @param compare (fun(action: data.TriggerItem): boolean) A comparison function
--- @return khaoslib.TriggerItemManipulator? action The first matching action, or nil if no match is found.
--- @throws If compare is not a function.
--- @nodiscard
function khaoslib_ammo_type.get_action(ammo_type, compare)
  if type(compare) ~= "function" then error("compare parameter: Expected function, got " .. type(compare), 2) end

  local resolved_ammo_type = resolve(ammo_type)
  populate_actions(resolved_ammo_type)

  local found = khaoslib_list.get(resolved_ammo_type.action --[[@as data.TriggerItem[] ]], compare)
  depopulate_actions(resolved_ammo_type)

  if found then
    return khaoslib_trigger_item:load(found)
  else
    return nil
  end
end

--- Adds an action to the ammo type, allows duplicates.
--- @param action khaoslib.TriggerItemManipulator|data.TriggerItem The action to add.
--- @param options ListAddIndexOptions? Options table with fields:
---   - `index` (integer, optional): If provided, inserts the action at the specified index instead of appending to the end of the list.
--- @return khaoslib.AmmoTypeManipulator self The same ammo type manipulation object for method chaining.
function khaoslib_ammo_type:add_action(action, options)
  if type(action) ~= "table" then error("action parameter: Expected table, got " .. type(action), 2) end

  options = options or {}
  --- @cast options ListAddOptions
  options.allow_duplicates = true

  populate_actions(self.ammo_type)
  self.ammo_type.action = khaoslib_list.add(self.ammo_type.action --[[@as data.TriggerItem[] ]], (type(action) == "table" and action.get) and action:get() or (action --[[@as data.TriggerItem]]), nil, options)

  depopulate_actions(self.ammo_type)
  return self
end

--- Removes matching action from the ammo type.
--- @param compare (fun(action: data.TriggerItem): boolean) A comparison function to match actions.
--- @param options ListRemoveOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, removes all matching actions instead of just the first.
--- @return khaoslib.AmmoTypeManipulator self The same ammo type manipulation object for method chaining.
function khaoslib_ammo_type:remove_action(compare, options)
  if type(compare) ~= "function" then error("compare parameter: Expected function, got " .. type(compare), 2) end

  populate_actions(self.ammo_type)
  self.ammo_type.action = khaoslib_list.remove(self.ammo_type.action --[[@as data.TriggerItem[] ]], compare, options)

  depopulate_actions(self.ammo_type)
  return self
end

--- Replaces matching action with a new action.
--- If no matching actions are found, no changes are made.
--- @param compare fun(action: data.TriggerItem): boolean A comparison function to match actions.
--- @param replacement khaoslib.TriggerItemManipulator|data.TriggerItem|fun(action: data.TriggerItem): data.TriggerItem The new action to replace with.
--- @param options ListReplaceOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, replaces all matching actions instead of just the first.
--- @return khaoslib.AmmoTypeManipulator self The same ammo type manipulation object for method chaining.
--- @throws If compare is not a string or function, or replacement is not a table or function.
function khaoslib_ammo_type:replace_action(compare, replacement, options)
  if type(compare) ~= "function" then error("compare parameter: Expected function, got " .. type(compare), 2) end
  if type(replacement) ~= "table" and type(replacement) ~= "function" then error("replacement parameter: Expected table or function, got " .. type(replacement), 2) end

  populate_actions(self.ammo_type)
  --- @diagnostic disable-next-line: assign-type-mismatch, param-type-mismatch
  self.ammo_type.action = khaoslib_list.replace(self.ammo_type.action --[[@as data.TriggerItem[] ]], (type(replacement) == "table" and replacement.get) and replacement:get() or replacement, compare, options)

  depopulate_actions(self.ammo_type)
  return self
end

--- Removes all actions from the ammo type.
--- @return khaoslib.AmmoTypeManipulator self The same ammo type manipulation object for method chaining.
function khaoslib_ammo_type:clear_actions()
  self.ammo_type.action = nil

  return self
end

--#endregion

return khaoslib_ammo_type
