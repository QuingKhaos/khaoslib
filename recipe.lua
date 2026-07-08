local khaoslib_list = require("__khaoslib__.list")
local khaoslib_technology = require("__khaoslib__.technology")
local util = require("util")

-- #region Basic manipulation methods
-- Core methods for creating and working with recipe manipulation objects.

--- Recipe manipulation utilities for Factorio data stage.
---
--- This module provides a fluent API for creating, modifying, and managing recipe prototypes
--- during the data stage. It supports method chaining and uses the list utility module for
--- consistent ingredient and result manipulation.
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
  local recipe_type = type(recipe)
  if recipe_type ~= "string" and recipe_type ~= "table" then error("recipe parameter: Expected string or table, got " .. type(recipe), 2) end

  if recipe_type == "string" then
    if not khaoslib_recipe.exists(recipe) then error("No such recipe: " .. recipe, 2) end
  else -- recipe_type == table
    if recipe.type and type(recipe.type) ~= "string" then error("recipe table type field should be a string if set", 2) end
    if recipe.type and recipe.type ~= "recipe" then error("recipe table type field should be 'recipe' if set", 2) end
    if not recipe.name or type(recipe.name) ~= "string" then error("recipe table must have a name field of type string", 2) end
    if data.raw.recipe[recipe.name] then error("A recipe with the name " .. recipe.name .. " already exists", 2) end
  end

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

--- @diagnostic disable: invisible

--- Internal helper function to resole the recipe from a string, recipe prototype data or a recipe manipulation object.
--- @param recipe data.RecipeID|data.RecipePrototype|khaoslib.RecipeManipulator The recipe to resolve.
--- @return data.RecipePrototype resolved_recipe The resolved recipe prototype.
--- @throws If the recipe cannot be resolved.
local resolve = function(recipe)
  if type(recipe) == "string" then
    local result = data.raw.recipe[recipe]
    if not result then
      error("No such recipe: " .. recipe, 3)
    end

    return result
  elseif type(recipe) == "table" then
    if getmetatable(recipe) == khaoslib_recipe and recipe.recipe then
      return recipe.recipe
    elseif recipe.type == "recipe" and recipe.name then
      return recipe --[[@as data.RecipePrototype]]
    else
      error("Invalid recipe table: expected manipulator or prototype with type='recipe' and name", 3)
    end
  else
    error("Invalid recipe parameter: expected recipe name, prototype table, or recipe manipulator", 3)
  end
end

--- @diagnostic enable: invisible

--- Gets the raw prototype data of the recipe currently being manipulated.
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

--- Unsets the given field in the recipe currently being manipulated.
--- @param field string The field to unset in the recipe. See `data.RecipePrototype` for valid fields.
--- @return khaoslib.RecipeManipulator self The same recipe manipulation object for method chaining.
--- @throws If field is not a string, or if it is the type or name field.
function khaoslib_recipe:unset(field)
  if type(field) ~= "string" then error("field parameter: Expected string, got " .. type(field), 2) end
  if field == "type" then error("Cannot unset the type of a recipe.", 2) end
  if field == "name" then error("Cannot unset the name of a recipe.", 2) end

  self.recipe[field] = nil

  return self
end

--- Creates a deep copy of the given recipe.
--- @param recipe data.RecipeID|data.RecipePrototype|khaoslib.RecipeManipulator The recipe.
--- @param new_name data.RecipeID The name of the new recipe. Must not already exist.
--- @return khaoslib.RecipeManipulator recipe A new recipe manipulation object with a deep copy of the recipe.
--- @throws If a recipe with the new name already exists.
--- @nodiscard
function khaoslib_recipe.copy(recipe, new_name)
  local copy = util.table.deepcopy(resolve(recipe))
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

--- Deletes the recipe currently being manipulated from the data stage instantly. Use with caution, as this works without a commit.
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
-- Specialized methods for manipulating recipe icons, ingredients, results, and properties.

--- If the recipe has a single icon, it is converted to the icons list format. If the recipe already has an icons list, no changes are made.
--- @param recipe data.RecipePrototype The recipe reference to populate icons for.
local populate_icons = function(recipe)
  if recipe.icon and (not recipe.icons or #recipe.icons == 0) then
    recipe.icons = {{icon = recipe.icon, icon_size = recipe.icon_size or nil}}
    recipe.icon = nil
    recipe.icon_size = nil
  end
end

--- If just a single item exists in the icons list, and it has no special properties, depopulate the icons list and set the icon and icon_size fields instead.
--- @param recipe data.RecipePrototype The recipe reference to depopulate icons from.
local depopulate_icons = function(recipe)
  if #recipe.icons == 1 then
    local icon = recipe.icons[1]
    if icon.tint == nil and icon.shift == nil and icon.scale == nil and icon.draw_background == nil and icon.floating == nil then
      recipe.icon = icon.icon
      recipe.icon_size = icon.icon_size or nil
      recipe.icons = nil
    end
  end
end

--- Returns a deepcopy of all icons for the given recipe. If the recipe has a single icon, it is returned as a single-element list.
--- @param recipe data.RecipeID|data.RecipePrototype|khaoslib.RecipeManipulator The recipe.
--- @return data.IconData[] icons A list of icons for the recipe.
--- @nodiscard
function khaoslib_recipe.get_icons(recipe)
  local resolved_recipe = resolve(recipe)
  if resolved_recipe.icon then
    return util.table.deepcopy({icon = resolved_recipe.icon, icon_size = resolved_recipe.icon_size or nil})
  elseif resolved_recipe.icons then
    return util.table.deepcopy(resolved_recipe.icons --[=[@as data.IconData[]]=])
  else
    return {}
  end
end

--- Sets the list of icons for the recipe currently being manipulated, replacing any existing icons.
--- @param icons data.IconData[] A list of icons to set.
--- @return khaoslib.RecipeManipulator self The same recipe manipulation object for method chaining.
--- @throws If icons is not a table.
function khaoslib_recipe:set_icons(icons)
  if type(icons) ~= "table" then error("icons parameter: Expected table, got " .. type(icons), 2) end

  self.recipe.icon = nil
  self.recipe.icon_size = nil
  self.recipe.icons = util.table.deepcopy(icons)
  depopulate_icons(self.recipe)

  return self
end

--- Returns the number of icons for the given recipe.
--- @param recipe data.RecipeID|data.RecipePrototype|khaoslib.RecipeManipulator The recipe.
--- @return integer count The number of icons.
--- @nodiscard
function khaoslib_recipe.count_icons(recipe)
  local resolved_recipe = resolve(recipe)
  return resolved_recipe.icons ~= nil and #resolved_recipe.icons or (resolved_recipe.icon ~= nil and 1 or 0)
end

--- Checks if the recipe has an icon matching the given criteria.
--- Supports both string matching (by icon filename) and custom comparison functions.
---
--- ```lua
--- -- By name (string)
--- if recipe:has_icon("__mymod__/graphics/icons/water.png") then
---   -- Recipe uses water icon
--- end
---
--- -- By comparison function
--- if recipe:has_icon(function(icon)
---   return icon.icon_size == 64
--- end) then
---   -- Recipe uses 64x64 icons
--- end
--- ```
---
--- @param recipe data.RecipeID|data.RecipePrototype|khaoslib.RecipeManipulator The recipe.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @return boolean has_icon True if the recipe has the icon, false otherwise.
--- @throws If compare is not a string or function.
--- @nodiscard
function khaoslib_recipe.has_icon(recipe, compare)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  local resolved_recipe = resolve(recipe)
  populate_icons(resolved_recipe)

  local result = khaoslib_list.has(resolved_recipe.icons, compare_fn)
  depopulate_icons(resolved_recipe)

  return result
end

--- Adds an icon to the recipe, allows duplicates.
--- @param icon data.IconData The icon data to add.
--- @return khaoslib.RecipeManipulator self The same recipe manipulation object for method chaining.
--- @throws If icon is not a table or doesn't have required fields.
function khaoslib_recipe:add_icon(icon)
  if type(icon) ~= "table" then error("icon parameter: Expected table, got " .. type(icon), 2) end
  if not icon.icon or type(icon.icon) ~= "string" then error("icon parameter: Must have an icon field of type string", 2) end

  populate_icons(self.recipe)
  self.recipe.icons = khaoslib_list.add(self.recipe.icons, icon, nil, {allow_duplicates = true})
  depopulate_icons(self.recipe)

  return self
end

--- Removes matching icons from the recipe.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @param options ListRemoveOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, removes all matching icons instead of just the first.
--- @return khaoslib.RecipeManipulator self The same recipe manipulation object for method chaining.
--- @throws If compare is not a string or function.
function khaoslib_recipe:remove_icon(compare, options)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  populate_icons(self.recipe)
  self.recipe.icons = khaoslib_list.remove(self.recipe.icons, compare_fn, options)
  depopulate_icons(self.recipe)

  return self
end

--- Replaces matching icons with a new icon.
--- If no matching icons are found, no changes are made.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @param replacement (fun(icon: data.IconData): data.IconData)|data.IconData The new icon data to replace with.
--- @param options ListReplaceOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, replaces all matching icons instead of just the first.
--- @return khaoslib.RecipeManipulator self The same recipe manipulation object for method chaining.
--- @throws If compare is not a string or function, or replacement is not a table or function.
function khaoslib_recipe:replace_icon(compare, replacement, options)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  if type(replacement) ~= "table" and type(replacement) ~= "function" then error("replacement parameter: Expected table or function, got " .. type(replacement), 2) end
  if type(replacement) == "table" then
    if not replacement.icon or type(replacement.icon) ~= "string" then error("replacement parameter: Must have an icon field of type string", 2) end
  end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  populate_icons(self.recipe)
  self.recipe.icons = khaoslib_list.replace(self.recipe.icons, replacement, compare_fn, options)
  depopulate_icons(self.recipe)

  return self
end

--- Removes all icons from the recipe.
--- @return khaoslib.RecipeManipulator self The same recipe manipulation object for method chaining.
function khaoslib_recipe:clear_icons()
  self.recipe.icon = nil
  self.recipe.icon_size = nil
  self.recipe.icons = nil

  return self
end

--- Returns a deepcopy of all ingredients for the given recipe.
--- @param recipe data.RecipeID|data.RecipePrototype|khaoslib.RecipeManipulator The recipe.
--- @return data.IngredientPrototype[] ingredients A list of ingredients required by the recipe.
--- @nodiscard
function khaoslib_recipe.get_ingredients(recipe)
  return util.table.deepcopy(resolve(recipe).ingredients or {})
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

--- Returns the number of ingredients for the given recipe.
--- @param recipe data.RecipeID|data.RecipePrototype|khaoslib.RecipeManipulator The recipe.
--- @return integer count The number of ingredients.
--- @nodiscard
function khaoslib_recipe.count_ingredients(recipe)
  return #(resolve(recipe).ingredients or {})
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
--- @param recipe data.RecipeID|data.RecipePrototype|khaoslib.RecipeManipulator The recipe.
--- @param compare (fun(ingredient: data.IngredientPrototype): boolean)|data.ItemID|data.FluidID A comparison function or ingredient name to match.
--- @return boolean has_ingredient True if the recipe has the ingredient, false otherwise.
--- @throws If compare is not a string or function.
--- @nodiscard
function khaoslib_recipe.has_ingredient(recipe, compare)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.name == compare end
  end

  return khaoslib_list.has(resolve(recipe).ingredients, compare_fn)
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
--- @param compare (fun(ingredient: data.IngredientPrototype): boolean)|data.ItemID|data.FluidID A comparison function or ingredient name to match.
--- @param options ListRemoveOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, removes all matching ingredients instead of just the first.
--- @return khaoslib.RecipeManipulator self The same recipe manipulation object for method chaining.
--- @throws If compare is not a string or function.
function khaoslib_recipe:remove_ingredient(compare, options)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.name == compare end
  end

  self.recipe.ingredients = khaoslib_list.remove(self.recipe.ingredients, compare_fn, options)

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
--- @param compare (fun(ingredient: data.IngredientPrototype): boolean)|data.ItemID|data.FluidID A comparison function or ingredient name to match.
--- @param replacement (fun(ingredient: data.IngredientPrototype): data.IngredientPrototype)|data.IngredientPrototype The new ingredient prototype to replace with.
--- @param options ListReplaceOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, replaces all matching ingredients instead of just the first.
--- @return khaoslib.RecipeManipulator self The same recipe manipulation object for method chaining.
--- @throws If compare is not a string or function, or replacement is not a table or function.
function khaoslib_recipe:replace_ingredient(compare, replacement, options)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  if type(replacement) ~= "table" and type(replacement) ~= "function" then error("replacement parameter: Expected table or function, got " .. type(replacement), 2) end
  if type(replacement) == "table" then
    if not replacement.type or type(replacement.type) ~= "string" then error("replacement parameter: Must have a type field of type string", 2) end
    if not replacement.name or type(replacement.name) ~= "string" then error("replacement parameter: Must have a name field of type string", 2) end
    if not replacement.amount or type(replacement.amount) ~= "number" then error("replacement parameter: Must have an amount field of type number", 2) end
  end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.name == compare end
  end

  self.recipe.ingredients = khaoslib_list.replace(self.recipe.ingredients, replacement, compare_fn, options)

  return self
end

--- Removes all ingredients from the recipe (clears the ingredients list).
--- @return khaoslib.RecipeManipulator self The same recipe manipulation object for method chaining.
function khaoslib_recipe:clear_ingredients()
  self.recipe.ingredients = {}

  return self
end

--- Returns a deep copy of all results produced by the recipe.
--- @param recipe data.RecipeID|data.RecipePrototype|khaoslib.RecipeManipulator The recipe.
--- @return data.ProductPrototype[] results A list of results produced by the recipe.
--- @nodiscard
function khaoslib_recipe.get_results(recipe)
  return util.table.deepcopy(resolve(recipe).results or {})
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
--- @param recipe data.RecipeID|data.RecipePrototype|khaoslib.RecipeManipulator The recipe.
--- @param compare (fun(result: data.ProductPrototype): boolean)|data.ItemID|data.FluidID A comparison function or result name to match.
--- @return data.ProductPrototype[] matching_results A deep copied list of all matching results.
--- @throws If compare is not a string or function.
--- @nodiscard
function khaoslib_recipe.get_matching_results(recipe, compare)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.name == compare end
  end

  local matching_results = {}
  for _, result in ipairs(resolve(recipe).results) do
    if compare_fn(result) then
      table.insert(matching_results, util.table.deepcopy(result))
    end
  end

  return matching_results
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

--- Returns the number of different result types produced by the given recipe.
--- @param recipe data.RecipeID|data.RecipePrototype|khaoslib.RecipeManipulator The recipe.
--- @return integer count The number of result types.
--- @nodiscard
function khaoslib_recipe.count_results(recipe)
  return #(resolve(recipe).results or {})
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
--- @param recipe data.RecipeID|data.RecipePrototype|khaoslib.RecipeManipulator The recipe.
--- @param compare (fun(result: data.ProductPrototype): boolean)|data.ItemID|data.FluidID A comparison function or result name to match.
--- @return boolean has_result True if the recipe produces the result, false otherwise.
--- @throws If compare is not a string or function.
--- @nodiscard
function khaoslib_recipe.has_result(recipe, compare)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.name == compare end
  end

  return khaoslib_list.has(resolve(recipe).results, compare_fn)
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
--- @param recipe data.RecipeID|data.RecipePrototype|khaoslib.RecipeManipulator The recipe.
--- @param compare (fun(result: data.ProductPrototype): boolean)|data.ItemID|data.FluidID A comparison function or result name to match.
--- @return integer count The number of matching results.
--- @throws If compare is not a string or function.
--- @nodiscard
function khaoslib_recipe.count_matching_results(recipe, compare)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.name == compare end
  end

  local count = 0
  for _, result in ipairs(resolve(recipe).results) do
    if compare_fn(result) then
      count = count + 1
    end
  end

  return count
end

--- Adds a result to the recipe. Unlike ingredients, results can have duplicates in Factorio recipes.
--- @param result data.ProductPrototype The result prototype to add.
--- @return khaoslib.RecipeManipulator self The same recipe manipulation object for method chaining.
--- @throws If result is not a table or doesn't have required fields.
function khaoslib_recipe:add_result(result)
  if type(result) ~= "table" then error("result parameter: Expected table, got " .. type(result), 2) end
  if not result.type or type(result.type) ~= "string" then error("result parameter: Must have a type field of type string", 2) end
  if not result.name or type(result.name) ~= "string" then error("result parameter: Must have a name field of type string", 2) end

  self.recipe.results = khaoslib_list.add(self.recipe.results, result, nil, {allow_duplicates = true})

  return self
end

--- Removes matching results from the recipe.
---
--- ```lua
--- -- Remove by name (string parameter) - removes first match by default
--- khaoslib_recipe("electronic-circuit"):remove_result("copper-cable")
---
--- -- Remove with custom function (function parameter) - removes first match by default
--- khaoslib_recipe("electronic-circuit"):remove_result(function(result)
---   return result.name == "electronic-circuit" and (result.amount or 1) > 1
--- end)
---
--- -- Remove all matches
--- khaoslib_recipe("electronic-circuit"):remove_result("electronic-circuit", {all = true})
--- ```
---
--- @param compare (fun(result: data.ProductPrototype): boolean)|data.ItemID|data.FluidID A comparison function or result name to match.
--- @param options ListRemoveOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, removes all matching results instead of just the first.
--- @return khaoslib.RecipeManipulator self The same recipe manipulation object for method chaining.
--- @throws If compare is not a string or function.
function khaoslib_recipe:remove_result(compare, options)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.name == compare end
  end

  self.recipe.results = khaoslib_list.remove(self.recipe.results, compare_fn, options)

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
--- @param compare (fun(result: data.ProductPrototype): boolean)|data.ItemID|data.FluidID A comparison function or result name to match.
--- @param replacement (fun(result: data.ProductPrototype): data.ProductPrototype)|data.ProductPrototype The new result prototype to replace with.
--- @param options ListReplaceOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, replaces all matching results instead of just the first.
--- @return khaoslib.RecipeManipulator self The same recipe manipulation object for method chaining.
--- @throws If old_result is not a string or function, or replacement is not a table or function.
function khaoslib_recipe:replace_result(compare, replacement, options)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  if type(replacement) ~= "table" and type(replacement) ~= "function" then error("replacement parameter: Expected table or function, got " .. type(replacement), 2) end
  if type(replacement) == "table" then
    if not replacement.type or type(replacement.type) ~= "string" then error("replacement parameter: Must have a type field of type string", 2) end
    if not replacement.name or type(replacement.name) ~= "string" then error("replacement parameter: Must have a name field of type string", 2) end
    if not replacement.amount or type(replacement.amount) ~= "number" then error("replacement parameter: Must have an amount field of type number", 2) end
  end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.name == compare end
  end

  self.recipe.results = khaoslib_list.replace(self.recipe.results, replacement, compare_fn, options)

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

--#region Utility functions
-- Module-level utility functions for recipe discovery and analysis.

--- Checks if a recipe exists in the data stage.
--- @param name data.RecipeID The recipe name to check.
--- @return boolean exists True if the recipe exists, false otherwise.
--- @nodiscard
function khaoslib_recipe.exists(name)
  if type(name) ~= "string" then error("name parameter: Expected string, got " .. type(name), 2) end

  return data.raw.recipe[name] ~= nil
end

--- Finds all recipes that match a custom compare function.
--- @param compare_fn fun(recipe: data.RecipePrototype): boolean A function that returns true for recipes to include.
--- @return data.RecipeID[] recipes A list of recipe names that match the compare function.
--- @throws If compare_fn is not a function.
--- @nodiscard
function khaoslib_recipe.find(compare_fn)
  if type(compare_fn) ~= "function" then error("compare_fn parameter: Expected function, got " .. type(compare_fn), 2) end

  local result = {}
  for _, recipe in pairs(data.raw.recipe or {}) do
    if compare_fn(recipe) then
      table.insert(result, recipe.name)
    end
  end

  return result
end

--#endregion

return khaoslib_recipe
