local khaoslib_list = require("__khaoslib__.list")
local util = require("util")

--#region Basic manipulation methods
-- A set of basic methods for creating and working with technology manipulation objects.

--- Technology manipulation utilities for Factorio data stage.
---
--- This module provides a fluent API for creating, modifying, and managing technology prototypes
--- during the data stage. It supports method chaining and uses the list utility module for
--- consistent prerequisite and effect manipulation.
---
--- ## Basic Usage Examples
---
--- ```lua
--- local khaoslib_technology = require("__khaoslib__.technology")
---
--- -- Load an existing technology for manipulation
--- khaoslib_technology:load("electronics")
---   :copy("electronics-with-solder")
---   :add_prerequisite("solder-tech")
---   :add_unlock_recipe("electronic-circuit-with-solder")
---   :commit()
---
--- -- Working with bulk operations
--- local tech = khaoslib_technology:load("advanced-electronics")
--- tech:remove_prerequisite(function(prereq)
---   return prereq:match("^basic%-")
--- end, {all = true}) -- removes all basic prerequisites
--- tech:replace_unlock_recipe("old-recipe", "new-recipe", {all = true})
---
--- -- Create a new technology from scratch
--- khaoslib_technology:load {
---   name = "advanced-electronics",
---   icon = "__mymod__/graphics/technology/advanced-electronics.png",
---   prerequisites = {"advanced-circuit"},
---   effects = {
---     {type = "unlock-recipe", recipe = "advanced-circuit-with-solder"},
---   },
---   -- other fields here
--- }:commit()
--- ```
---
--- @class khaoslib.TechnologyManipulator
--- @field private technology data.TechnologyPrototype The technology currently being manipulated.
--- @operator add(khaoslib.TechnologyManipulator): khaoslib.TechnologyManipulator
local khaoslib_technology = {}

--- Loads a given technology for manipulation or creates a new one if a table is passed.
--- @param technology data.TechnologyID|data.TechnologyPrototype The name of an existing technology or a new technology prototype table.
--- @return khaoslib.TechnologyManipulator manipulator A technology manipulation object for the given technology.
--- @throws If the technology name doesn't exist or if a table is passed with a name that already exists or without a valid name field.
function khaoslib_technology:load(technology)
  local tech_type = type(technology)
  if tech_type ~= "string" and tech_type ~= "table" then error("technology parameter: Expected string or table , got " .. tech_type, 2) end

  if tech_type == "string" then
    if not khaoslib_technology.exists(technology) then error("No such technology: " .. technology, 2) end
  else -- tech_type == "table"
    if technology.type and type(technology.type) ~= "string" then error("technology table type field should be a string if set", 2) end
    if technology.type and technology.type ~= "technology" then error("technology table type field should be 'technology' if set", 2) end
    if not technology.name or type(technology.name) ~= "string" then error("technology table must have a name field of type string", 2) end
    if khaoslib_technology.exists(technology.name) then error("A technology with the name " .. technology.name .. " already exists", 2) end
  end

  local _technology = technology --luacheck: ignore 311
  if tech_type == "string" then
    _technology = util.table.deepcopy(data.raw.technology[technology])
  else
    _technology = util.table.deepcopy(technology)
    _technology.type = "technology"
  end

  --- @cast _technology data.TechnologyPrototype
  --- @type khaoslib.TechnologyManipulator
  local obj = {technology = _technology}
  setmetatable(obj, self)
  self.__index = self

  return obj
end

--- @diagnostic disable: invisible

--- Internal helper function to resole the technology from a string, technology prototype data or a technology manipulation object.
--- @param technology data.TechnologyID|data.TechnologyPrototype|khaoslib.TechnologyManipulator The technology to resolve.
--- @return data.TechnologyPrototype resolved_technology The resolved technology prototype.
--- @throws If the technology cannot be resolved.
local resolve = function(technology)
  if type(technology) == "string" then
    local result = data.raw.technology[technology]
    if not result then
      error("No such technology: " .. technology, 3)
    end

    return result
  elseif type(technology) == "table" then
    if getmetatable(technology) == khaoslib_technology and technology.technology then
      return technology.technology
    elseif technology.type == "technology" and technology.name then
      return technology --[[@as data.TechnologyPrototype]]
    else
      error("Invalid technology table: expected manipulator or prototype with type='technology' and name", 3)
    end
  else
    error("Invalid technology parameter: expected technology name, prototype table, or technology manipulator", 3)
  end
end

--- @diagnostic enable: invisible

--- Gets the raw data table of the technology.
--- @return data.TechnologyPrototype technology A deep copy of the technology data.
--- @nodiscard
function khaoslib_technology:get()
  return util.table.deepcopy(self.technology) --[[@as data.TechnologyPrototype]]
end

--- Merges the given fields into the technology.
--- @param fields table A table of fields to merge into the technology. See `data.TechnologyPrototype` for valid fields.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If fields is not a table or if it contains a name field.
function khaoslib_technology:set(fields)
  if type(fields) ~= "table" then error("fields parameter: Expected table, got " .. type(fields), 2) end
  if fields.type then error("Cannot change the type of a technology.", 2) end
  if fields.name then error("Cannot change the name of a technology using set(). Use copy() to create a new technology with a different name.", 2) end

  self.technology = util.merge({self.technology, fields})

  return self
end

--- Unsets the given field in the technology currently being manipulated.
--- @param field string The field to unset in the technology. See `data.TechnologyPrototype` for valid fields.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If field is not a string, or if it is the type or name field.
function khaoslib_technology:unset(field)
  if type(field) ~= "string" then error("field parameter: Expected string, got " .. type(field), 2) end
  if field == "type" then error("Cannot unset the type of a technology.", 2) end
  if field == "name" then error("Cannot unset the name of a technology.", 2) end

  self.technology[field] = nil

  return self
end

--- Creates a deep copy of the technology.
--- @param technology data.TechnologyID|data.TechnologyPrototype|khaoslib.TechnologyManipulator The technology.
--- @param new_name data.TechnologyID The name of the new technology. Must not already exist.
--- @return khaoslib.TechnologyManipulator technology A new technology manipulation object with a deep copy of the technology.
--- @throws If a technology with the new name already exists.
--- @nodiscard
function khaoslib_technology.copy(technology, new_name)
  local copy = util.table.deepcopy(resolve(technology))
  copy.name = new_name

  return khaoslib_technology:load(copy)
end

--- Commits the changes to the data stage.
--- If the technology already exists, it is overwritten.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
function khaoslib_technology:commit()
  self:remove()
  data:extend({self:get()})

  return self
end

--- Deletes the technology from the data stage instantly. Use with caution, as this works without a commit.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
function khaoslib_technology:remove()
  data.raw.technology[self.technology.name] = nil

  return self
end

--- Merges another technology manipulation object into this one, excluding the name field.
--- @param other khaoslib.TechnologyManipulator The other technology manipulation object to merge into this one
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If other is not a technology manipulation object.
function khaoslib_technology:__add(other)
  if type(other) ~= "table" or getmetatable(other) ~= khaoslib_technology then
    error("Can only concatenate with another khaoslib.TechnologyManipulator object", 2)
  end

  local other_copy = other:get()
  other_copy.type = nil
  other_copy.name = nil

  return self:set(other_copy)
end

--- Compares two technology manipulation objects for equality based on the technology name.
--- @param other khaoslib.TechnologyManipulator The other technology manipulation object to compare with.
--- @return boolean is_equal True if the two technology manipulation objects represent the same technology, false otherwise.
function khaoslib_technology:__eq(other)
  if type(other) ~= "table" or getmetatable(other) ~= khaoslib_technology then return false end

  return self.technology.name == other.technology.name
end

--- Returns a string representation of the technology manipulation object.
--- @return string representation A string representation of the technology manipulation object.
function khaoslib_technology:__tostring()
  return "[khaoslib_technology: " .. self.technology.name .. "]"
end

--#endregion

--#region Technology manipulation methods
-- A set of utility functions for manipulating technologies.

--- If the technology has a single icon, it is converted to the icons list format. If the technology already has an icons list, no changes are made.
--- @param technology data.TechnologyPrototype The technology reference to populate icons for.
local populate_icons = function(technology)
  if technology.icon and (not technology.icons or #technology.icons == 0) then
    technology.icons = {{icon = technology.icon, icon_size = technology.icon_size or nil}}
    technology.icon = nil
    technology.icon_size = nil
  end
end

--- If just a single item exists in the icons list, and it has no special properties, depopulate the icons list and set the icon and icon_size fields instead.
--- @param technology data.TechnologyPrototype The technology reference to depopulate icons from.
local depopulate_icons = function(technology)
  if #technology.icons == 1 then
    local icon = technology.icons[1]
    if icon.tint == nil and icon.shift == nil and icon.scale == nil and icon.draw_background == nil and icon.floating == nil then
      technology.icon = icon.icon
      technology.icon_size = icon.icon_size or nil
      technology.icons = nil
    end
  end
end

--- Returns a deepcopy of all icons for the given technology. If the technology has a single icon, it is returned as a single-element list.
--- @param technology data.TechnologyID|data.TechnologyPrototype|khaoslib.TechnologyManipulator The technology.
--- @return data.IconData[] icons A list of icons for the technology.
--- @nodiscard
function khaoslib_technology.get_icons(technology)
  local resolved_technology = resolve(technology)
  if resolved_technology.icons then
    return util.table.deepcopy(resolved_technology.icons --[=[@as data.IconData[]]=])
  elseif resolved_technology.icon then
    return util.table.deepcopy({{icon = resolved_technology.icon, icon_size = resolved_technology.icon_size or nil}})
  else
    return {}
  end
end

--- Sets the list of icons for the technology currently being manipulated, replacing any existing icons.
--- @param icons data.IconData[] A list of icons to set.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If icons is not a table.
function khaoslib_technology:set_icons(icons)
  if type(icons) ~= "table" then error("icons parameter: Expected table, got " .. type(icons), 2) end

  self.technology.icon = nil
  self.technology.icon_size = nil
  self.technology.icons = util.table.deepcopy(icons)
  depopulate_icons(self.technology)

  return self
end

--- Returns the number of icons for the given technology.
--- @param technology data.TechnologyID|data.TechnologyPrototype|khaoslib.TechnologyManipulator The technology.
--- @return integer count The number of icons.
--- @nodiscard
function khaoslib_technology.count_icons(technology)
  local resolved_technology = resolve(technology)
  return resolved_technology.icons ~= nil and #resolved_technology.icons or (resolved_technology.icon ~= nil and 1 or 0)
end

--- Checks if the technology has an icon matching the given criteria.
--- Supports both string matching (by icon filename) and custom comparison functions.
--- @param technology data.TechnologyID|data.TechnologyPrototype|khaoslib.TechnologyManipulator The technology.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @return boolean has_icon True if the technology has the icon, false otherwise.
--- @throws If compare is not a string or function.
--- @nodiscard
function khaoslib_technology.has_icon(technology, compare)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  local resolved_technology = resolve(technology)
  populate_icons(resolved_technology)

  local result = khaoslib_list.has(resolved_technology.icons, compare_fn)
  depopulate_icons(resolved_technology)

  return result
end

--- Adds an icon to the technology, allows duplicates.
--- @param icon data.IconData The icon data to add.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If icon is not a table or doesn't have required fields.
function khaoslib_technology:add_icon(icon)
  if type(icon) ~= "table" then error("icon parameter: Expected table, got " .. type(icon), 2) end
  if not icon.icon or type(icon.icon) ~= "string" then error("icon parameter: Must have an icon field of type string", 2) end

  populate_icons(self.technology)
  self.technology.icons = khaoslib_list.add(self.technology.icons, icon, nil, {allow_duplicates = true})
  depopulate_icons(self.technology)

  return self
end

--- Removes matching icons from the technology.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @param options ListRemoveOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, removes all matching icons instead of just the first.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If compare is not a string or function.
function khaoslib_technology:remove_icon(compare, options)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  populate_icons(self.technology)
  self.technology.icons = khaoslib_list.remove(self.technology.icons, compare_fn, options)
  depopulate_icons(self.technology)

  return self
end

--- Replaces matching icons with a new icon.
--- If no matching icons are found, no changes are made.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @param replacement (fun(icon: data.IconData): data.IconData)|data.IconData The new icon data to replace with.
--- @param options ListReplaceOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, replaces all matching icons instead of just the first.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If compare is not a string or function, or replacement is not a table or function.
function khaoslib_technology:replace_icon(compare, replacement, options)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  if type(replacement) ~= "table" and type(replacement) ~= "function" then error("replacement parameter: Expected table or function, got " .. type(replacement), 2) end
  if type(replacement) == "table" then
    if not replacement.icon or type(replacement.icon) ~= "string" then error("replacement parameter: Must have an icon field of type string", 2) end
  end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  populate_icons(self.technology)
  self.technology.icons = khaoslib_list.replace(self.technology.icons, replacement, compare_fn, options)
  depopulate_icons(self.technology)

  return self
end

--- Removes all icons from the technology.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
function khaoslib_technology:clear_icons()
  self.technology.icon = nil
  self.technology.icon_size = nil
  self.technology.icons = nil

  return self
end

--- Returns a list of all prerequisite technologies.
--- @param technology data.TechnologyID|data.TechnologyPrototype|khaoslib.TechnologyManipulator The technology.
--- @return data.TechnologyID[] prerequisites A list of prerequisite technology names.
--- @nodiscard
function khaoslib_technology.get_prerequisites(technology)
  return util.table.deepcopy(resolve(technology).prerequisites or {})
end

--- Sets the list of prerequisite technologies for the technology currently being manipulated, replacing any existing prerequisites.
--- @param prerequisites data.TechnologyID[] A list of prerequisite technology names to set.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If prerequisites is not a table.
function khaoslib_technology:set_prerequisites(prerequisites)
  if type(prerequisites) ~= "table" then error("prerequisites parameter: Expected table, got " .. type(prerequisites), 2) end

  self.technology.prerequisites = util.table.deepcopy(prerequisites)

  return self
end

--- Returns the number of prerequisite technologies for the given technology.
--- @param technology data.TechnologyID|data.TechnologyPrototype|khaoslib.TechnologyManipulator The technology.
--- @return integer count The number of prerequisite technologies.
--- @nodiscard
function khaoslib_technology.count_prerequisites(technology)
  return #(resolve(technology).prerequisites or {})
end

--- Checks if the technology has a prerequisite matching the given criteria.
--- Supports both string matching (by prerequisite name) and custom comparison functions.
---
--- ```lua
--- -- By name (string)
--- if tech:has_prerequisite("electronics") then
---   -- Technology requires electronics
--- end
---
--- -- By comparison function
--- if tech:has_prerequisite(function(prereq)
---   return prereq:match("^advanced%-")
--- end) then
---   -- Technology has advanced prerequisites
--- end
--- ```
---
--- @param technology data.TechnologyID|data.TechnologyPrototype|khaoslib.TechnologyManipulator The technology.
--- @param compare (fun(prerequisite: data.TechnologyID): boolean)|data.TechnologyID A comparison function or prerequisite name to match.
--- @return boolean has_prerequisite True if the technology has the prerequisite, false otherwise.
--- @throws If compare is not a string or function.
--- @nodiscard
function khaoslib_technology.has_prerequisite(technology, compare)
  return khaoslib_list.has(resolve(technology).prerequisites, compare)
end

--- Adds a prerequisite to the technology currently being manipulated if it doesn't already exist.
--- @param prerequisite data.TechnologyID The name of the prerequisite technology to add.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining
--- @throws If prerequisite is not a string.
function khaoslib_technology:add_prerequisite(prerequisite)
  if type(prerequisite) ~= "string" then error("prerequisite parameter: Expected string, got " .. type(prerequisite), 2) end

  self.technology.prerequisites = khaoslib_list.add(self.technology.prerequisites, prerequisite, prerequisite)

  return self
end

--- Removes matching prerequisites from the technology.
---
--- ```lua
--- -- By name (string) - removes first match by default
--- tech:remove_prerequisite("electronics")
---
--- -- By comparison function - removes first match by default
--- tech:remove_prerequisite(function(prereq)
---   return prereq:match("^advanced%-")
--- end)
---
--- -- Remove all matching prerequisites
--- tech:remove_prerequisite(function(prereq)
---   return prereq:match("^basic%-")
--- end, {all = true})
--- ```
---
--- @param compare (fun(prerequisite: data.TechnologyID): boolean)|data.TechnologyID A comparison function or prerequisite name to match.
--- @param options ListRemoveOptions? Options table with fields:
---   - `all` (boolean, default: false): If true, removes all matching prerequisites instead of just the first.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If compare is not a string or function.
function khaoslib_technology:remove_prerequisite(compare, options)
  self.technology.prerequisites = khaoslib_list.remove(self.technology.prerequisites, compare, options)

  return self
end

--- Replaces matching prerequisites with a new prerequisite.
--- If no matching prerequisites are found, no changes are made.
---
--- ```lua
--- -- Replace by name (string parameter) - replaces first match by default
--- tech:replace_prerequisite("electronics", "advanced-electronics")
---
--- -- Replace with custom function (function parameter) - replaces first match by default
--- tech:replace_prerequisite(function(prereq)
---   return prereq:match("^basic%-")
--- end, "electronics")
---
--- -- Replace all matching prerequisites
--- tech:replace_prerequisite(function(prereq)
---   return prereq:match("^old%-")
--- end, "new-base-tech", {all = true})
--- ```
---
--- @param compare (fun(prerequisite: data.TechnologyID): boolean)|data.TechnologyID A comparison function or prerequisite name to match.
--- @param replacement (fun(prerequisite: data.TechnologyID): data.TechnologyID)|data.TechnologyID The new prerequisite technology name to replace with.
--- @param options ListReplaceOptions? Options table with fields:
---   - `all` (boolean, default: false): If true, replaces all matching prerequisites instead of just the first.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If compare is not a string or function, or replacement is not a string or function.
function khaoslib_technology:replace_prerequisite(compare, replacement, options)
  if type(replacement) ~= "string" and type(replacement) ~= "function" then error("replacement parameter: Expected string or function, got " .. type(replacement), 2) end

  self.technology.prerequisites = khaoslib_list.replace(self.technology.prerequisites, replacement, compare, options)

  return self
end

--- Removes all prerequisites from the technology currently being manipulated.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
function khaoslib_technology:clear_prerequisites()
  self.technology.prerequisites = {}

  return self
end

--- Returns a list of all effects granted by the given technology.
--- @param technology data.TechnologyID|data.TechnologyPrototype|khaoslib.TechnologyManipulator The technology.
--- @return data.Modifier[] effects A list of effects granted by the technology.
--- @nodiscard
function khaoslib_technology.get_effects(technology)
  return util.table.deepcopy(resolve(technology).effects or {})
end

--- Sets the list of effects granted by the technology currently being manipulated, replacing any existing effects.
--- @param effects data.Modifier[] A list of effects to set.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If effects is not a table.
function khaoslib_technology:set_effects(effects)
  if type(effects) ~= "table" then error("effects parameter: Expected table, got " .. type(effects), 2) end

  self.technology.effects = util.table.deepcopy(effects)

  return self
end

--- Returns the number of effects granted by the given technology.
--- @param technology data.TechnologyID|data.TechnologyPrototype|khaoslib.TechnologyManipulator The technology.
--- @return integer count The number of effects.
--- @nodiscard
function khaoslib_technology.count_effects(technology)
  return #(resolve(technology).effects or {})
end

--- Returns `true` if the given technology has an effect that matches the given comparison function.
--- @param technology data.TechnologyID|data.TechnologyPrototype|khaoslib.TechnologyManipulator The technology.
--- @param compare_fn fun(effect: data.Modifier): boolean A function that takes an effect and returns true if it matches.
--- @return boolean has_effect True if the technology has a matching effect, false otherwise.
--- @throws If compare_fn is not a function.
--- @nodiscard
function khaoslib_technology.has_effect(technology, compare_fn)
  if type(compare_fn) ~= "function" then error("compare_fn parameter: Expected function, got " .. type(compare_fn), 2) end

  return khaoslib_list.has(resolve(technology).effects, compare_fn)
end

--- Adds an effect to the technology currently being manipulated.
--- @param effect data.Modifier The effect to add. See `data.Modifier` for valid effect types.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If effect is not a table.
function khaoslib_technology:add_effect(effect)
  if type(effect) ~= "table" then error("effect parameter: Expected table, got " .. type(effect), 2) end

  self.technology.effects = khaoslib_list.add(self.technology.effects, effect, nil, {allow_duplicates = true})

  return self
end

--- Removes matching effects from the technology.
---
--- ```lua
--- -- Remove first matching effect (default behavior)
--- tech:remove_effect(function(effect)
---   return effect.type == "unlock-recipe" and effect.recipe == "old-recipe"
--- end)
---
--- -- Remove all matching effects
--- tech:remove_effect(function(effect)
---   return effect.type == "unlock-recipe" and effect.recipe:match("^deprecated%-")
--- end, {all = true})
--- ```
---
--- @param compare_fn fun(effect: data.Modifier): boolean A function that takes an effect and returns true if it should be removed.
--- @param options ListRemoveOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, removes all matching effects instead of just the first.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If compare_fn is not a function.
function khaoslib_technology:remove_effect(compare_fn, options)
  if type(compare_fn) ~= "function" then error("compare_fn parameter: Expected function, got " .. type(compare_fn), 2) end

  self.technology.effects = khaoslib_list.remove(self.technology.effects, compare_fn, options)

  return self
end

--- Replaces matching effects with a new effect.
--- If no matching effects are found, no changes are made.
---
--- ```lua
--- -- Replace first matching effect (default behavior)
--- tech:replace_effect(function(effect)
---   return effect.type == "unlock-recipe" and effect.recipe == "old-recipe"
--- end, {type = "unlock-recipe", recipe = "new-recipe"})
---
--- -- Replace all matching effects
--- tech:replace_effect(function(effect)
---   return effect.type == "unlock-recipe" and effect.recipe:match("^deprecated%-")
--- end, {type = "nothing", effect_description = "Removed deprecated recipe"}, {all = true})
--- ```
---
--- @param compare_fn fun(effect: data.Modifier): boolean A function that takes an effect and returns true if it should be replaced.
--- @param replacement (fun(effect: data.Modifier): data.Modifier)|data.Modifier The new effect to add. See `data.Modifier` for valid effect types.
--- @param options ListReplaceOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, replaces all matching effects instead of just the first.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If compare_fn is not a function or if replacement is not a table or function.
function khaoslib_technology:replace_effect(compare_fn, replacement, options)
  if type(compare_fn) ~= "function" then error("compare_fn parameter: Expected function, got " .. type(compare_fn), 2) end
  if type(replacement) ~= "table" and type(replacement) ~= "function" then error("replacement parameter: Expected table or function, got " .. type(replacement), 2) end

  self.technology.effects = khaoslib_list.replace(self.technology.effects, replacement, compare_fn, options)

  return self
end

--- Removes all effects from the technology currently being manipulated.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
function khaoslib_technology:clear_effects()
  self.technology.effects = {}

  return self
end

--- Gets all recipes unlocked by the given technology.
--- @param technology data.TechnologyID|data.TechnologyPrototype|khaoslib.TechnologyManipulator The technology.
--- @return data.RecipeID[] recipe_names A list of recipe names unlocked by this technology.
--- @nodiscard
function khaoslib_technology.get_unlock_recipes(technology)
  local result = {}
  local tech = resolve(technology)

  if tech.effects then
    for _, effect in ipairs(tech.effects) do
      if effect.type == "unlock-recipe" and effect.recipe then
        table.insert(result, effect.recipe)
      end
    end
  end

  return util.table.deepcopy(result)
end

--- Returns the number of unlock-recipe effects in the technology currently being manipulated.
--- @param technology data.TechnologyID|data.TechnologyPrototype|khaoslib.TechnologyManipulator The technology.
--- @return integer count The number of unlock-recipe effects.
--- @nodiscard
function khaoslib_technology.count_unlock_recipes(technology)
  local count = 0
  local tech = resolve(technology)

  if tech.effects then
    for _, effect in ipairs(tech.effects) do
      if effect.type == "unlock-recipe" then
        count = count + 1
      end
    end
  end

  return count
end

--- Returns `true` if the given technology has an "unlock-recipe" effect for the given recipe.
--- @param technology data.TechnologyID|data.TechnologyPrototype|khaoslib.TechnologyManipulator The technology.
--- @param compare (fun(effect: data.Modifier): boolean)|data.RecipeID An effect comparison function or recipe name to match.
--- @return boolean has_unlock_recipe True if the technology has an unlock-recipe effect for the recipe, false otherwise.
--- @throws If compare is not a string or function.
--- @nodiscard
function khaoslib_technology.has_unlock_recipe(technology, compare)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.type == "unlock-recipe" and existing.recipe == compare end
  end

  return khaoslib_technology.has_effect(technology, compare_fn --[[@as fun(effect: data.Modifier): boolean]])
end

--- Adds an "unlock-recipe" effect to the technology currently being manipulated.
--- @param recipe data.RecipeID The name of the recipe to unlock.
--- @param modifier table? modifier Optional table with additional modifier options to add to the unlock effect. See `data.UnlockRecipeModifier` for valid fields.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If recipe is not a string.
function khaoslib_technology:add_unlock_recipe(recipe, modifier)
  if type(recipe) ~= "string" then error("recipe parameter: Expected string, got " .. type(recipe), 2) end
  if modifier ~= nil and type(modifier) ~= "table" then error("modifier parameter: Expected table or nil, got " .. type(modifier), 2) end

  modifier = modifier or {}
  modifier.type = "unlock-recipe"
  modifier.recipe = recipe

  return self:add_effect(modifier)
end

--- Removes matching "unlock-recipe" effects from the technology.
---
--- ```lua
--- -- Remove by name (string parameter) - removes first match by default
--- tech:remove_unlock_recipe("deprecated-recipe")
---
--- -- Remove all matching unlock effects for a recipe
--- tech:remove_unlock_recipe("recipe-with-duplicates", {all = true})
--- ```
---
--- @param compare (fun(effect: data.Modifier): boolean)|data.RecipeID An effect comparison function or recipe name to match.
--- @param options ListRemoveOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, removes all matching unlock-recipe effects instead of just the first.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If compare is not a string or function.
function khaoslib_technology:remove_unlock_recipe(compare, options)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.type == "unlock-recipe" and existing.recipe == compare end
  end

  return self:remove_effect(compare_fn --[[@as fun(effect: data.Modifier): boolean]], options)
end

--- Replaces matching "unlock-recipe" effects with a new recipe.
--- If no matching effects are found, no changes are made.
---
--- ```lua
--- -- Replace by name (string parameter) - replaces first match by default
--- tech:replace_unlock_recipe("old-recipe", "new-recipe")
---
--- -- Replace all matching unlock effects for a recipe
--- tech:replace_unlock_recipe("recipe-with-duplicates", "replacement-recipe", {all = true})
--- ```
---
--- @param compare (fun(effect: data.Modifier): boolean)|data.RecipeID An effect comparison function or recipe name to match.
--- @param replacement (fun(recipe: data.Modifier): data.Modifier)|data.RecipeID The name of the new recipe to unlock or modified effect table from the function callback.
--- @param options ListReplaceOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, replaces all matching unlock-recipe effects instead of just the first.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If compare is not a string or function, or replacement is not a string or function.
function khaoslib_technology:replace_unlock_recipe(compare, replacement, options)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end
  if type(replacement) ~= "string" and type(replacement) ~= "function" then error("replacement parameter: Expected string or function, got " .. type(replacement), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.type == "unlock-recipe" and existing.recipe == compare end
  end

  local replacement_fn = replacement
  if type(replacement) == "string" then
    replacement_fn = function(existing)
      existing.recipe = replacement
      return existing
    end
  end

  return self:replace_effect(compare_fn --[[@as fun(effect: data.Modifier): boolean]], replacement_fn --[[@as fun(effect: data.Modifier): data.Modifier]], options)
end

--- Returns a list of all science pack ingredients for the given technology.
--- @param technology data.TechnologyID|data.TechnologyPrototype|khaoslib.TechnologyManipulator The technology.
--- @return data.ResearchIngredient[] ingredients A deep copy of the science pack ingredients.
--- @nodiscard
function khaoslib_technology.get_science_packs(technology)
  local tech = resolve(technology)
  if not tech.unit or not tech.unit.ingredients then
    return {}
  end

  return util.table.deepcopy(tech.unit.ingredients)
end

--- Sets the science pack list, replacing existing ones.
--- @param ingredients data.ResearchIngredient[] A list of science pack ingredients to set.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If ingredients is not a table, or if unit is not defined on the technology.
function khaoslib_technology:set_science_packs(ingredients)
  if type(ingredients) ~= "table" then error("ingredients parameter: Expected table, got " .. type(ingredients), 2) end
  if not self.technology.unit then error("technology.unit is not defined", 2) end

  self.technology.unit.ingredients = util.table.deepcopy(ingredients)

  return self
end

--- Returns the number of science pack ingredients for the given technology.
--- @param technology data.TechnologyID|data.TechnologyPrototype|khaoslib.TechnologyManipulator The technology.
--- @return integer count The number of science pack ingredients.
--- @nodiscard
function khaoslib_technology.count_science_packs(technology)
  local tech = resolve(technology)
  if not tech.unit or not tech.unit.ingredients then
    return 0
  end

  return #tech.unit.ingredients
end

--- Checks if the technology has a science pack ingredient matching the given criteria.
--- Supports both string matching (by science pack name) and custom comparison functions.
---
--- ```lua
--- -- By name (string)
--- if tech:has_science_pack("automation-science-pack") then
---   -- Technology requires automation science packs
--- end
---
--- -- By comparison function
--- if tech:has_science_pack(function(ingredient)
---   return ingredient.name:match("%-military%-science%-pack$")
--- end) then
---   -- Technology requires military science
--- end
--- ```
---
--- @param technology data.TechnologyID|data.TechnologyPrototype|khaoslib.TechnologyManipulator The technology.
--- @param compare fun(ingredients: data.ResearchIngredient): boolean|data.ItemID A comparison function or science pack name to match.
--- @return boolean has_science_pack True if the technology has the science pack, false otherwise.
--- @throws If compare is not a string or function, or unit is not defined on the technology.
--- @nodiscard
function khaoslib_technology.has_science_pack(technology, compare)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local tech = resolve(technology)
  if not tech.unit then error("technology.unit is not defined", 2) end
  if not tech.unit.ingredients then
    return false
  end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing[1] == compare end
  end

  return khaoslib_list.has(tech.unit.ingredients, compare_fn)
end

--- Adds a science pack ingredient to the technology currently being manipulated if it doesn't already exist. Ingredients cannot have duplicates.
--- @param ingredient data.ResearchIngredient The science pack ingredientto add.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If ingredient is not a table or isn't an ingredient, or unit is not defined on the technology.
function khaoslib_technology:add_science_pack(ingredient)
  if type(ingredient) ~= "table" then error("ingredient parameter: Expected table, got " .. type(ingredient), 2) end
  if not ingredient[1] then error("ingredient parameter: Missing science pack name at index 1", 2) end
  if not ingredient[2] then error("ingredient parameter: Missing science pack amount at index 2", 2) end
  if not self.technology.unit then error("technology.unit is not defined", 2) end

  self.technology.unit.ingredients = khaoslib_list.add(self.technology.unit.ingredients, ingredient, function(existing)
    return existing[1] == ingredient[1]
  end)

  return self
end

--- Removes matching science pack ingredients from the technology.
---
--- ```lua
--- -- By name (string) - removes first match by default
--- tech:remove_science_pack("automation-science-pack")
---
--- -- By comparison function - removes first match by default
--- tech:remove_science_pack(function(ingredient)
---   return ingredient.name:match("^military%-")
--- end)
---
--- -- Remove all matching science packs
--- tech:remove_science_pack(function(ingredient)
---   return ingredient.amount > 5
--- end, {all = true})
--- ```
---
--- @param compare (fun(ingredients: data.ResearchIngredient): boolean)|data.ItemID A comparison function or science pack name to match.
--- @param options ListRemoveOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, removes all matching science packs instead of just the first.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If compare is not a string or function, or unit is not defined on the technology.
function khaoslib_technology:remove_science_pack(compare, options)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  if not self.technology.unit then error("technology.unit is not defined", 2) end
  if not self.technology.unit.ingredients then
    return self
  end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing[1] == compare end
  end

  self.technology.unit.ingredients = khaoslib_list.remove(self.technology.unit.ingredients, compare_fn, options)

  return self
end

--- Replaces matching science packs with a new science pack.
--- If no matching science packs are found, no changes are made.
---
--- ```lua
--- -- Replace by name (string parameter) - replaces first match by default
--- tech:replace_science_pack("automation-science-pack", {
---   type = "item",
---   name = "automation-science-pack",
---   amount = 2
--- })
---
--- -- Replace with custom function (function parameter) - replaces first match by default
--- tech:replace_science_pack(function(ingredient)
---   return ingredient.name:match("^basic%-")
--- end, {type = "item", name = "advanced-science-pack", amount = 1})
---
--- -- Replace all matching science packs
--- tech:replace_science_pack(function(science_pack)
---   return science_pack.amount == 1
--- end, {type = "item", name = "universal-science-pack", amount = 2}, {all = true})
--- ```
---
--- @param compare (fun(ingredient: data.ResearchIngredient): boolean)|data.ItemID A comparison function or science pack name to match.
--- @param replacement (fun(ingredient: data.ResearchIngredient): data.ResearchIngredient)|data.ResearchIngredient The new science pack to replace with.
--- @param options ListReplaceOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, replaces all matching science packs instead of just the first.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If compare is not a string or function, or replacement is not a function or not a table or isn't an ingredient, or unit is not defined on the technology.
function khaoslib_technology:replace_science_pack(compare, replacement, options)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  if type(replacement) ~= "table" and type(replacement) ~= "function" then error("replacement parameter: Expected table or function, got " .. type(replacement), 2) end
  if type(replacement) == "table" then
    if not replacement[1] then error("replacement parameter: Missing science pack name at index 1", 2) end
    if not replacement[2] then error("replacement parameter: Missing science pack amount at index 2", 2) end
  end

  if not self.technology.unit then error("technology.unit is not defined", 2) end
  if not self.technology.unit.ingredients then
    return self
  end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing[1] == compare end
  end

  self.technology.unit.ingredients = khaoslib_list.replace(self.technology.unit.ingredients, replacement, compare_fn, options)

  return self
end

--- Removes all science packs from the technology currently being manipulated.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If unit is not defined on the technology.
function khaoslib_technology:clear_science_packs()
  if not self.technology.unit then error("technology.unit is not defined", 2) end

  self.technology.unit.ingredients = {}

  return self
end

--#endregion

--#region Utility functions
-- Module-level utility functions for technology discovery and analysis.

--- Checks if a technology exists in the data stage.
--- @param name data.TechnologyID The technology name to check.
--- @return boolean exists True if the technology exists, false otherwise.
--- @nodiscard
function khaoslib_technology.exists(name)
  if type(name) ~= "string" then error("name parameter: Expected string, got " .. type(name), 2) end

  return data.raw.technology[name] ~= nil
end

--- Finds all technologies that match a custom compare function.
--- @param compare_fn fun(technology: data.TechnologyPrototype): boolean A function that returns true for technologies to include.
--- @return data.TechnologyID[] technologies A list of technology names that match the compare function.
--- @throws If compare_fn is not a function.
--- @nodiscard
function khaoslib_technology.find(compare_fn)
  if type(compare_fn) ~= "function" then error("compare_fn parameter: Expected function, got " .. type(compare_fn), 2) end

  local result = {}
  for _, technology in pairs(data.raw.technology or {}) do
    if compare_fn(technology) then
      table.insert(result, technology.name)
    end
  end

  return result
end

--#endregion

return khaoslib_technology
