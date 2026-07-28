local khaoslib_list = require("__khaoslib__.common.list")
local khaoslib_trigger_delivery_item = require("__khaoslib__.prototypes.trigger-delivery-item")

--#region Basic manipulation methods
-- A set of basic methods for creating and working with trigger item manipulation objects.

--- Trigger item manipulation utilities for Factorio data stage.
---
--- This module provides a fluent API for creating, modifying, and managing trigger items
--- during the data stage. It supports method chaining and uses the list utility module for
--- consistent prerequisite and effect manipulation.
--- @class khaoslib.TriggerItemManipulator
--- @field private trigger_item data.TriggerItem The trigger item currently being manipulated.
--- @operator add(khaoslib.TriggerItemManipulator): khaoslib.TriggerItemManipulator
local khaoslib_trigger_item = {}

--- Loads a given trigger item for manipulation.
--- @param trigger_item data.TriggerItem The trigger item to manipulate.
--- @return khaoslib.TriggerItemManipulator manipulator A trigger item manipulation object for the given trigger item.
--- @throws If the trigger item is invalid.
function khaoslib_trigger_item:load(trigger_item)
  if type(trigger_item) ~= "table" then error("trigger_item parameter: Expected table, got " .. type(trigger_item), 2) end

  local _trigger_item = util.table.deepcopy(trigger_item)

  --- @diagnostic disable-next-line: missing-fields
  --- @type khaoslib.TriggerItemManipulator
  local obj = {trigger_item = _trigger_item}
  setmetatable(obj, self)
  self.__index = self

  return obj
end

--- Internal helper function to resolve the trigger item from data or a trigger item manipulation object.
--- @param trigger_item data.TriggerItem|khaoslib.TriggerItemManipulator The trigger item to resolve.
--- @return data.TriggerItem resolved_trigger_item The resolved trigger item.
--- @throws If the trigger item cannot be resolved.
local resolve = function(trigger_item)
  if type(trigger_item) == "table" then
    --- @diagnostic disable: access-invisible
    if getmetatable(trigger_item) == khaoslib_trigger_item and trigger_item.trigger_item then
      return trigger_item.trigger_item
    else
      return trigger_item --[[@as data.TriggerItem]]
    end
    --- @diagnostic enable: access-invisible
  else
    error("Invalid trigger item parameter: expected trigger item table or trigger item manipulator", 3)
  end
end

--- Gets the raw data table of the trigger item.
--- @param trigger_item data.TriggerItem|khaoslib.TriggerItemManipulator The trigger item.
--- @return data.TriggerItem trigger_item A deep copy of the trigger item data.
--- @nodiscard
function khaoslib_trigger_item.get(trigger_item)
  return util.table.deepcopy(resolve(trigger_item))
end

--- Merges the given fields into the trigger item.
--- @param fields data.TriggerItem A table of fields to merge into the trigger item. See `data.TriggerItem` for valid fields.
--- @return khaoslib.TriggerItemManipulator self The same trigger item manipulation object for method chaining.
--- @throws If fields is not a table
function khaoslib_trigger_item:set(fields)
  if type(fields) ~= "table" then error("fields parameter: Expected table, got " .. type(fields), 2) end

  self.trigger_item = util.merge({self.trigger_item, util.table.deepcopy(fields)})

  return self
end

--- Unsets the given field in the trigger item currently being manipulated.
--- @param field string The field to unset in the trigger item. See `data.TriggerItem` for valid fields.
--- @return khaoslib.TriggerItemManipulator self The same trigger item manipulation object for method chaining.
--- @throws If field is not a string
function khaoslib_trigger_item:unset(field)
  if type(field) ~= "string" then error("field parameter: Expected string, got " .. type(field), 2) end

  self.trigger_item[field] = nil

  return self
end

--- Merges another trigger item manipulation object into this one, excluding the name field.
--- @param other khaoslib.TriggerItemManipulator The other trigger item manipulation object to merge into this one.
--- @return khaoslib.TriggerItemManipulator self The same trigger item manipulation object for method chaining.
--- @throws If other is not a trigger item manipulation object.
function khaoslib_trigger_item:__add(other)
  if type(other) ~= "table" or getmetatable(other) ~= khaoslib_trigger_item then
    error("Can only concatenate with another khaoslib.TriggerItemManipulator object", 2)
  end

  local other_copy = other:get()

  return self:set(other_copy)
end

--#endregion

--#region Trigger item manipulation methods
-- A set of utility functions for manipulating trigger items.

--- If the trigger item has a single action delivery, it is converted to the list format. If the trigger item already has an action delivery list, no changes are made.
--- @param trigger_item data.TriggerItem The trigger item reference to populate the action deliveries for.
local function populate_action_deliveries(trigger_item)
  if trigger_item.action_delivery and trigger_item.action_delivery.type ~= nil then
    trigger_item.action_delivery = {trigger_item.action_delivery --[[@as data.TriggerDeliveryItem]]}
  end
end

--- If just a single action delivery exists in the action deliveries list, depopulate the list.
--- @param trigger_item data.TriggerItem The trigger item reference to depopulate the action deliveries list from.
local function depopulate_action_deliveries(trigger_item)
  if trigger_item.action_delivery and #trigger_item.action_delivery == 1 then
    trigger_item.action_delivery = trigger_item.action_delivery[1]
  end
end

--- Returns a deepcopy of all action deliveries for the given trigger item. If the trigger item has a single action delivery, it is returned as a single-element list.
--- @param trigger_item data.TriggerItem|khaoslib.TriggerItemManipulator The trigger item.
--- @return khaoslib.TriggerItemManipulator[] actions A list of action deliveries for the trigger item.
--- @nodiscard
function khaoslib_trigger_item.get_actions(trigger_item)
  local resolved_trigger_item = resolve(trigger_item)
  if resolved_trigger_item.action_delivery then
    populate_action_deliveries(resolved_trigger_item)

    --- @type khaoslib.TriggerItemManipulator[]
    local result = {}

    if resolved_trigger_item.action_delivery then
      for _, action_delivery in ipairs(resolved_trigger_item.action_delivery) do
        table.insert(result, khaoslib_trigger_delivery_item:load(action_delivery))
      end
    end

    depopulate_action_deliveries(resolved_trigger_item)
    return result
  else
    return {}
  end
end

--- Returns a deep-copied list of all action deliveries for the given trigger item that match the given criteria.
--- @param trigger_item data.TriggerItem|khaoslib.TriggerItemManipulator The trigger item.
--- @param compare fun(action_delivery: data.TriggerDeliveryItem): boolean A comparison function
--- @return khaoslib.TriggerDeliveryItemManipulator[] actions A list of matching action deliveries.
--- @throws If compare is not a function.
--- @nodiscard
function khaoslib_trigger_item.find_action_deliveries(trigger_item, compare)
  if type(compare) ~= "function" then error("compare parameter: Expected function, got " .. type(compare), 2) end

  local resolved_trigger_item = resolve(trigger_item)
  populate_action_deliveries(resolved_trigger_item)

  --- @type khaoslib.TriggerDeliveryItemManipulator[]
  local result = {}
  local find_result = khaoslib_list.find(resolved_trigger_item.action_delivery --[[@as data.TriggerDeliveryItem[] ]], compare)

  for _, action_delivery in ipairs(find_result) do
    table.insert(result, khaoslib_trigger_delivery_item:load(action_delivery))
  end

  depopulate_action_deliveries(resolved_trigger_item)
  return result
end

--- Sets the list of action deliveries for the trigger item currently being manipulated, replacing any existing action deliveries.
--- @param action_deliveries khaoslib.TriggerItemManipulator[] A list of action deliveries to set.
--- @return khaoslib.TriggerItemManipulator self The same trigger item manipulation object for method chaining.
--- @throws If action_deliveries is not a table.
function khaoslib_trigger_item:set_action_deliveries(action_deliveries)
  if type(action_deliveries) ~= "table" then error("action_deliveries parameter: Expected table, got " .. type(action_deliveries), 2) end

  self.trigger_item.action_delivery = {}
  for _, action_manipulator in ipairs(action_deliveries) do
    table.insert(self.trigger_item.action_delivery, action_manipulator:get())
  end

  depopulate_action_deliveries(self.trigger_item)
  return self
end

--- Returns the number of action deliveries for the given trigger item.
--- @param trigger_item data.TriggerItem|khaoslib.TriggerItemManipulator The trigger item.
--- @return integer count The number of action deliveries.
--- @nodiscard
function khaoslib_trigger_item.count_action_deliveries(trigger_item)
  local resolved_trigger_item = resolve(trigger_item)
  if resolved_trigger_item.action_delivery then
    populate_action_deliveries(resolved_trigger_item)
    local count = #resolved_trigger_item.action_delivery

    depopulate_action_deliveries(resolved_trigger_item)
    return count
  else
    return 0
  end
end

--- Checks if the trigger item has an action delivery matching the given criteria.
--- @param trigger_item data.TriggerItem|khaoslib.TriggerItemManipulator The trigger item.
--- @param compare fun(action_delivery: data.TriggerDeliveryItem): boolean A comparison function
--- @return boolean has_action True if the trigger item has a matching action delivery, false otherwise.
--- @throws If compare is not a function.
--- @nodiscard
function khaoslib_trigger_item.has_action_delivery(trigger_item, compare)
  if type(compare) ~= "function" then error("compare parameter: Expected function, got " .. type(compare), 2) end

  local resolved_trigger_item = resolve(trigger_item)
  populate_action_deliveries(resolved_trigger_item)

  local result = khaoslib_list.has(resolved_trigger_item.action_delivery --[[@as data.TriggerDeliveryItem[] ]], compare)
  depopulate_action_deliveries(resolved_trigger_item)

  return result
end

--- Gets the first action delivery (deep-copy) that matches the given criteria.
--- @param trigger_item data.TriggerItem|khaoslib.TriggerItemManipulator The trigger item.
--- @param compare (fun(action_delivery: data.TriggerDeliveryItem): boolean) A comparison function
--- @return khaoslib.TriggerDeliveryItemManipulator? action_delivery The first matching action delivery, or nil if no match is found.
--- @throws If compare is not a function.
--- @nodiscard
function khaoslib_trigger_item.get_action_delivery(trigger_item, compare)
  if type(compare) ~= "function" then error("compare parameter: Expected function, got " .. type(compare), 2) end

  local resolved_trigger_item = resolve(trigger_item)
  populate_action_deliveries(resolved_trigger_item)

  local found = khaoslib_list.get(resolved_trigger_item.action_delivery --[[@as data.TriggerDeliveryItem[] ]], compare)
  depopulate_action_deliveries(resolved_trigger_item)

  if found then
    return khaoslib_trigger_delivery_item:load(found)
  else
    return nil
  end
end

--- Adds an action delivery to the trigger item, allows duplicates.
--- @param action_delivery khaoslib.TriggerDeliveryItemManipulator|data.TriggerDeliveryItem The action delivery to add.
--- @param options ListAddIndexOptions? Options table with fields:
---   - `index` (integer, optional): If provided, inserts the action delivery at the specified index instead of appending to the end of the list.
--- @return khaoslib.TriggerItemManipulator self The same trigger item manipulation object for method chaining.
function khaoslib_trigger_item:add_action_delivery(action_delivery, options)
  if type(action_delivery) ~= "table" then error("action_delivery parameter: Expected table, got " .. type(action_delivery), 2) end

  options = options or {}
  --- @cast options ListAddOptions
  options.allow_duplicates = true

  populate_action_deliveries(self.trigger_item)
  self.trigger_item.action_delivery = khaoslib_list.add(self.trigger_item.action_delivery --[[@as data.TriggerDeliveryItem[] ]], (type(action_delivery) == "table" and action_delivery.get) and action_delivery:get() or (action_delivery --[[@as data.TriggerDeliveryItem]]), nil, options)

  depopulate_action_deliveries(self.trigger_item)
  return self
end

--- Removes matching action delivery from the trigger item.
--- @param compare (fun(action_delivery: data.TriggerDeliveryItem): boolean) A comparison function to match action deliveries.
--- @param options ListRemoveOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, removes all matching action deliveries instead of just the first.
--- @return khaoslib.TriggerItemManipulator self The same trigger item manipulation object for method chaining.
function khaoslib_trigger_item:remove_action_delivery(compare, options)
  if type(compare) ~= "function" then error("compare parameter: Expected function, got " .. type(compare), 2) end

  populate_action_deliveries(self.trigger_item)
  self.trigger_item.action_delivery = khaoslib_list.remove(self.trigger_item.action_delivery --[[@as data.TriggerDeliveryItem[] ]], compare, options)

  depopulate_action_deliveries(self.trigger_item)
  return self
end

--- Replaces matching action delivery with a new action delivery.
--- If no matching action deliveries are found, no changes are made.
--- @param compare fun(action_delivery: data.TriggerDeliveryItem): boolean A comparison function to match action deliveries.
--- @param replacement khaoslib.TriggerDeliveryItemManipulator|data.TriggerDeliveryItem|fun(action_delivery: data.TriggerDeliveryItem): data.TriggerDeliveryItem The new action delivery to replace with.
--- @param options ListReplaceOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, replaces all matching action deliveries instead of just the first.
--- @return khaoslib.TriggerItemManipulator self The same trigger item manipulation object for method chaining.
--- @throws If compare is not a function, or replacement is not a table or function.
function khaoslib_trigger_item:replace_action_delivery(compare, replacement, options)
  if type(compare) ~= "function" then error("compare parameter: Expected function, got " .. type(compare), 2) end
  if type(replacement) ~= "table" and type(replacement) ~= "function" then error("replacement parameter: Expected table or function, got " .. type(replacement), 2) end

  populate_action_deliveries(self.trigger_item)
  --- @diagnostic disable-next-line: assign-type-mismatch, param-type-mismatch
  self.trigger_item.action_delivery = khaoslib_list.replace(self.trigger_item.action_delivery --[[@as data.TriggerDeliveryItem[] ]], (type(replacement) == "table" and replacement.get) and replacement:get() or replacement, compare, options)

  depopulate_action_deliveries(self.trigger_item)
  return self
end

--- Removes all action deliveries from the trigger item.
--- @return khaoslib.TriggerItemManipulator self The same trigger item manipulation object for method chaining.
function khaoslib_trigger_item:clear_action_deliveries()
  self.trigger_item.action_delivery = nil

  return self
end

--#endregion

return khaoslib_trigger_item
