-- Handle both Factorio and testing environments
if ... ~= "__khaoslib__.recipe" and ... ~= "recipe" then
  if ... == "__khaoslib__.recipe" then
    return require("__khaoslib__.recipe")
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

-- Technology module needs special handling for testing
local khaoslib_technology
if module_loader.is_testing_environment() then
  khaoslib_technology = module_loader.create_mock_technology()
else
  khaoslib_technology = module_loader.load_khaoslib_module("technology")
end

-- #region Basic manipulation methods
-- Core methods for creating and working with recipe manipulation objects.

--- Recipe manipulation utilities for Factorio data stage.
---
--- This module provides a fluent API for creating, modifying, and managing recipe prototypes
--- during the data stage. It supports method chaining and uses the list utility module for
--- consistent ingredient and result manipulation.
---
--- Key features:
--- - Ingredients prevent duplicates (Factorio requirement)
--- - Results allow duplicates with specialized handling functions
--- - Technology unlock integration for recipe-tech relationships
--- - Comprehensive validation and error handling
--- - Method chaining for fluent API design
--- - Deep copying ensures data stage safety
--- - Options tables for extensible parameters
---
--- ## Basic Usage Examples
---
--- ```lua
--- local khaoslib_recipe = require("__khaoslib__.recipe")
---
--- -- Load an existing recipe for manipulation
--- khaoslib_recipe:load("electronic-circuit")
---   :copy("electronic-circuit-with-solder")
---   :add_ingredient({type = "item", name = "solder", amount = 5})
---   :replace_result("electronic-circuit", {type = "item", name = "electronic-circuit", amount = 2})
---   :commit()
---
--- -- Working with duplicate results (allowed in Factorio)
--- local recipe = khaoslib_recipe:load("my-recipe")
--- recipe:add_result({type = "item", name = "byproduct", amount = 1})
---   :add_result({type = "item", name = "byproduct", amount = 2})
--- recipe:count_matching_results("byproduct") -- returns 2
--- recipe:remove_result("byproduct") -- removes first match by default
--- recipe:remove_result("byproduct", {all = true}) -- removes all matches
---
--- -- Create a new recipe from scratch
--- khaoslib_recipe:load {
---   name = "advanced-circuit-with-solder",
---   category = "crafting",
---   energy_required = 5,
---   ingredients = {
---     {type = "item", name = "electronic-circuit", amount = 5},
---     {type = "item", name = "solder", amount = 10},
---   },
---   results = {
---     {type = "item", name = "advanced-circuit", amount = 2},
---   },
--- }:commit()
--- ```
---
--- ## Advanced Examples
---
--- ```lua
--- -- Complex ingredient manipulation
--- local recipe = khaoslib_recipe:load("steel-plate")
--- recipe:remove_ingredient("iron-plate")
---   :add_ingredient({type = "item", name = "processed-iron-ore", amount = 1})
---   :add_ingredient({type = "item", name = "carbon", amount = 1})
---   :set({energy_required = 3.2})
---   :commit()
---
--- -- Working with complex comparison functions
--- recipe:remove_result(function(result)
---   return result.probability and result.probability < 0.1 and result.amount < 2
--- end)
---
--- -- Conditional ingredient replacement
--- if recipe:has_ingredient("water") then
---   recipe:replace_ingredient("water", {type = "fluid", name = "heavy-water", amount = 100})
--- end
---
--- -- Bulk operations with validation
--- local iron_recipes = {"iron-plate", "iron-gear-wheel", "iron-stick"}
--- for _, recipe_name in ipairs(iron_recipes) do
---   if data.raw.recipe[recipe_name] then
---     khaoslib_recipe:load(recipe_name)
---       :set({energy_required = (data.raw.recipe[recipe_name].energy_required or 0.5) * 1.5})
---       :commit()
---   end
--- end
---
--- -- Technology unlock management
--- khaoslib_recipe:load("my-recipe")
---   :add_unlock("my-cool-tech-1")
---   :add_unlock("alternative-tech-2")
---   :remove_unlock("bad-tech")
---   :commit() -- Commits both recipe and modified technologies
--- ```
---
--- ## Performance Notes
---
--- - All operations use deep copying to ensure data stage safety
--- - Method chaining is efficient - intermediate states are not committed
--- - Use `has_ingredient()` and `has_result()` before expensive operations
--- - Bulk operations are more efficient than individual commits
---
--- @class khaoslib.RecipeManipulator
--- @field private recipe data.RecipePrototype The recipe currently being manipulated.
--- @field private modified_technologies table<string, khaoslib.TechnologyManipulator> Technologies that have been modified and need committing.
--- @operator add(khaoslib.RecipeManipulator): khaoslib.RecipeManipulator
local khaoslib_recipe = {}

--- Loads a given recipe for manipulation or creates a new one if a table is passed.
--- @param recipe data.RecipeID|data.RecipePrototype The name of an existing recipe or a new recipe prototype table.
--- @return khaoslib.RecipeManipulator manipulator A recipe manipulation object for the given recipe.
--- @throws If the recipe name doesn't exist or if a table is passed with a name that already exists or without a valid name field.
function khaoslib_recipe:load(recipe)
  if type(recipe) ~= "string" and type(recipe) ~= "table" then error("recipe parameter: Expected string or table, got " .. type(recipe), 2) end
  if type(recipe) == "string" and not data.raw.recipe[recipe] then error("No such recipe: " .. recipe, 2) end
  if type(recipe) == "table" and recipe.type and type(recipe.type) ~= "string" then error("recipe table type field should be a string if set", 2) end
  if type(recipe) == "table" and recipe.type and recipe.type ~= "recipe" then error("recipe table type field should be 'recipe' if set", 2) end
  if type(recipe) == "table" and (not recipe.name or type(recipe.name) ~= "string") then error("recipe table must have a name field of type string", 2) end
  if type(recipe) == "table" and data.raw.recipe[recipe.name] then error("A recipe with the name " .. recipe.name .. " already exists", 2) end

  local _recipe = recipe --luacheck: ignore 311
  if type(recipe) == "string" then
    _recipe = util.table.deepcopy(data.raw.recipe[recipe])
  else
    _recipe = util.table.deepcopy(recipe)
    _recipe.type = "recipe"
  end

  --- @cast _recipe data.RecipePrototype
  --- @type khaoslib.RecipeManipulator
  local obj = {recipe = _recipe, modified_technologies = {}}
  setmetatable(obj, self)
  self.__index = self

  return obj
end

--- Gets the raw data table of the recipe currently being manipulated.
--- @return data.RecipePrototype recipe A deep copy of the recipe currently being manipulated.
--- @nodiscard
function khaoslib_recipe:get()
  return util.table.deepcopy(self.recipe) --[[@as data.RecipePrototype]]
end

--- Merges the given fields into the recipe currently being manipulated.
--- @param fields table A table of fields to merge into the recipe. See `data.RecipePrototype` for valid fields.
--- @return khaoslib.RecipeManipulator self The same recipe manipulation object for method chaining.
--- @throws If fields is not a table or if it contains a name field.
function khaoslib_recipe:set(fields)
  if type(fields) ~= "table" then error("fields parameter: Expected table, got " .. type(fields), 2) end
  if fields.type then error("Cannot change the type of a recipe.", 2) end
  if fields.name then error("Cannot change the name of a recipe using set(). Use copy() to create a new recipe with a different name.", 2) end

  self.recipe = util.merge({self.recipe, fields})

  return self
end

--- Creates a deep copy of the recipe currently being manipulated.
--- @param new_name data.RecipeID The name of the new recipe. Must not already exist.
--- @return khaoslib.RecipeManipulator recipe A new recipe manipulation object with a deep copy of the recipe.
--- @throws If a recipe with the new name already exists.
--- @nodiscard
function khaoslib_recipe:copy(new_name)
  local copy = self:get()
  copy.name = new_name

  return khaoslib_recipe:load(copy)
end

--- Commits the changes made to the recipe currently being manipulated back to the data stage.
--- If the recipe already exists, it is overwritten. Also commits any modified technologies.
--- @return khaoslib.RecipeManipulator self The same recipe manipulation object for method chaining.
function khaoslib_recipe:commit()
  -- Commit the recipe
  self:remove()
  data:extend({self:get()})

  -- Commit all modified technologies
  for _, tech_manipulator in pairs(self.modified_technologies) do
    tech_manipulator:commit()
  end

  return self
end

--- Deletes the recipe currently being manipulated from the data stage.
--- @return khaoslib.RecipeManipulator self The same recipe manipulation object for method chaining.
function khaoslib_recipe:remove()
  data.raw.recipe[self.recipe.name] = nil

  return self
end

--- Merges another recipe manipulation object into this one, excluding the name field.
--- @param other khaoslib.RecipeManipulator The other recipe manipulation object to merge into this one
--- @return khaoslib.RecipeManipulator self The same recipe manipulation object for method chaining.
--- @throws If other is not a recipe manipulation object.
function khaoslib_recipe:__add(other)
  if type(other) ~= "table" or getmetatable(other) ~= khaoslib_recipe then error("Can only concatenate with another khaoslib.RecipeManipulator object", 2) end

  --- @cast other khaoslib.RecipeManipulator
  local other_copy = util.table.deepcopy(other.recipe)
  other_copy.type = nil
  other_copy.name = nil

  return self:set(other_copy)
end

--- Compares two recipe manipulation objects for equality based on the recipe name.
--- @param other khaoslib.RecipeManipulator The other recipe manipulation object to compare with.
--- @return boolean is_equal True if the two recipe manipulation objects represent the same recipe, false otherwise.
function khaoslib_recipe:__eq(other)
  if type(other) ~= "table" or getmetatable(other) ~= khaoslib_recipe then return false end

  --- @cast other khaoslib.RecipeManipulator
  return self.recipe.name == other.recipe.name
end

--- Returns a string representation of the recipe manipulation object.
--- @return string representation A string representation of the recipe manipulation object.
function khaoslib_recipe:__tostring()
  return "[khaoslib_recipe: " .. self.recipe.name .. "]"
end

-- #endregion

-- #region Recipe manipulation methods
-- Specialized methods for manipulating recipe ingredients, results, and properties.

--- Returns a deepcopy of all ingredients for the recipe currently being manipulated.
--- @return data.IngredientPrototype[] ingredients A list of ingredients required by the recipe.
function khaoslib_recipe:get_ingredients()
  return util.table.deepcopy(self.recipe.ingredients or {})
end

--- Sets the list of ingredients for the recipe currently being manipulated, replacing any existing ingredients.
--- @param ingredients data.IngredientPrototype[] A list of ingredients to set.
--- @return khaoslib.RecipeManipulator self The same recipe manipulation object for method chaining.
--- @throws If ingredients is not a table.
function khaoslib_recipe:set_ingredients(ingredients)
  if type(ingredients) ~= "table" then error("ingredients parameter: Expected table, got " .. type(ingredients), 2) end

  self.recipe.ingredients = util.table.deepcopy(ingredients)

  return self
end

--- Returns the number of ingredients for the recipe currently being manipulated.
--- @return integer count The number of ingredients.
function khaoslib_recipe:count_ingredients()
  return #(self.recipe.ingredients or {})
end

--- Checks if the recipe has an ingredient matching the given criteria.
--- Supports both string matching (by ingredient name) and custom comparison functions.
---
--- ```lua
--- -- By name (string)
--- if recipe:has_ingredient("water") then
---   -- Recipe uses water
--- end
---
--- -- By comparison function
--- if recipe:has_ingredient(function(ingredient)
---   return ingredient.type == "fluid" and ingredient.amount > 100
--- end) then
---   -- Recipe uses lots of fluid
--- end
--- ```
---
--- @param compare function|string A comparison function or ingredient name to match.
--- @return boolean has_ingredient True if the recipe has the ingredient, false otherwise.
--- @throws If compare is not a string or function.
function khaoslib_recipe:has_ingredient(compare)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.name == compare end
  end

  return khaoslib_list.has(self.recipe.ingredients, compare_fn)
end

--- Adds an ingredient to the recipe if it doesn't already exist (prevents duplicates).
--- @param ingredient data.IngredientPrototype The ingredient prototype to add.
--- @return khaoslib.RecipeManipulator self The same recipe manipulation object for method chaining.
--- @throws If ingredient is not a table or doesn't have required fields.
function khaoslib_recipe:add_ingredient(ingredient)
  if type(ingredient) ~= "table" then error("ingredient parameter: Expected table, got " .. type(ingredient), 2) end
  if not ingredient.type or type(ingredient.type) ~= "string" then error("ingredient parameter: Must have a type field of type string", 2) end
  if not ingredient.name or type(ingredient.name) ~= "string" then error("ingredient parameter: Must have a name field of type string", 2) end
  if not ingredient.amount or type(ingredient.amount) ~= "number" then error("ingredient parameter: Must have an amount field of type number", 2) end

  local compare_fn = function(existing)
    return existing.type == ingredient.type and existing.name == ingredient.name
  end

  self.recipe.ingredients = khaoslib_list.add(self.recipe.ingredients, ingredient, compare_fn)

  return self
end

--- Removes matching ingredients from the recipe.
---
--- ```lua
--- -- By name (string) - removes first match by default
--- recipe:remove_ingredient("iron-ore")
---
--- -- By comparison function - removes first match by default
--- recipe:remove_ingredient(function(ingredient)
---   return ingredient.amount > 10
--- end)
---
--- -- Remove all matching ingredients
--- recipe:remove_ingredient(function(ingredient)
---   return ingredient.type == "fluid"
--- end, {all = true})
--- ```
---
--- @param compare function|string A comparison function or ingredient name to match.
--- @param options table? Options table with fields: `all` (boolean, default false) - if true, removes all matching ingredients instead of just the first.
--- @return khaoslib.RecipeManipulator self The same recipe manipulation object for method chaining.
--- @throws If compare is not a string or function.
function khaoslib_recipe:remove_ingredient(compare, options)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end
  if options ~= nil and type(options) ~= "table" then error("options parameter: Expected table or nil, got " .. type(options), 2) end

  options = options or {}
  local remove_all = options.all or false

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.name == compare end
  end

  self.recipe.ingredients = khaoslib_list.remove(self.recipe.ingredients, compare_fn, {all = remove_all})

  return self
end

--- Replaces matching ingredients with a new ingredient.
--- If no matching ingredients are found, no changes are made.
---
--- ```lua
--- -- Replace by name (string parameter) - replaces first match by default
--- recipe:replace_ingredient("iron-ore", {type = "item", name = "processed-iron-ore", amount = 1})
---
--- -- Replace with custom function (function parameter) - replaces first match by default
--- recipe:replace_ingredient(function(ingredient)
---   return ingredient.type == "fluid" and ingredient.amount > 50
--- end, {type = "fluid", name = "purified-water", amount = 25})
---
--- -- Replace all matching ingredients
--- recipe:replace_ingredient(function(ingredient)
---   return ingredient.type == "fluid"
--- end, {type = "fluid", name = "water", amount = 10}, {all = true})
--- ```
---
--- @param old_ingredient function|string A comparison function or ingredient name to match.
--- @param new_ingredient data.IngredientPrototype The new ingredient prototype to replace with.
--- @param options table? Options table with fields: `all` (boolean, default false) - if true, replaces all matching ingredients instead of just the first.
--- @return khaoslib.RecipeManipulator self The same recipe manipulation object for method chaining.
--- @throws If old_ingredient is not a string or function, or new_ingredient is not a table.
function khaoslib_recipe:replace_ingredient(old_ingredient, new_ingredient, options)
  if type(old_ingredient) ~= "string" and type(old_ingredient) ~= "function" then 
    error("old_ingredient parameter: Expected string or function, got " .. type(old_ingredient), 2) 
  end
  if type(new_ingredient) ~= "table" then error("new_ingredient parameter: Expected table, got " .. type(new_ingredient), 2) end
  if not new_ingredient.type or type(new_ingredient.type) ~= "string" then error("new_ingredient parameter: Must have a type field of type string", 2) end
  if not new_ingredient.name or type(new_ingredient.name) ~= "string" then error("new_ingredient parameter: Must have a name field of type string", 2) end
  if not new_ingredient.amount or type(new_ingredient.amount) ~= "number" then 
    error("new_ingredient parameter: Must have an amount field of type number", 2) 
  end
  if options ~= nil and type(options) ~= "table" then error("options parameter: Expected table or nil, got " .. type(options), 2) end

  options = options or {}
  local replace_all = options.all or false

  local compare_fn = old_ingredient
  if type(old_ingredient) == "string" then
    compare_fn = function(existing) return existing.name == old_ingredient end
  end

  self.recipe.ingredients = khaoslib_list.replace(self.recipe.ingredients, new_ingredient, compare_fn, {all = replace_all})

  return self
end

--- Removes all ingredients from the recipe (clears the ingredients list).
--- @return khaoslib.RecipeManipulator self The same recipe manipulation object for method chaining.
function khaoslib_recipe:clear_ingredients()
  self.recipe.ingredients = {}

  return self
end

--- Returns a deep copy of all results produced by the recipe.
--- @return data.ProductPrototype[] results A list of results produced by the recipe.
function khaoslib_recipe:get_results()
  return util.table.deepcopy(self.recipe.results or {})
end

--- Sets the complete list of results for the recipe, replacing any existing results.
--- @param results data.ProductPrototype[] A list of results to set.
--- @return khaoslib.RecipeManipulator self The same recipe manipulation object for method chaining.
--- @throws If results is not a table.
function khaoslib_recipe:set_results(results)
  if type(results) ~= "table" then error("results parameter: Expected table, got " .. type(results), 2) end

  self.recipe.results = util.table.deepcopy(results)

  return self
end

--- Returns the number of different result types produced by the recipe currently being manipulated.
--- @return integer count The number of result types.
function khaoslib_recipe:count_results()
  return #(self.recipe.results or {})
end

--- Checks if the recipe produces a result matching the given criteria.
--- Supports both string matching (by result name) and custom comparison functions.
---
--- ```lua
--- -- By name (string)
--- if recipe:has_result("iron-plate") then
---   -- Recipe produces iron plates
--- end
---
--- -- By comparison function
--- if recipe:has_result(function(result)
---   return result.probability and result.probability < 0.1
--- end) then
---   -- Recipe has low-probability results
--- end
--- ```
---
--- @param compare function|string A comparison function or result name to match.
--- @return boolean has_result True if the recipe produces the result, false otherwise.
--- @throws If compare is not a string or function.
function khaoslib_recipe:has_result(compare)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.name == compare end
  end

  local results = self:get_results()
  return khaoslib_list.has(results, compare_fn)
end

--- Counts how many results match the given criteria.
--- Supports both string matching (by result name) and custom comparison functions.
--- This is useful since recipes can have duplicate results.
---
--- ```lua
--- -- Count by name (string)
--- local byproduct_count = recipe:count_matching_results("byproduct")
--- log("Recipe has " .. byproduct_count .. " byproduct results")
---
--- -- Count by comparison function
--- local rare_count = recipe:count_matching_results(function(result)
---   return result.probability and result.probability < 0.1
--- end)
--- ```
---
--- @param compare function|string A comparison function or result name to match.
--- @return integer count The number of matching results.
--- @throws If compare is not a string or function.
function khaoslib_recipe:count_matching_results(compare)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.name == compare end
  end

  local count = 0
  local results = self:get_results()
  for _, result in ipairs(results) do
    if compare_fn(result) then
      count = count + 1
    end
  end

  return count
end

--- Adds a result to the recipe.
--- Unlike ingredients, results can have duplicates in Factorio recipes.
--- @param result data.ProductPrototype The result prototype to add.
--- @return khaoslib.RecipeManipulator self The same recipe manipulation object for method chaining.
--- @throws If result is not a table or doesn't have required fields.
function khaoslib_recipe:add_result(result)
  if type(result) ~= "table" then error("result parameter: Expected table, got " .. type(result), 2) end
  if not result.type or type(result.type) ~= "string" then error("result parameter: Must have a type field of type string", 2) end
  if not result.name or type(result.name) ~= "string" then error("result parameter: Must have a name field of type string", 2) end
  if not result.amount or type(result.amount) ~= "number" then error("result parameter: Must have an amount field of type number", 2) end

  self.recipe.results = khaoslib_list.add(self.recipe.results, result, nil, {allow_duplicates = true})

  return self
end

--- Gets all results that match the given criteria.
--- This is useful since recipes can have duplicate results.
---
--- ```lua
--- -- Get by name (string)
--- local byproducts = recipe:get_matching_results("byproduct")
---
--- -- Get by comparison function
--- local rare_results = recipe:get_matching_results(function(result)
---   return result.probability and result.probability < 0.1
--- end)
--- ```
---
--- @param compare function|string A comparison function or result name to match.
--- @return data.ProductPrototype[] matching_results A list of all matching results (deep copies).
--- @throws If compare is not a string or function.
function khaoslib_recipe:get_matching_results(compare)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.name == compare end
  end

  local matching_results = {}
  local results = self:get_results()
  for _, result in ipairs(results) do
    if compare_fn(result) then
      table.insert(matching_results, util.table.deepcopy(result))
    end
  end

  return matching_results
end

--- Removes matching results from the recipe.
---
--- ```lua
--- -- Remove by name (string parameter) - removes first match by default
--- khaoslib.recipe("electronic-circuit"):remove_result("copper-cable")
---
--- -- Remove with custom function (function parameter) - removes first match by default
--- khaoslib.recipe("electronic-circuit"):remove_result(function(result)
---   return result.name == "electronic-circuit" and (result.amount or 1) > 1
--- end)
---
--- -- Remove all matches
--- khaoslib.recipe("electronic-circuit"):remove_result("electronic-circuit", {all = true})
--- ```
---
--- @param compare function|string A comparison function or result name to match.
--- @param options table? Options table with fields: `all` (boolean, default false) - if true, removes all matching results instead of just the first.
--- @return khaoslib.RecipeManipulator self The same recipe manipulation object for method chaining.
--- @throws If compare is not a string or function.
function khaoslib_recipe:remove_result(compare, options)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end
  if options ~= nil and type(options) ~= "table" then error("options parameter: Expected table or nil, got " .. type(options), 2) end

  options = options or {}
  local remove_all = options.all or false

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.name == compare end
  end

  self.recipe.results = khaoslib_list.remove(self.recipe.results, compare_fn, {all = remove_all})

  return self
end

--- Replaces matching results with a new result.
--- If no matching results are found, no changes are made.
---
--- ```lua
--- -- Replace by name (string parameter) - replaces first match by default
--- recipe:replace_result("iron-plate", {type = "item", name = "steel-plate", amount = 1})
---
--- -- Replace with custom function (function parameter) - replaces first match by default
--- recipe:replace_result(function(result)
---   return result.probability and result.probability < 0.5
--- end, {type = "item", name = "rare-metal", amount = 1, probability = 0.1})
---
--- -- Replace all matches
--- recipe:replace_result("electronic-circuit", {type = "item", name = "advanced-circuit", amount = 1}, {all = true})
--- ```
---
--- @param old_result function|string A comparison function or result name to match.
--- @param new_result data.ProductPrototype The new result prototype to replace with.
--- @param options table? Options table with fields: `all` (boolean, default false) - if true, replaces all matching results 
---   instead of just the first.
--- @return khaoslib.RecipeManipulator self The same recipe manipulation object for method chaining.
--- @throws If old_result is not a string or function, or new_result is not a table.
function khaoslib_recipe:replace_result(old_result, new_result, options)
  if type(old_result) ~= "string" and type(old_result) ~= "function" then error("old_result parameter: Expected string or function, got " .. type(old_result), 2) end
  if type(new_result) ~= "table" then error("new_result parameter: Expected table, got " .. type(new_result), 2) end
  if not new_result.type or type(new_result.type) ~= "string" then error("new_result parameter: Must have a type field of type string", 2) end
  if not new_result.name or type(new_result.name) ~= "string" then error("new_result parameter: Must have a name field of type string", 2) end
  if not new_result.amount or type(new_result.amount) ~= "number" then error("new_result parameter: Must have an amount field of type number", 2) end
  if options ~= nil and type(options) ~= "table" then error("options parameter: Expected table or nil, got " .. type(options), 2) end

  options = options or {}
  local replace_all = options.all or false

  local compare_fn = old_result
  if type(old_result) == "string" then
    compare_fn = function(existing) return existing.name == old_result end
  end

  self.recipe.results = khaoslib_list.replace(self.recipe.results, new_result, compare_fn, {all = replace_all})

  return self
end

--- Removes all results from the recipe (clears the results list).
--- @return khaoslib.RecipeManipulator self The same recipe manipulation object for method chaining.
function khaoslib_recipe:clear_results()
  self.recipe.results = {}

  return self
end

-- #endregion

-- #region Technology unlock methods
-- Methods for managing which technologies unlock this recipe.

--- Adds this recipe as an unlock-recipe effect to the specified technology.
--- The technology modification is tracked and will be committed when the recipe is committed.
---
--- ```lua
--- -- Add this recipe to a technology's unlock effects
--- khaoslib_recipe:load("my-recipe")
---   :add_unlock("my-cool-tech-1")
---   :add_unlock("alternative-tech-2")
---   :commit() -- Commits both recipe and modified technologies
--- ```
---
--- @param technology data.TechnologyID The name of the technology to add this recipe's unlock effect to.
--- @return khaoslib.RecipeManipulator self The same recipe manipulation object for method chaining.
--- @throws If technology is not a string or if the technology doesn't exist.
function khaoslib_recipe:add_unlock(technology)
  if not khaoslib_technology.exists(technology) then error("No such technology: " .. technology, 2) end

  -- Load or get existing technology manipulator
  local tech_manipulator = self.modified_technologies[technology]
  if not tech_manipulator then
    tech_manipulator = khaoslib_technology:load(technology)
    self.modified_technologies[technology] = tech_manipulator
  end

  -- Add unlock recipe effect
  tech_manipulator:add_unlock_recipe(self.recipe.name)

  return self
end

--- Removes this recipe's unlock-recipe effect from the specified technology.
--- The technology modification is tracked and will be committed when the recipe is committed.
---
--- ```lua
--- -- Remove this recipe from a technology's unlock effects
--- khaoslib_recipe:load("my-recipe")
---   :remove_unlock("bad-tech")
---   :remove_unlock("old-tech")
---   :commit() -- Commits both recipe and modified technologies
--- ```
---
--- @param technology data.TechnologyID The name of the technology to remove this recipe's unlock effect from.
--- @return khaoslib.RecipeManipulator self The same recipe manipulation object for method chaining.
--- @throws If technology is not a string or if the technology doesn't exist.
function khaoslib_recipe:remove_unlock(technology)
  if not khaoslib_technology.exists(technology) then error("No such technology: " .. technology, 2) end

  -- Load or get existing technology manipulator
  local tech_manipulator = self.modified_technologies[technology]
  if not tech_manipulator then
    tech_manipulator = khaoslib_technology:load(technology)
    self.modified_technologies[technology] = tech_manipulator
  end

  -- Remove unlock recipe effect (remove all matching effects by default)
  tech_manipulator:remove_unlock_recipe(self.recipe.name, {all = true})

  return self
end

-- #endregion

return khaoslib_recipe
