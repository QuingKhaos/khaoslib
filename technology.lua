if ... ~= "__khaoslib__.technology" then
  return require("__khaoslib__.technology")
end

local util = require("util")

--#region Basic manipulation methods
-- A set of basic methods for creating and working with technology manipulation objects.

--- Utilities for technology manipulation in Factorio data stage.
--- ```lua
--- local khaoslib_technology = require("__khaoslib__.technology")
---
--- -- Load an existing technology for manipulation
--- khaoslib_technology:load("electronics"):add_prerequisite("solder"):add_unlock_recipe("electronic-circuit-with-solder"):commit()
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
--- @class khaoslib.TechnologyManipulator
--- @field private technology data.TechnologyPrototype The technology currently being manipulated.
--- @operator add(khaoslib.TechnologyManipulator): khaoslib.TechnologyManipulator
local khaoslib_technology = {}

--- Loads a given technology for manipulation or creates a new one if a table is passed.
--- @param technology data.TechnologyID|data.TechnologyPrototype The name of an existing technology or a new technology prototype table.
--- @return khaoslib.TechnologyManipulator manipulator A technology manipulation object for the given technology.
--- @throws If the technology name doesn't exist or if a table is passed with a name that already exists or without a valid name field.
function khaoslib_technology:load(technology)
  if type(technology) ~= "string" and type(technology) ~= "table" then error("technology parameter: Expected string or table , got " .. type(technology), 2) end
  if type(technology) == "string" and not data.raw.technology[technology] then error("No such technology: " .. technology, 2) end
  if type(technology) == "table" and technology.type and type(technology.type) ~= "string" then error("technology table type field should be a string if set", 2) end
  if type(technology) == "table" and technology.type and technology.type ~= "technology" then error("technology table type field should be 'technology' if set", 2) end
  if type(technology) == "table" and (not technology.name or type(technology.name) ~= "string") then error("technology table must have a name field of type string", 2) end
  if type(technology) == "table" and data.raw.technology[technology.name] then error("A technology with the name " .. technology.name .. " already exists", 2) end

  local _technology = technology
  if type(technology) == "string" then
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

--- Gets the raw data table of the technology currently being manipulated.
--- @return data.TechnologyPrototype technology A deep copy of the technology currently being manipulated.
--- @nodiscard
function khaoslib_technology:get()
  return util.table.deepcopy(self.technology) --[[@as data.TechnologyPrototype]]
end

--- Merges the given fields into the technology currently being manipulated.
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

--- Creates a deep copy of the technology currently being manipulated.
--- @param new_name data.TechnologyID The name of the new technology. Must not already exist.
--- @return khaoslib.TechnologyManipulator technology A new technology manipulation object with a deep copy of the technology.
--- @throws If a technology with the new name already exists.
--- @nodiscard
function khaoslib_technology:copy(new_name)
  local copy = self:get()
  copy.name = new_name

  return khaoslib_technology:load(copy)
end

--- Commits the changes made to the technology currently being manipulated back to the data stage.
--- If the technology already exists, it is overwritten.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
function khaoslib_technology:commit()
  data:extend({self:remove():get()})

  return self
end

--- Deletes the technology currently being manipulated from the data stage.
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
  if type(other) ~= "table" or getmetatable(other) ~= khaoslib_technology then error("Can only concatenate with another khaoslib.TechnologyManipulator object", 2) end

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

--- Returns a list of all prerequisite technologies for the technology currently being manipulated.
--- @return data.TechnologyID[] prerequisites A list of prerequisite technology names.
function khaoslib_technology:get_prerequisites()
  return util.table.deepcopy(self.technology.prerequisites or {})
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

--- Returns the number of prerequisite technologies for the technology currently being manipulated.
--- @return integer count The number of prerequisite technologies.
function khaoslib_technology:count_prerequisites()
  return #(self.technology.prerequisites or {})
end

--- Returns `true` if the technology currently being manipulated has the given prerequisite.
--- @param prerequisite data.TechnologyID The name of the prerequisite technology to check for.
--- @return boolean has_prerequisite True if the technology has the prerequisite, false otherwise.
--- @throws If prerequisite is not a string.
function khaoslib_technology:has_prerequisite(prerequisite)
  if type(prerequisite) ~= "string" then error("prerequisite parameter: Expected string, got " .. type(prerequisite), 2) end

  local prerequisites = self.technology.prerequisites or {}
  for _, existing in pairs(prerequisites) do
    if existing == prerequisite then
      return true
    end
  end

  return false
end

--- Adds a prerequisite to the technology currently being manipulated if it doesn't already exist.
--- @param prerequisite data.TechnologyID The name of the prerequisite technology to add.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining
--- @throws If prerequisite is not a string.
function khaoslib_technology:add_prerequisite(prerequisite)
  if type(prerequisite) ~= "string" then error("prerequisite parameter: Expected string, got " .. type(prerequisite), 2) end

  local prerequisites = self.technology.prerequisites or {}
  for _, existing in pairs(prerequisites) do
    if existing == prerequisite then
      return self
    end
  end

  table.insert(prerequisites, prerequisite)
  self.technology.prerequisites = prerequisites

  return self
end

--- Removes a prerequisite from the technology currently being manipulated if it exists.
--- @param prerequisite data.TechnologyID The name of the prerequisite technology to remove.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If prerequisite is not a string.
function khaoslib_technology:remove_prerequisite(prerequisite)
  if type(prerequisite) ~= "string" then error("prerequisite parameter: Expected string, got " .. type(prerequisite), 2) end

  local prerequisites = self.technology.prerequisites or {}
  for i, existing in ipairs(prerequisites) do
    if existing == prerequisite then
      table.remove(prerequisites, i)
      self.technology.prerequisites = prerequisites

      return self
    end
  end

  return self
end

--- Replaces an existing prerequisite in the technology currently being manipulated with a new prerequisite.
--- If no matching prerequisite is found, no changes are made.
--- @param old_prerequisite data.TechnologyID The name of the prerequisite technology to replace.
--- @param new_prerequisite data.TechnologyID The name of the new prerequisite technology to add.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If old_prerequisite or new_prerequisite is not a string.
function khaoslib_technology:replace_prerequisite(old_prerequisite, new_prerequisite)
  if type(old_prerequisite) ~= "string" then error("old_prerequisite parameter: Expected string, got " .. type(old_prerequisite), 2) end
  if type(new_prerequisite) ~= "string" then error("new_prerequisite parameter: Expected string, got " .. type(new_prerequisite), 2) end

  local prerequisites = self.technology.prerequisites or {}
  for i, existing in ipairs(prerequisites) do
    if existing == old_prerequisite then
      prerequisites[i] = new_prerequisite
      self.technology.prerequisites = prerequisites

      return self
    end
  end

  return self
end

--- Removes all prerequisites from the technology currently being manipulated.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
function khaoslib_technology:clear_prerequisites()
  self.technology.prerequisites = {}

  return self
end

--- Returns a list of all effects granted by the technology currently being manipulated.
--- @return data.Modifier[] effects A list of effects granted by the technology.
function khaoslib_technology:get_effects()
  return util.table.deepcopy(self.technology.effects or {})
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

--- Returns the number of effects granted by the technology currently being manipulated.
--- @return integer count The number of effects.
function khaoslib_technology:count_effects()
  return #(self.technology.effects or {})
end

--- Returns `true` if the technology currently being manipulated has an effect that matches the given comparison function.
--- @param compare_fn fun(effect: data.Modifier): boolean A function that takes an effect and returns true if it matches.
--- @return boolean has_effect True if the technology has a matching effect, false otherwise.
--- @throws If compare_fn is not a function.
function khaoslib_technology:has_effect(compare_fn)
  if type(compare_fn) ~= "function" then error("compare_fn parameter: Expected function, got " .. type(compare_fn), 2) end

  local effects = self.technology.effects or {}
  for _, existing in pairs(effects) do
    if compare_fn(existing) then
      return true
    end
  end

  return false
end

--- Adds an effect to the technology currently being manipulated.
--- @param effect data.Modifier The effect to add. See `data.Modifier` for valid effect types.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If effect is not a table.
function khaoslib_technology:add_effect(effect)
  if type(effect) ~= "table" then error("effect parameter: Expected table, got " .. type(effect), 2) end

  self.technology.effects = self.technology.effects or {}
  table.insert(self.technology.effects, util.table.deepcopy(effect))

  return self
end

--- Removes the first effect from the technology currently being manipulated that matches the given comparison function.
--- @param compare_fn fun(effect: data.Modifier): boolean A function that takes an effect and returns true if it should be removed.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If compare_fn is not a function.
function khaoslib_technology:remove_effect(compare_fn)
  if type(compare_fn) ~= "function" then error("compare_fn parameter: Expected function, got " .. type(compare_fn), 2) end

  local effects = self.technology.effects or {}
  for i, existing in ipairs(effects) do
    if compare_fn(existing) then
      table.remove(effects, i)
      self.technology.effects = effects

      return self
    end
  end

  return self
end

--- Replaces the first effect in the technology currently being manipulated that matches the given comparison function with a new effect.
--- If no matching effect is found, no changes are made.
--- @param compare_fn fun(effect: data.Modifier): boolean A function that takes an effect and returns true if it should be replaced.
--- @param new_effect data.Modifier The new effect to add. See `data.Modifier` for valid effect types.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If compare_fn is not a function or if new_effect is not a table.
function khaoslib_technology:replace_effect(compare_fn, new_effect)
  if type(compare_fn) ~= "function" then error("compare_fn parameter: Expected function, got " .. type(compare_fn), 2) end
  if type(new_effect) ~= "table" then error("new_effect parameter: Expected table, got " .. type(new_effect), 2) end

  local effects = self.technology.effects or {}
  for i, existing in ipairs(effects) do
    if compare_fn(existing) then
      effects[i] = util.table.deepcopy(new_effect)
      self.technology.effects = effects

      return self
    end
  end

  return self
end

--- Removes all effects from the technology currently being manipulated.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
function khaoslib_technology:clear_effects()
  self.technology.effects = {}

  return self
end

--- Adds an "unlock-recipe" effect to the technology currently being manipulated.
--- @param recipe data.RecipeID The name of the recipe to unlock.
--- @param modifier data.UnlockRecipeModifier? modifier Optional modifier table to modify the unlock effect.
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

--- Removes an "unlock-recipe" effect from the technology currently being manipulated.
--- @param recipe data.RecipeID The name of the recipe to remove.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If recipe is not a string.
function khaoslib_technology:remove_unlock_recipe(recipe)
  if type(recipe) ~= "string" then error("recipe parameter: Expected string, got " .. type(recipe), 2) end

  return self:remove_effect(function(effect)
    return effect.type == "unlock-recipe" and effect.recipe == recipe
  end)
end

--- Replaces an existing "unlock-recipe" effect in the technology currently being manipulated with a new recipe.
--- If no matching effect is found, no changes are made.
--- @param old_recipe data.RecipeID The name of the recipe to replace.
--- @param new_recipe data.RecipeID The name of the new recipe to unlock.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If old_recipe or new_recipe is not a string.
function khaoslib_technology:replace_unlock_recipe(old_recipe, new_recipe)
  if type(old_recipe) ~= "string" then error("old_recipe parameter: Expected string, got " .. type(old_recipe), 2) end
  if type(new_recipe) ~= "string" then error("new_recipe parameter: Expected string, got " .. type(new_recipe), 2) end

  local effects = self.technology.effects or {}
  for _, effect in ipairs(effects) do
    if effect.type == "unlock-recipe" and effect.recipe == old_recipe then
      effect.recipe = new_recipe

      return self
    end
  end

  return self
end

--#endregion

return khaoslib_technology
