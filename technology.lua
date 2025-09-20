-- Handle both Factorio and testing environments
if ... ~= "__khaoslib__.technology" and ... ~= "technology" then
  if ... == "__khaoslib__.technology" then
    return require("__khaoslib__.technology")
  end
end

-- Load dependencies with shared module loader
local module_loader
if type(data) == "nil" or _G.util ~= nil then
  -- Testing environment
  module_loader = require("module_loader")
else
  -- Factorio environment
  --- @diagnostic disable-next-line: different-requires
  module_loader = require("__khaoslib__.module_loader")
end

local khaoslib_list = module_loader.load_khaoslib_module("list")
local util = module_loader.load_util()

--#region Basic manipulation methods
-- A set of basic methods for creating and working with technology manipulation objects.

--- Technology manipulation utilities for Factorio data stage.
---
--- This module provides a fluent API for creating, modifying, and managing technology prototypes
--- during the data stage. It supports method chaining and uses the list utility module for
--- consistent prerequisite and effect manipulation.
---
--- Key features:
--- - Prerequisites prevent duplicates (Factorio requirement)
--- - Effects allow duplicates with specialized handling functions
--- - Science pack cost manipulation with comprehensive control
--- - Comprehensive validation and error handling
--- - Method chaining for fluent API design
--- - Deep copying ensures data stage safety
--- - Options tables for extensible parameters
--- - 'all' option support for bulk operations
--- - Flexible comparison functions for advanced matching
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
--- ## Advanced Examples
---
--- ```lua
--- -- Complex prerequisite manipulation
--- local tech = khaoslib_technology:load("example")
--- tech:remove_prerequisite(function(prereq)
---   return prereq:match("^military%-") and not prereq:match("%-science%-")
--- end, {all = true})
---   :add_prerequisite("peaceful-research")
---   :commit()
---
--- -- Working with complex effect manipulation
--- tech:remove_effect(function(effect)
---   return effect.type == "unlock-recipe" and
---     data.raw.recipe[effect.recipe] and
---     data.raw.recipe[effect.recipe].category == "chemistry"
--- end, {all = true})
---
--- -- Conditional technology replacement
--- if tech:has_prerequisite("old-tech") then
---   tech:replace_prerequisite("old-tech", "new-tech")
--- end
---
--- -- Science pack cost manipulation
--- local tech = khaoslib_technology:load("expensive-research")
--- tech:add_science_pack({type = "item", name = "space-science-pack", amount = 1})
---   :replace_science_pack("automation-science-pack", {
---     type = "item", name = "automation-science-pack", amount = 2
---   })
---   :remove_science_pack(function(ingredient)
---     return ingredient.name:match("^military%-")
---   end, {all = true})
---   :commit()
---
--- -- Rebalance all technologies for difficulty mod
--- local all_techs = khaoslib_technology.find(function(tech)
---   return tech.unit and tech.unit.ingredients
--- end)
--- for _, tech_name in ipairs(all_techs) do
---   khaoslib_technology:load(tech_name)
---     :replace_science_pack(function(ingredient)
---       return ingredient.amount == 1
---     end, function(ingredient)
---       local new_ingredient = util.table.deepcopy(ingredient)
---       new_ingredient.amount = 2  -- Double all single-pack costs
---       return new_ingredient
---     end, {all = true})
---     :commit()
--- end
---
--- -- Bulk technology cleanup
--- local deprecated_techs = {"old-tech-1", "old-tech-2", "old-tech-3"}
--- for _, technology in ipairs(deprecated_techs) do
---   if khaoslib_technology.exists(technology) then
---     khaoslib_technology:load(technology)
---       :remove_effect(function(e) return e.type == "unlock-recipe" end, {all = true})
---       :add_effect({type = "nothing", effect_description = "Technology deprecated"})
---       :commit()
---   end
--- end
--- ```
---
--- ## Performance Notes
---
--- - All operations use deep copying to ensure data stage safety
--- - Method chaining is efficient - intermediate states are not committed
--- - Use `has_prerequisite()` and `has_effect()` before expensive operations
--- - Bulk operations are more efficient than individual commits
--- - Function comparisons enable powerful but potentially expensive matching
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

--- Creates a deep copy of the technology.
--- @param new_name data.TechnologyID The name of the new technology. Must not already exist.
--- @return khaoslib.TechnologyManipulator technology A new technology manipulation object with a deep copy of the technology.
--- @throws If a technology with the new name already exists.
--- @nodiscard
function khaoslib_technology:copy(new_name)
  local copy = self:get()
  copy.name = new_name

  return khaoslib_technology:load(copy)
end

--- Commits the changes to the data stage.
--- If the technology already exists, it is overwritten.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
function khaoslib_technology:commit()
  data:extend({self:remove():get()})

  return self
end

--- Deletes the technology from the data stage.
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

--- Returns a list of all prerequisite technologies.
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
--- @param compare function|string A comparison function or prerequisite name to match.
--- @return boolean has_prerequisite True if the technology has the prerequisite, false otherwise.
--- @throws If compare is not a string or function.
function khaoslib_technology:has_prerequisite(compare)
  local compare_fn
  if type(compare) == "string" then
    compare_fn = function(prereq) return prereq == compare end
  elseif type(compare) == "function" then
    compare_fn = compare
  else
    error("compare parameter: Expected string or function, got " .. type(compare), 2)
  end

  return khaoslib_list.has(self.technology.prerequisites, compare_fn)
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
--- @param compare function|string A comparison function or prerequisite name to match.
--- @param options table? Options table with fields: `all` (boolean, default false) - if true, removes all matching prerequisites instead of just the first.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If compare is not a string or function.
function khaoslib_technology:remove_prerequisite(compare, options)
  local compare_fn
  if type(compare) == "string" then
    compare_fn = function(prereq) return prereq == compare end
  elseif type(compare) == "function" then
    compare_fn = compare
  else
    error("compare parameter: Expected string or function, got " .. type(compare), 2)
  end

  options = options or {}
  local remove_options = {all = options.all or false}

  self.technology.prerequisites = khaoslib_list.remove(self.technology.prerequisites, compare_fn, remove_options)

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
--- @param old_prerequisite function|string A comparison function or prerequisite name to match.
--- @param new_prerequisite data.TechnologyID The new prerequisite technology name to replace with.
--- @param options table? Options table with fields: `all` (boolean, default false) - if true, replaces all matching prerequisites instead of just the first.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If old_prerequisite is not a string or function, or new_prerequisite is not a string.
function khaoslib_technology:replace_prerequisite(old_prerequisite, new_prerequisite, options)
  local compare_fn
  if type(old_prerequisite) == "string" then
    compare_fn = function(prereq) return prereq == old_prerequisite end
  elseif type(old_prerequisite) == "function" then
    compare_fn = old_prerequisite
  else
    error("old_prerequisite parameter: Expected string or function, got " .. type(old_prerequisite), 2)
  end

  if type(new_prerequisite) ~= "string" then error("new_prerequisite parameter: Expected string, got " .. type(new_prerequisite), 2) end

  options = options or {}
  local replace_options = {all = options.all or false}

  self.technology.prerequisites = khaoslib_list.replace(self.technology.prerequisites, new_prerequisite, compare_fn, replace_options)

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

  return khaoslib_list.has(self.technology.effects, compare_fn)
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
--- @param options table? Options table with fields: `all` (boolean, default false) - if true, removes all matching effects instead of just the first.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If compare_fn is not a function.
function khaoslib_technology:remove_effect(compare_fn, options)
  if type(compare_fn) ~= "function" then error("compare_fn parameter: Expected function, got " .. type(compare_fn), 2) end

  options = options or {}
  local remove_options = {all = options.all or false}

  self.technology.effects = khaoslib_list.remove(self.technology.effects, compare_fn, remove_options)

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
--- @param new_effect data.Modifier The new effect to add. See `data.Modifier` for valid effect types.
--- @param options table? Options table with fields: `all` (boolean, default false) - if true, replaces all matching effects instead of just the first.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If compare_fn is not a function or if new_effect is not a table.
function khaoslib_technology:replace_effect(compare_fn, new_effect, options)
  if type(compare_fn) ~= "function" then error("compare_fn parameter: Expected function, got " .. type(compare_fn), 2) end
  if type(new_effect) ~= "table" then error("new_effect parameter: Expected table, got " .. type(new_effect), 2) end

  options = options or {}
  local replace_options = {all = options.all or false}

  self.technology.effects = khaoslib_list.replace(self.technology.effects, new_effect, compare_fn, replace_options)

  return self
end

--- Removes all effects from the technology currently being manipulated.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
function khaoslib_technology:clear_effects()
  self.technology.effects = {}

  return self
end

--- Gets all recipes unlocked by the technology currently being manipulated.
--- @return data.RecipeID[] recipe_names A list of recipe names unlocked by this technology.
function khaoslib_technology:get_unlock_recipes()
  local result = {}
  if self.technology.effects then
    for _, effect in ipairs(self.technology.effects) do
      if effect.type == "unlock-recipe" and effect.recipe then
        table.insert(result, effect.recipe)
      end
    end
  end

  return util.table.deepcopy(result)
end

--- Returns the number of unlock-recipe effects in the technology currently being manipulated.
--- @return integer count The number of unlock-recipe effects.
function khaoslib_technology:count_unlock_recipes()
  local count = 0
  if self.technology.effects then
    for _, effect in ipairs(self.technology.effects) do
      if effect.type == "unlock-recipe" then
        count = count + 1
      end
    end
  end

  return count
end

--- Returns `true` if the technology currently being manipulated has an "unlock-recipe" effect for the given recipe.
--- @param recipe data.RecipeID The name of the recipe to check for.
--- @return boolean has_unlock_recipe True if the technology has an unlock-recipe effect for the recipe, false otherwise.
--- @throws If recipe is not a string.
function khaoslib_technology:has_unlock_recipe(recipe)
  if type(recipe) ~= "string" then error("recipe parameter: Expected string, got " .. type(recipe), 2) end

  return self:has_effect(function(effect)
    return effect.type == "unlock-recipe" and effect.recipe == recipe
  end)
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
--- @param recipe data.RecipeID The name of the recipe to remove.
--- @param options table? Options table with fields: `all` (boolean, default false) - if true, removes all matching unlock-recipe effects instead of just the first.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If recipe is not a string.
function khaoslib_technology:remove_unlock_recipe(recipe, options)
  if type(recipe) ~= "string" then error("recipe parameter: Expected string, got " .. type(recipe), 2) end

  options = options or {}
  local remove_options = {all = options.all or false}

  return self:remove_effect(function(effect)
    return effect.type == "unlock-recipe" and effect.recipe == recipe
  end, remove_options)
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
--- @param old_recipe data.RecipeID The name of the recipe to replace.
--- @param new_recipe data.RecipeID The name of the new recipe to unlock.
--- @param options table? Options table with fields: `all` (boolean, default false) - if true, replaces all matching unlock-recipe effects instead of just the first.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If old_recipe or new_recipe is not a string.
function khaoslib_technology:replace_unlock_recipe(old_recipe, new_recipe, options)
  if type(old_recipe) ~= "string" then error("old_recipe parameter: Expected string, got " .. type(old_recipe), 2) end
  if type(new_recipe) ~= "string" then error("new_recipe parameter: Expected string, got " .. type(new_recipe), 2) end

  options = options or {}
  local replace_options = {all = options.all or false}

  return self:replace_effect(
    function(effect) return effect.type == "unlock-recipe" and effect.recipe == old_recipe end,
    {type = "unlock-recipe", recipe = new_recipe},
    replace_options
  )
end

--- Returns a list of all science packs for the technology.
--- @return data.ResearchIngredient[] science_packs A deep copy of the science packs.
function khaoslib_technology:get_science_packs()
  if not self.technology.unit or not self.technology.unit.ingredients then
    return {}
  end

  return util.table.deepcopy(self.technology.unit.ingredients)
end

--- Sets the science pack list, replacing existing ones.
--- @param science_packs data.ResearchIngredient[] A list of science packs to set.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If science_packs is not a table.
function khaoslib_technology:set_science_packs(science_packs)
  if type(science_packs) ~= "table" then error("science_packs parameter: Expected table, got " .. type(science_packs), 2) end

  if not self.technology.unit then
    --- @diagnostic disable-next-line: missing-fields
    self.technology.unit = {}
  end

  self.technology.unit.ingredients = util.table.deepcopy(science_packs)

  return self
end

--- Returns the number of science packs for the technology currently being manipulated.
--- @return integer count The number of science packs.
function khaoslib_technology:count_science_packs()
  if not self.technology.unit or not self.technology.unit.ingredients then
    return 0
  end

  return #self.technology.unit.ingredients
end

--- Checks if the technology has a science pack matching the given criteria.
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
--- @param compare function|string A comparison function or science pack name to match.
--- @return boolean has_science_pack True if the technology has the science pack, false otherwise.
--- @throws If compare is not a string or function.
function khaoslib_technology:has_science_pack(compare)
  local compare_fn
  if type(compare) == "string" then
    compare_fn = function(ingredient) return ingredient[1] == compare end
  elseif type(compare) == "function" then
    compare_fn = compare
  else
    error("compare parameter: Expected string or function, got " .. type(compare), 2)
  end

  if not self.technology.unit or not self.technology.unit.ingredients then
    return false
  end

  return khaoslib_list.has(self.technology.unit.ingredients, compare_fn)
end

--- Adds a science pack to the technology currently being manipulated if it doesn't already exist.
--- science packs cannot have duplicates (Factorio requirement).
--- @param science_pack data.ResearchIngredient The science pack to add.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If science_pack is not a table or doesn't have a name field.
function khaoslib_technology:add_science_pack(science_pack)
  if type(science_pack) ~= "table" then error("science_pack parameter: Expected table, got " .. type(science_pack), 2) end
  if not science_pack[1] then error("science_pack parameter: Missing science pack name at index 1", 2) end
  if not science_pack[2] then error("science_pack parameter: Missing science pack amount at index 2", 2) end

  if not self.technology.unit then
    --- @diagnostic disable-next-line: missing-fields
    self.technology.unit = {}
  end

  self.technology.unit.ingredients = khaoslib_list.add(self.technology.unit.ingredients, science_pack, function(existing)
    return existing[1] == science_pack[1]
  end)

  return self
end

--- Removes matching science packs from the technology.
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
--- @param compare function|string A comparison function or science pack name to match.
--- @param options table? Options table with fields: `all` (boolean, default false) - if true, removes all matching science packs instead of just the first.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If compare is not a string or function.
function khaoslib_technology:remove_science_pack(compare, options)
  local compare_fn
  if type(compare) == "string" then
    compare_fn = function(ingredient) return ingredient[1] == compare end
  elseif type(compare) == "function" then
    compare_fn = compare
  else
    error("compare parameter: Expected string or function, got " .. type(compare), 2)
  end

  if not self.technology.unit or not self.technology.unit.ingredients then
    return self
  end

  options = options or {}
  local remove_options = {all = options.all or false}

  self.technology.unit.ingredients = khaoslib_list.remove(self.technology.unit.ingredients, compare_fn, remove_options)

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
--- @param old_science_pack function|string A comparison function or science pack name to match.
--- @param new_science_pack data.ResearchIngredient The new science pack to replace with.
--- @param options table? Options table with fields: `all` (boolean, default false) - if true, replaces all matching science packs instead of just the first.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If old_science_pack is not a string or function, or new_science_pack is not a table.
function khaoslib_technology:replace_science_pack(old_science_pack, new_science_pack, options)
  local compare_fn
  if type(old_science_pack) == "string" then
    compare_fn = function(ingredient) return ingredient[1] == old_science_pack end
  elseif type(old_science_pack) == "function" then
    compare_fn = old_science_pack
  else
    error("old_science_pack parameter: Expected string or function, got " .. type(old_science_pack), 2)
  end

  if type(new_science_pack) ~= "table" then error("new_science_pack parameter: Expected table, got " .. type(new_science_pack), 2) end

  if not self.technology.unit or not self.technology.unit.ingredients then
    return self
  end

  options = options or {}
  local replace_options = {all = options.all or false}

  self.technology.unit.ingredients = khaoslib_list.replace(self.technology.unit.ingredients, new_science_pack, compare_fn, replace_options)

  return self
end

--- Removes all science packs from the technology currently being manipulated.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
function khaoslib_technology:clear_science_packs()
  if not self.technology.unit then
    --- @diagnostic disable-next-line: missing-fields
    self.technology.unit = {}
  end

  self.technology.unit.ingredients = {}

  return self
end

--#endregion

--#region Utility functions
-- Module-level utility functions for technology discovery and analysis.

--- Checks if a technology exists in the data stage.
--- @param technology_name data.TechnologyID The technology name to check.
--- @return boolean exists True if the technology exists, false otherwise.
function khaoslib_technology.exists(technology_name)
  if type(technology_name) ~= "string" then error("technology_name parameter: Expected string, got " .. type(technology_name), 2) end

  return data.raw.technology[technology_name] ~= nil
end

--- Finds all technologies that match a custom filter function.
--- @param filter_fn fun(technology: data.TechnologyPrototype): boolean A function that returns true for technologies to include.
--- @return data.TechnologyID[] technologies A list of technology names that match the filter.
--- @throws If filter_fn is not a function.
function khaoslib_technology.find(filter_fn)
  if type(filter_fn) ~= "function" then error("filter_fn parameter: Expected function, got " .. type(filter_fn), 2) end

  local result = {}
  for _, technology in pairs(data.raw.technology or {}) do
    if filter_fn(technology) then
      table.insert(result, technology.name)
    end
  end
  return result
end

--#endregion

return khaoslib_technology
