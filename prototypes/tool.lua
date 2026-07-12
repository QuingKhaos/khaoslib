local khaoslib_list = require("__khaoslib__.common.list")
local util = require("util")

--#region Basic manipulation methods
-- A set of basic methods for creating and working with tool manipulation objects.

--- Tool manipulation utilities for Factorio data stage.
---
--- This module provides a fluent API for creating, modifying, and managing tool prototypes
--- during the data stage. It supports method chaining and uses the list utility module for
--- consistent prerequisite and effect manipulation.
--- @class khaoslib.ToolManipulator
--- @field private tool data.ToolPrototype The tool currently being manipulated.
--- @operator add(khaoslib.ToolManipulator): khaoslib.ToolManipulator
local khaoslib_tool = {}

--- Loads a given tool for manipulation or creates a new one if a table is passed.
--- @param tool data.ItemID|data.ToolPrototype The name of an existing tool or a new tool prototype table.
--- @return khaoslib.ToolManipulator manipulator A tool manipulation object for the given tool.
--- @throws If the tool name doesn't exist or if a table is passed with a name that already exists or without a valid name field.
function khaoslib_tool:load(tool)
  local tool_type = type(tool)
  if tool_type ~= "string" and tool_type ~= "table" then error("tool parameter: Expected string or table , got " .. tool_type, 2) end

  if tool_type == "string" then
    if not khaoslib_tool.exists(tool) then error("No such tool: " .. tool, 2) end
  else -- tool_type == "table"
    if tool.type and type(tool.type) ~= "string" then error("tool table type field should be a string if set", 2) end
    if tool.type and tool.type ~= "tool" then error("tool table type field should be 'tool' if set", 2) end
    if not tool.name or type(tool.name) ~= "string" then error("tool table must have a name field of type string", 2) end
    if khaoslib_tool.exists(tool.name) then error("A tool with the name " .. tool.name .. " already exists", 2) end
  end

  local _tool = tool --luacheck: ignore 311
  if tool_type == "string" then
    _tool = util.table.deepcopy(data.raw.tool[tool])
  else
    _tool = util.table.deepcopy(tool)
    _tool.type = "tool"
  end

  --- @cast _tool data.ToolPrototype
  --- @type khaoslib.ToolManipulator
  local obj = {tool = _tool}
  setmetatable(obj, self)
  self.__index = self

  return obj
end

--- @diagnostic disable: invisible

--- Internal helper function to resolve the tool from a string, tool prototype data or a tool manipulation object.
--- @param tool data.ItemID|data.ToolPrototype|khaoslib.ToolManipulator The tool to resolve.
--- @return data.ToolPrototype resolved_tool The resolved tool prototype.
--- @throws If the tool cannot be resolved.
local resolve = function(tool)
  if type(tool) == "string" then
    local result = data.raw.tool[tool]
    if not result then
      error("No such tool: " .. tool, 3)
    end

    return result
  elseif type(tool) == "table" then
    if getmetatable(tool) == khaoslib_tool and tool.tool then
      return tool.tool
    elseif tool.type == "tool" and tool.name then
      return tool --[[@as data.ToolPrototype]]
    else
      error("Invalid tool table: expected manipulator or prototype with type='tool' and name", 3)
    end
  else
    error("Invalid tool parameter: expected tool name, prototype table, or tool manipulator", 3)
  end
end

--- @diagnostic enable: invisible

--- Gets the raw data table of the tool.
--- @param tool data.ItemID|data.ToolPrototype|khaoslib.ToolManipulator The tool.
--- @return data.ToolPrototype tool A deep copy of the tool data.
--- @nodiscard
function khaoslib_tool.get(tool)
  return util.table.deepcopy(resolve(tool)) --[[@as data.ToolPrototype]]
end

--- @class khaoslib_tool.ToolPrototype : data.ToolPrototype
--- @field type? string
--- @field name? string
--- @field stack_size? data.ItemCountType

--- Merges the given fields into the tool.
--- @param fields khaoslib_tool.ToolPrototype A table of fields to merge into the tool. See `data.ToolPrototype` for valid fields.
--- @return khaoslib.ToolManipulator self The same tool manipulation object for method chaining.
--- @throws If fields is not a table or if it contains a name field.
function khaoslib_tool:set(fields)
  if type(fields) ~= "table" then error("fields parameter: Expected table, got " .. type(fields), 2) end
  if fields.type then error("Cannot change the type of a tool.", 2) end
  if fields.name then error("Cannot change the name of a tool using set(). Use copy() to create a new tool with a different name.", 2) end

  self.tool = util.merge({self.tool, util.table.deepcopy(fields)})

  return self
end

--- Unsets the given field in the tool currently being manipulated.
--- @param field string The field to unset in the tool. See `data.ToolPrototype` for valid fields.
--- @return khaoslib.ToolManipulator self The same tool manipulation object for method chaining.
--- @throws If field is not a string, or if it is the type or name field.
function khaoslib_tool:unset(field)
  if type(field) ~= "string" then error("field parameter: Expected string, got " .. type(field), 2) end
  if field == "type" then error("Cannot unset the type of a tool.", 2) end
  if field == "name" then error("Cannot unset the name of a tool.", 2) end

  self.tool[field] = nil

  return self
end

--- Creates a deep copy of the tool.
--- @param tool data.ItemID|data.ToolPrototype|khaoslib.ToolManipulator The tool.
--- @param new_name data.ItemID The name of the new tool. Must not already exist.
--- @return khaoslib.ToolManipulator tool A new tool manipulation object with a deep copy of the tool.
--- @throws If a tool with the new name already exists.
--- @nodiscard
function khaoslib_tool.copy(tool, new_name)
  local copy = util.table.deepcopy(resolve(tool))
  copy.name = new_name

  return khaoslib_tool:load(copy)
end

--- Commits the changes to the data stage.
--- If the tool already exists, it is overwritten.
--- @return khaoslib.ToolManipulator self The same tool manipulation object for method chaining.
function khaoslib_tool:commit()
  self:remove()
  data:extend({self:get()})

  return self
end

--- Deletes the tool from the data stage instantly. Use with caution, as this works without a commit.
--- @param tool data.ItemID|data.ToolPrototype The tool.
--- @return nil
--- @overload fun(self: khaoslib.ToolManipulator): khaoslib.ToolManipulator
function khaoslib_tool.remove(tool)
  data.raw.tool[resolve(tool).name] = nil

  if type(tool) == "table" and getmetatable(tool) == khaoslib_tool then
    return tool --[[@as khaoslib.ToolManipulator]]
  end
end

--- Merges another tool manipulation object into this one, excluding the name field.
--- @param other khaoslib.ToolManipulator The other tool manipulation object to merge into this one
--- @return khaoslib.ToolManipulator self The same tool manipulation object for method chaining.
--- @throws If other is not a tool manipulation object.
function khaoslib_tool:__add(other)
  if type(other) ~= "table" or getmetatable(other) ~= khaoslib_tool then
    error("Can only concatenate with another khaoslib.ToolManipulator object", 2)
  end

  local other_copy = other:get()
  other_copy.type = nil
  other_copy.name = nil

  return self:set(other_copy --[[@as khaoslib_tool.ToolPrototype]])
end

--- Compares two tool manipulation objects for equality based on the tool name.
--- @param other khaoslib.ToolManipulator The other tool manipulation object to compare with.
--- @return boolean is_equal True if the two tool manipulation objects represent the same tool, false otherwise.
function khaoslib_tool:__eq(other)
  if type(other) ~= "table" or getmetatable(other) ~= khaoslib_tool then return false end

  return self.tool.name == other.tool.name
end

--- Returns a string representation of the tool manipulation object.
--- @return string representation A string representation of the tool manipulation object.
function khaoslib_tool:__tostring()
  return "[khaoslib_tool: " .. self.tool.name .. "]"
end

--#endregion

--#region Tool manipulation methods
-- A set of utility functions for manipulating tools.

--- If the tool has a single icon, it is converted to the icons list format. If the tool already has an icons list, no changes are made.
--- @param tool data.ToolPrototype The tool reference to populate icons for.
local populate_icons = function(tool)
  if tool.icon and (not tool.icons or #tool.icons == 0) then
    tool.icons = {{icon = tool.icon, icon_size = tool.icon_size or nil}}
    tool.icon = nil
    tool.icon_size = nil
  end
end

--- If just a single tool exists in the icons list, and it has no special properties, depopulate the icons list and set the icon and icon_size fields instead.
--- @param tool data.ToolPrototype The tool reference to depopulate icons from.
local depopulate_icons = function(tool)
  if #tool.icons == 1 then
    local icon = tool.icons[1]
    if icon.tint == nil and icon.shift == nil and icon.scale == nil and icon.draw_background == nil and icon.floating == nil then
      tool.icon = icon.icon
      tool.icon_size = icon.icon_size or nil
      tool.icons = nil
    end
  end
end

--- Returns a deepcopy of all icons for the given tool. If the tool has a single icon, it is returned as a single-element list.
--- @param tool data.ItemID|data.ToolPrototype|khaoslib.ToolManipulator The tool.
--- @return data.IconData[] icons A list of icons for the tool.
--- @nodiscard
function khaoslib_tool.get_icons(tool)
  local resolved_tool = resolve(tool)
  if resolved_tool.icons then
    return util.table.deepcopy(resolved_tool.icons --[=[@as data.IconData[]]=])
  elseif resolved_tool.icon then
    return util.table.deepcopy({{icon = resolved_tool.icon, icon_size = resolved_tool.icon_size or nil}})
  else
    return {}
  end
end

--- Returns a deep-copied list of all icons for the given tool that match the given criteria.
--- @param tool data.ItemID|data.ToolPrototype|khaoslib.ToolManipulator The tool.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @return data.IconData[] icons A list of matching icons.
--- @throws If compare is not a string or function.
--- @nodiscard
function khaoslib_tool.find_icons(tool, compare)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  local resolved_tool = resolve(tool)
  populate_icons(resolved_tool)

  local result = khaoslib_list.find(resolved_tool.icons, compare_fn)
  depopulate_icons(resolved_tool)

  return result
end

--- Sets the list of icons for the tool currently being manipulated, replacing any existing icons.
--- @param icons data.IconData[] A list of icons to set.
--- @return khaoslib.ToolManipulator self The same tool manipulation object for method chaining.
--- @throws If icons is not a table.
function khaoslib_tool:set_icons(icons)
  if type(icons) ~= "table" then error("icons parameter: Expected table, got " .. type(icons), 2) end

  self.tool.icon = nil
  self.tool.icon_size = nil
  self.tool.icons = util.table.deepcopy(icons)
  depopulate_icons(self.tool)

  return self
end

--- Returns the number of icons for the given tool.
--- @param tool data.ItemID|data.ToolPrototype|khaoslib.ToolManipulator The tool.
--- @return integer count The number of icons.
--- @nodiscard
function khaoslib_tool.count_icons(tool)
  local resolved_tool = resolve(tool)
  return resolved_tool.icon ~= nil and 1 or #(resolved_tool.icons or {})
end

--- Checks if the tool has an icon matching the given criteria.
--- Supports both string matching (by icon filename) and custom comparison functions.
--- @param tool data.ItemID|data.ToolPrototype|khaoslib.ToolManipulator The tool.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @return boolean has_icon True if the tool has the icon, false otherwise.
--- @throws If compare is not a string or function.
--- @nodiscard
function khaoslib_tool.has_icon(tool, compare)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  local resolved_tool = resolve(tool)
  populate_icons(resolved_tool)

  local result = khaoslib_list.has(resolved_tool.icons, compare_fn)
  depopulate_icons(resolved_tool)

  return result
end

--- Gets the first icon (deep-copy) that matches the given criteria.
--- Supports both string matching (by icon filename) and custom comparison functions.
--- @param tool data.ItemID|data.ToolPrototype|khaoslib.ToolManipulator The tool.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @return data.IconData? icon The first matching icon, or nil if no match is found.
--- @throws If compare is not a string or function.
--- @nodiscard
function khaoslib_tool.get_icon(tool, compare)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  local resolved_tool = resolve(tool)
  populate_icons(resolved_tool)

  local result = khaoslib_list.get(resolved_tool.icons, compare_fn)
  depopulate_icons(resolved_tool)

  return result
end

--- Adds an icon to the tool, allows duplicates.
--- @param icon data.IconData The icon data to add.
--- @param options ListAddIndexOptions? Options table with fields:
---   - `index` (integer, optional): If provided, inserts the icon at the specified index instead of appending to the end of the list.
--- @return khaoslib.ToolManipulator self The same tool manipulation object for method chaining.
--- @throws If icon is not a table or doesn't have required fields.
function khaoslib_tool:add_icon(icon, options)
  if type(icon) ~= "table" then error("icon parameter: Expected table, got " .. type(icon), 2) end
  if not icon.icon or type(icon.icon) ~= "string" then error("icon parameter: Must have an icon field of type string", 2) end

  options = options or {}
  --- @cast options ListAddOptions
  options.allow_duplicates = true

  populate_icons(self.tool)
  self.tool.icons = khaoslib_list.add(self.tool.icons, icon, nil, options)
  depopulate_icons(self.tool)

  return self
end

--- Removes matching icons from the tool.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @param options ListRemoveOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, removes all matching icons instead of just the first.
--- @return khaoslib.ToolManipulator self The same tool manipulation object for method chaining.
--- @throws If compare is not a string or function.
function khaoslib_tool:remove_icon(compare, options)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  populate_icons(self.tool)
  self.tool.icons = khaoslib_list.remove(self.tool.icons, compare_fn, options)
  depopulate_icons(self.tool)

  return self
end

--- Replaces matching icons with a new icon.
--- If no matching icons are found, no changes are made.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @param replacement (fun(icon: data.IconData): data.IconData)|data.IconData The new icon data to replace with.
--- @param options ListReplaceOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, replaces all matching icons instead of just the first.
--- @return khaoslib.ToolManipulator self The same tool manipulation object for method chaining.
--- @throws If compare is not a string or function, or replacement is not a table or function.
function khaoslib_tool:replace_icon(compare, replacement, options)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  if type(replacement) ~= "table" and type(replacement) ~= "function" then error("replacement parameter: Expected table or function, got " .. type(replacement), 2) end
  if type(replacement) == "table" then
    if not replacement.icon or type(replacement.icon) ~= "string" then error("replacement parameter: Must have an icon field of type string", 2) end
  end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  populate_icons(self.tool)
  self.tool.icons = khaoslib_list.replace(self.tool.icons, replacement, compare_fn, options)
  depopulate_icons(self.tool)

  return self
end

--- Removes all icons from the tool.
--- @return khaoslib.ToolManipulator self The same tool manipulation object for method chaining.
function khaoslib_tool:clear_icons()
  self.tool.icon = nil
  self.tool.icon_size = nil
  self.tool.icons = nil

  return self
end

--#endregion

--#region Utility functions
-- Module-level utility functions for tool discovery and analysis.

--- Checks if a tool exists in the data stage.
--- @param name data.ItemID The tool name to check.
--- @return boolean exists True if the tool exists, false otherwise.
--- @nodiscard
function khaoslib_tool.exists(name)
  if type(name) ~= "string" then error("name parameter: Expected string, got " .. type(name), 2) end

  return data.raw.tool[name] ~= nil
end

--- Finds all tools that match a custom compare function.
--- @param compare_fn fun(tool: data.ToolPrototype): boolean A function that returns true for tools to include.
--- @return data.ItemID[] tools A list of tool names that match the compare function.
--- @throws If compare_fn is not a function.
--- @nodiscard
function khaoslib_tool.find(compare_fn)
  if type(compare_fn) ~= "function" then error("compare_fn parameter: Expected function, got " .. type(compare_fn), 2) end

  local result = {}
  for _, tool in pairs(data.raw.tool or {}) do
    if compare_fn(tool) then
      table.insert(result, tool.name)
    end
  end

  return result
end

--#endregion

return khaoslib_tool
