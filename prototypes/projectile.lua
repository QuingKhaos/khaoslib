local khaoslib_list = require("__khaoslib__.common.list")
local khaoslib_trigger_item = require("__khaoslib__.prototypes.trigger-item")

--#region Basic manipulation methods
-- A set of basic methods for creating and working with projectile manipulation objects.

--- Projectile manipulation utilities for Factorio data stage.
---
--- This module provides a fluent API for creating, modifying, and managing projectile prototypes
--- during the data stage. It supports method chaining and uses the list utility module for
--- consistent prerequisite and effect manipulation.
--- @class khaoslib.ProjectileManipulator
--- @field private projectile data.ProjectilePrototype The projectile currently being manipulated.
--- @operator add(khaoslib.ProjectileManipulator): khaoslib.ProjectileManipulator
local khaoslib_projectile = {}

--- Loads a given projectile for manipulation or creates a new one if a table is passed.
--- @param projectile data.ItemID|data.ProjectilePrototype The name of an existing projectile or a new projectile prototype table.
--- @return khaoslib.ProjectileManipulator manipulator A projectile manipulation object for the given projectile.
--- @throws If the projectile name doesn't exist or if a table is passed with a name that already exists or without a valid name field.
function khaoslib_projectile:load(projectile)
  local projectile_type = type(projectile)
  if projectile_type ~= "string" and projectile_type ~= "table" then error("projectile parameter: Expected string or table , got " .. projectile_type, 2) end

  if projectile_type == "string" then
    if not khaoslib_projectile.exists(projectile) then error("No such projectile: " .. projectile, 2) end
  else -- projectile_type == "table"
    if projectile.type and type(projectile.type) ~= "string" then error("projectile table type field should be a string if set", 2) end
    if projectile.type and projectile.type ~= "projectile" then error("projectile table type field should be 'projectile' if set", 2) end
    if not projectile.name or type(projectile.name) ~= "string" then error("projectile table must have a name field of type string", 2) end
    if khaoslib_projectile.exists(projectile.name) then error("A projectile with the name " .. projectile.name .. " already exists", 2) end
  end

  local _projectile = projectile --luacheck: ignore 311
  if projectile_type == "string" then
    _projectile = util.table.deepcopy(data.raw["projectile"][projectile])
  else
    _projectile = util.table.deepcopy(projectile)
    _projectile.type = "projectile"
  end

  --- @diagnostic disable-next-line: missing-fields
  --- @cast _projectile data.ProjectilePrototype
  --- @type khaoslib.ProjectileManipulator
  local obj = {projectile = _projectile}
  setmetatable(obj, self)
  self.__index = self

  return obj
end

--- Internal helper function to resolve the projectile from a string, projectile prototype data or a projectile manipulation object.
--- @param projectile data.ItemID|data.ProjectilePrototype|khaoslib.ProjectileManipulator The projectile to resolve.
--- @return data.ProjectilePrototype resolved_projectile The resolved projectile prototype.
--- @throws If the projectile cannot be resolved.
local resolve = function(projectile)
  if type(projectile) == "string" then
    local result = data.raw["projectile"][projectile]
    if not result then
      error("No such projectile: " .. projectile, 3)
    end

    return result
  elseif type(projectile) == "table" then
    --- @diagnostic disable: access-invisible
    if getmetatable(projectile) == khaoslib_projectile and projectile.projectile then
      return projectile.projectile
    elseif projectile.type == "projectile" and projectile.name then
      return projectile --[[@as data.ProjectilePrototype]]
    else
      error("Invalid projectile table: expected manipulator or prototype with type='projectile' and name", 3)
    end
    --- @diagnostic enable: access-invisible
  else
    error("Invalid projectile parameter: expected projectile name, prototype table, or projectile manipulator", 3)
  end
end

--- Gets the raw data table of the projectile.
--- @param projectile data.ItemID|data.ProjectilePrototype|khaoslib.ProjectileManipulator The projectile.
--- @return data.ProjectilePrototype projectile A deep copy of the projectile data.
--- @nodiscard
function khaoslib_projectile.get(projectile)
  return util.table.deepcopy(resolve(projectile)) --[[@as data.ProjectilePrototype]]
end

--- @class khaoslib_projectile.ProjectilePrototype : data.ProjectilePrototype
--- @field type? string
--- @field name? string
--- @field acceleration? double

--- Merges the given fields into the projectile.
--- @param fields khaoslib_projectile.ProjectilePrototype A table of fields to merge into the projectile. See `data.ProjectilePrototype` for valid fields.
--- @return khaoslib.ProjectileManipulator self The same projectile manipulation object for method chaining.
--- @throws If fields is not a table or if it contains a name field.
function khaoslib_projectile:set(fields)
  if type(fields) ~= "table" then error("fields parameter: Expected table, got " .. type(fields), 2) end
  if fields.type then error("Cannot change the type of a projectile.", 2) end
  if fields.name then error("Cannot change the name of a projectile using set(). Use copy() to create a new projectile with a different name.", 2) end

  self.projectile = util.merge({self.projectile, util.table.deepcopy(fields)})

  return self
end

--- Unsets the given field in the projectile currently being manipulated.
--- @param field string The field to unset in the projectile. See `data.ProjectilePrototype` for valid fields.
--- @return khaoslib.ProjectileManipulator self The same projectile manipulation object for method chaining.
--- @throws If field is not a string, or if it is the type or name field.
function khaoslib_projectile:unset(field)
  if type(field) ~= "string" then error("field parameter: Expected string, got " .. type(field), 2) end
  if field == "type" then error("Cannot unset the type of a projectile.", 2) end
  if field == "name" then error("Cannot unset the name of a projectile.", 2) end

  --- @diagnostic disable-next-line: undefined-field
  local fields_iter = field:gmatch("[^%.]+")
  local current = self.projectile
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

--- Creates a deep copy of the projectile.
--- @param projectile data.ItemID|data.ProjectilePrototype|khaoslib.ProjectileManipulator The projectile.
--- @param new_name data.ItemID The name of the new projectile. Must not already exist.
--- @return khaoslib.ProjectileManipulator projectile A new projectile manipulation object with a deep copy of the projectile.
--- @throws If a projectile with the new name already exists.
--- @nodiscard
function khaoslib_projectile.copy(projectile, new_name)
  local copy = util.table.deepcopy(resolve(projectile))
  copy.name = new_name

  return khaoslib_projectile:load(copy)
end

--- Commits the changes to the data stage.
--- If the projectile already exists, it is overwritten.
--- @return khaoslib.ProjectileManipulator self The same projectile manipulation object for method chaining.
function khaoslib_projectile:commit()
  self:remove()
  data:extend({self:get()})

  return self
end

--- Deletes the projectile from the data stage instantly. Use with caution, as this works without a commit.
--- @param projectile data.ItemID|data.ProjectilePrototype The projectile.
--- @return khaoslib.ProjectileManipulator? self The same projectile manipulation object if used on manipulation object or nil if used on a string or prototype.
--- @overload fun(item: data.ItemID|data.ProjectilePrototype)
--- @overload fun(self: khaoslib.ProjectileManipulator): khaoslib.ProjectileManipulator
function khaoslib_projectile.remove(projectile)
  data.raw["projectile"][resolve(projectile).name] = nil

  if type(projectile) == "table" and getmetatable(projectile) == khaoslib_projectile then
    return projectile --[[@as khaoslib.ProjectileManipulator]]
  end
end

--- Merges another projectile manipulation object into this one, excluding the name field.
--- @param other khaoslib.ProjectileManipulator The other projectile manipulation object to merge into this one
--- @return khaoslib.ProjectileManipulator self The same projectile manipulation object for method chaining.
--- @throws If other is not a projectile manipulation object.
function khaoslib_projectile:__add(other)
  if type(other) ~= "table" or getmetatable(other) ~= khaoslib_projectile then
    error("Can only concatenate with another khaoslib.ProjectileManipulator object", 2)
  end

  local other_copy = other:get()
  other_copy.type = nil
  other_copy.name = nil

  return self:set(other_copy --[[@as khaoslib_projectile.ProjectilePrototype]])
end

--- Compares two projectile manipulation objects for equality based on the projectile name.
--- @param other khaoslib.ProjectileManipulator The other projectile manipulation object to compare with.
--- @return boolean is_equal True if the two projectile manipulation objects represent the same projectile, false otherwise.
function khaoslib_projectile:__eq(other)
  if type(other) ~= "table" or getmetatable(other) ~= khaoslib_projectile then return false end

  return self.projectile.name == other.projectile.name
end

--- Returns a string representation of the projectile manipulation object.
--- @return string representation A string representation of the projectile manipulation object.
function khaoslib_projectile:__tostring()
  return "[khaoslib_projectile: " .. self.projectile.name .. "]"
end

--#endregion

--#region Projectile manipulation methods
-- A set of utility functions for manipulating projectiles.

--- If the projectile has a single icon, it is converted to the icons list format. If the projectile already has an icons list, no changes are made.
--- @param projectile data.ProjectilePrototype The projectile reference to populate icons for.
local populate_icons = function(projectile)
  if projectile.icon and (not projectile.icons or #projectile.icons == 0) then
    projectile.icons = {{icon = projectile.icon, icon_size = projectile.icon_size or nil}}
    projectile.icon = nil
    projectile.icon_size = nil
  end
end

--- If just a single projectile exists in the icons list, and it has no special properties, depopulate the icons list and set the icon and icon_size fields instead.
--- @param projectile data.ProjectilePrototype The projectile reference to depopulate icons from.
local depopulate_icons = function(projectile)
  if projectile.icons and #projectile.icons == 1 then
    local icon = projectile.icons[1]
    if icon.tint == nil and icon.shift == nil and icon.scale == nil and icon.draw_background == nil and icon.floating == nil then
      projectile.icon = icon.icon
      projectile.icon_size = icon.icon_size or nil
      projectile.icons = nil
    end
  end
end

--- Returns a deepcopy of all icons for the given projectile. If the projectile has a single icon, it is returned as a single-element list.
--- @param projectile data.ItemID|data.ProjectilePrototype|khaoslib.ProjectileManipulator The projectile.
--- @return data.IconData[] icons A list of icons for the projectile.
--- @nodiscard
function khaoslib_projectile.get_icons(projectile)
  local resolved_projectile = resolve(projectile)
  if resolved_projectile.icons then
    return util.table.deepcopy(resolved_projectile.icons --[[@as data.IconData[] ]])
  elseif resolved_projectile.icon then
    return util.table.deepcopy({{icon = resolved_projectile.icon, icon_size = resolved_projectile.icon_size or nil}})
  else
    return {}
  end
end

--- Returns a deep-copied list of all icons for the given projectile that match the given criteria.
--- @param projectile data.ItemID|data.ProjectilePrototype|khaoslib.ProjectileManipulator The projectile.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @return data.IconData[] icons A list of matching icons.
--- @throws If compare is not a string or function.
--- @nodiscard
function khaoslib_projectile.find_icons(projectile, compare)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  local resolved_projectile = resolve(projectile)
  populate_icons(resolved_projectile)

  local result = khaoslib_list.find(resolved_projectile.icons, compare_fn)
  depopulate_icons(resolved_projectile)

  return result
end

--- Sets the list of icons for the projectile currently being manipulated, replacing any existing icons.
--- @param icons data.IconData[] A list of icons to set.
--- @return khaoslib.ProjectileManipulator self The same projectile manipulation object for method chaining.
--- @throws If icons is not a table.
function khaoslib_projectile:set_icons(icons)
  if type(icons) ~= "table" then error("icons parameter: Expected table, got " .. type(icons), 2) end

  self.projectile.icon = nil
  self.projectile.icon_size = nil
  self.projectile.icons = util.table.deepcopy(icons)
  depopulate_icons(self.projectile)

  return self
end

--- Returns the number of icons for the given projectile.
--- @param projectile data.ItemID|data.ProjectilePrototype|khaoslib.ProjectileManipulator The projectile.
--- @return integer count The number of icons.
--- @nodiscard
function khaoslib_projectile.count_icons(projectile)
  local resolved_projectile = resolve(projectile)
  return resolved_projectile.icon ~= nil and 1 or #(resolved_projectile.icons or {})
end

--- Checks if the projectile has an icon matching the given criteria.
--- Supports both string matching (by icon filename) and custom comparison functions.
--- @param projectile data.ItemID|data.ProjectilePrototype|khaoslib.ProjectileManipulator The projectile.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @return boolean has_icon True if the capsule has the icon, false otherwise.
--- @throws If compare is not a string or function.
--- @nodiscard
function khaoslib_projectile.has_icon(projectile, compare)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  local resolved_projectile = resolve(projectile)
  populate_icons(resolved_projectile)

  local result = khaoslib_list.has(resolved_projectile.icons, compare_fn)
  depopulate_icons(resolved_projectile)

  return result
end

--- Gets the first icon (deep-copy) that matches the given criteria.
--- Supports both string matching (by icon filename) and custom comparison functions.
--- @param projectile data.ItemID|data.ProjectilePrototype|khaoslib.ProjectileManipulator The projectile.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @return data.IconData? icon The first matching icon, or nil if no match is found.
--- @throws If compare is not a string or function.
--- @nodiscard
function khaoslib_projectile.get_icon(projectile, compare)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  local resolved_projectile = resolve(projectile)
  populate_icons(resolved_projectile)

  local result = khaoslib_list.get(resolved_projectile.icons, compare_fn)
  depopulate_icons(resolved_projectile)

  return result
end

--- Adds an icon to the projectile, allows duplicates.
--- @param icon data.IconData The icon data to add.
--- @param options ListAddIndexOptions? Options table with fields:
---   - `index` (integer, optional): If provided, inserts the icon at the specified index instead of appending to the end of the list.
--- @return khaoslib.ProjectileManipulator self The same projectile manipulation object for method chaining.
function khaoslib_projectile:add_icon(icon, options)
  if type(icon) ~= "table" then error("icon parameter: Expected table, got " .. type(icon), 2) end
  if not icon.icon or type(icon.icon) ~= "string" then error("icon parameter: Must have an icon field of type string", 2) end

  options = options or {}
  --- @cast options ListAddOptions
  options.allow_duplicates = true

  populate_icons(self.projectile)
  self.projectile.icons = khaoslib_list.add(self.projectile.icons, icon, nil, options)
  depopulate_icons(self.projectile)

  return self
end

--- Removes matching icons from the projectile.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @param options ListRemoveOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, removes all matching icons instead of just the first.
--- @return khaoslib.ProjectileManipulator self The same projectile manipulation object for method chaining.
function khaoslib_projectile:remove_icon(compare, options)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  populate_icons(self.projectile)
  self.projectile.icons = khaoslib_list.remove(self.projectile.icons, compare_fn, options)
  depopulate_icons(self.projectile)

  return self
end

--- Replaces matching icons with a new icon.
--- If no matching icons are found, no changes are made.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @param replacement (fun(icon: data.IconData): data.IconData)|data.IconData The new icon data to replace with.
--- @param options ListReplaceOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, replaces all matching icons instead of just the first.
--- @return khaoslib.ProjectileManipulator self The same projectile manipulation object for method chaining.
function khaoslib_projectile:replace_icon(compare, replacement, options)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  if type(replacement) ~= "table" and type(replacement) ~= "function" then error("replacement parameter: Expected table or function, got " .. type(replacement), 2) end
  if type(replacement) == "table" then
    if not replacement.icon or type(replacement.icon) ~= "string" then error("replacement parameter: Must have an icon field of type string", 2) end
  end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  populate_icons(self.projectile)
  --- @diagnostic disable-next-line: assign-type-mismatch, param-type-mismatch
  self.projectile.icons = khaoslib_list.replace(self.projectile.icons, replacement, compare_fn, options)
  depopulate_icons(self.projectile)

  return self
end

--- Removes all icons from the projectile.
--- @return khaoslib.ProjectileManipulator self The same projectile manipulation object for method chaining.
function khaoslib_projectile:clear_icons()
  self.projectile.icon = nil
  self.projectile.icon_size = nil
  self.projectile.icons = nil

  return self
end
--- If the projectile has a single action, it is converted to the list format. If the projectile already has an action list, no changes are made.
--- @param projectile data.ProjectilePrototype The projectile reference to populate the actions for.
local function populate_actions(projectile)
  if projectile.action and projectile.action.type ~= nil then
    projectile.action = {projectile.action --[[@as data.TriggerItem]]}
  end
end

--- If just a single action exists in the actions list, depopulate the list.
--- @param projectile data.ProjectilePrototype The projectile reference to depopulate the actions list from.
local function depopulate_actions(projectile)
  if projectile.action and #projectile.action == 1 then
    projectile.action = projectile.action[1]
  end
end

--- Returns a deepcopy of all actions for the given projectile. If the projectile has a single action, it is returned as a single-element list.
--- @param projectile data.ProjectilePrototype|khaoslib.ProjectileManipulator The projectile.
--- @return khaoslib.TriggerItemManipulator[] actions A list of actions for the projectile.
--- @nodiscard
function khaoslib_projectile.get_actions(projectile)
  local resolved_projectile = resolve(projectile)
  if resolved_projectile.action then
    populate_actions(resolved_projectile)

    --- @type khaoslib.TriggerItemManipulator[]
    local result = {}

    if resolved_projectile.action then
      for _, action in ipairs(resolved_projectile.action) do
        table.insert(result, khaoslib_trigger_item:load(action))
      end
    end

    depopulate_actions(resolved_projectile)
    return result
  else
    return {}
  end
end

--- Returns a deep-copied list of all actions for the given projectile that match the given criteria.
--- @param projectile data.ProjectilePrototype|khaoslib.ProjectileManipulator The projectile.
--- @param compare fun(action: data.TriggerItem): boolean A comparison function
--- @return khaoslib.TriggerItemManipulator[] actions A list of matching actions.
--- @throws If compare is not a function.
--- @nodiscard
function khaoslib_projectile.find_actions(projectile, compare)
  if type(compare) ~= "function" then error("compare parameter: Expected function, got " .. type(compare), 2) end

  local resolved_projectile = resolve(projectile)
  populate_actions(resolved_projectile)

  --- @type khaoslib.TriggerItemManipulator[]
  local result = {}
  local find_result = khaoslib_list.find(resolved_projectile.action --[[@as data.TriggerItem[] ]], compare)

  for _, action in ipairs(find_result) do
    table.insert(result, khaoslib_trigger_item:load(action))
  end

  depopulate_actions(resolved_projectile)
  return result
end

--- Sets the list of actions for the projectile currently being manipulated, replacing any existing actions.
--- @param actions khaoslib.TriggerItemManipulator[] A list of actions to set.
--- @return khaoslib.ProjectileManipulator self The same projectile manipulation object for method chaining.
--- @throws If actions is not a table.
function khaoslib_projectile:set_actions(actions)
  if type(actions) ~= "table" then error("actions parameter: Expected table, got " .. type(actions), 2) end

  self.projectile.action = {}
  for _, action_manipulator in ipairs(actions) do
    table.insert(self.projectile.action, action_manipulator:get())
  end

  depopulate_actions(self.projectile)
  return self
end

--- Returns the number of actions for the given projectile.
--- @param projectile data.ProjectilePrototype|khaoslib.ProjectileManipulator The projectile.
--- @return integer count The number of actions.
--- @nodiscard
function khaoslib_projectile.count_actions(projectile)
  local resolved_projectile = resolve(projectile)
  if resolved_projectile.action then
    populate_actions(resolved_projectile)
    local count = #resolved_projectile.action

    depopulate_actions(resolved_projectile)
    return count
  else
    return 0
  end
end

--- Checks if the projectile has an action matching the given criteria.
--- @param projectile data.ProjectilePrototype|khaoslib.ProjectileManipulator The projectile.
--- @param compare fun(action: data.TriggerItem): boolean A comparison function
--- @return boolean has_action True if the ammo type has a matching action, false otherwise.
--- @throws If compare is not a function.
--- @nodiscard
function khaoslib_projectile.has_action(projectile, compare)
  if type(compare) ~= "function" then error("compare parameter: Expected function, got " .. type(compare), 2) end

  local resolved_projectile = resolve(projectile)
  populate_actions(resolved_projectile)

  local result = khaoslib_list.has(resolved_projectile.action --[[@as data.TriggerItem[] ]], compare)
  depopulate_actions(resolved_projectile)

  return result
end

--- Gets the first action (deep-copy) that matches the given criteria.
--- @param projectile data.ProjectilePrototype|khaoslib.ProjectileManipulator The projectile.
--- @param compare (fun(action: data.TriggerItem): boolean) A comparison function
--- @return khaoslib.TriggerItemManipulator? action The first matching action, or nil if no match is found.
--- @throws If compare is not a function.
--- @nodiscard
function khaoslib_projectile.get_action(projectile, compare)
  if type(compare) ~= "function" then error("compare parameter: Expected function, got " .. type(compare), 2) end

  local resolved_projectile = resolve(projectile)
  populate_actions(resolved_projectile)

  local found = khaoslib_list.get(resolved_projectile.action --[[@as data.TriggerItem[] ]], compare)
  depopulate_actions(resolved_projectile)

  if found then
    return khaoslib_trigger_item:load(found)
  else
    return nil
  end
end

--- Adds an action to the projectile, allows duplicates.
--- @param action khaoslib.TriggerItemManipulator|data.TriggerItem The action to add.
--- @param options ListAddIndexOptions? Options table with fields:
---   - `index` (integer, optional): If provided, inserts the action at the specified index instead of appending to the end of the list.
--- @return khaoslib.ProjectileManipulator self The same projectile manipulation object for method chaining.
function khaoslib_projectile:add_action(action, options)
  if type(action) ~= "table" then error("action parameter: Expected table, got " .. type(action), 2) end

  options = options or {}
  --- @cast options ListAddOptions
  options.allow_duplicates = true

  populate_actions(self.projectile)
  self.projectile.action = khaoslib_list.add(self.projectile.action --[[@as data.TriggerItem[] ]], (type(action) == "table" and action.get) and action:get() or (action --[[@as data.TriggerItem]]), nil, options)

  depopulate_actions(self.projectile)
  return self
end

--- Removes matching action from the projectile.
--- @param compare (fun(action: data.TriggerItem): boolean) A comparison function to match actions.
--- @param options ListRemoveOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, removes all matching actions instead of just the first.
--- @return khaoslib.ProjectileManipulator self The same projectile manipulation object for method chaining.
function khaoslib_projectile:remove_action(compare, options)
  if type(compare) ~= "function" then error("compare parameter: Expected function, got " .. type(compare), 2) end

  populate_actions(self.projectile)
  self.projectile.action = khaoslib_list.remove(self.projectile.action --[[@as data.TriggerItem[] ]], compare, options)

  depopulate_actions(self.projectile)
  return self
end

--- Replaces matching action with a new action.
--- If no matching actions are found, no changes are made.
--- @param compare fun(action: data.TriggerItem): boolean A comparison function to match actions.
--- @param replacement khaoslib.TriggerItemManipulator|data.TriggerItem|fun(action: data.TriggerItem): data.TriggerItem The new action to replace with.
--- @param options ListReplaceOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, replaces all matching actions instead of just the first.
--- @return khaoslib.ProjectileManipulator self The same projectile manipulation object for method chaining.
function khaoslib_projectile:replace_action(compare, replacement, options)
  if type(compare) ~= "function" then error("compare parameter: Expected function, got " .. type(compare), 2) end
  if type(replacement) ~= "table" and type(replacement) ~= "function" then error("replacement parameter: Expected table or function, got " .. type(replacement), 2) end

  populate_actions(self.projectile)
  --- @diagnostic disable-next-line: assign-type-mismatch, param-type-mismatch
  self.projectile.action = khaoslib_list.replace(self.projectile.action --[[@as data.TriggerItem[] ]], (type(replacement) == "table" and replacement.get) and replacement:get() or replacement, compare, options)

  depopulate_actions(self.projectile)
  return self
end

--- Removes all actions from the projectile.
--- @return khaoslib.ProjectileManipulator self The same projectile manipulation object for method chaining.
function khaoslib_projectile:clear_actions()
  self.projectile.action = nil

  return self
end

--#endregion

--#region Utility functions
-- Module-level utility functions for projectile discovery and analysis.

--- Checks if an projectile exists in the data stage.
--- @param name data.ItemID The projectile name to check.
--- @return boolean exists True if the projectile exists, false otherwise.
function khaoslib_projectile.exists(name)
  if type(name) ~= "string" then error("name parameter: Expected string, got " .. type(name), 2) end

  return data.raw["projectile"][name] ~= nil
end

--- Finds all projectiles that match a custom compare function.
--- @param compare_fn fun(projectile: data.ProjectilePrototype): boolean A function that returns true for projectiles to include.
--- @return data.ItemID[] projectiles A list of projectile names that match the compare function.
--- @throws If compare_fn is not a function.
--- @nodiscard
function khaoslib_projectile.find(compare_fn)
  if type(compare_fn) ~= "function" then error("compare_fn parameter: Expected function, got " .. type(compare_fn), 2) end

  local result = {}
  for _, projectile in pairs(data.raw["projectile"] or {}) do
    if compare_fn(projectile) then
      table.insert(result, projectile.name)
    end
  end

  return result
end

--#endregion

return khaoslib_projectile
