-- Test file for khaoslib recipe module
package.path = package.path .. ";tests/?.lua"
local luaunit = require('luaunit')
local test_utils = require('test_utils')

local khaoslib_recipe = test_utils.load_module('recipe')

-- Test suite
TestRecipeModule = {}

function TestRecipeModule:setUp()
  -- Reset data for each test
  data.raw.recipe = {}
  data.raw.technology = {}
end

function TestRecipeModule:test_load_existing_recipe()
  -- Setup
  data.raw.recipe["test-recipe"] = {
    type = "recipe",
    name = "test-recipe",
    ingredients = {{type = "item", name = "iron-ore", amount = 1}},
    results = {{type = "item", name = "iron-plate", amount = 1}}
  }

  -- Test
  local recipe = khaoslib_recipe:load("test-recipe")

  -- Assert
  luaunit.assertEquals(recipe.recipe.name, "test-recipe")
  luaunit.assertEquals(#recipe.recipe.ingredients, 1)
  luaunit.assertEquals(recipe.recipe.ingredients[1].name, "iron-ore")
end

function TestRecipeModule:test_load_nonexistent_recipe_throws_error()
  -- Test that loading a non-existent recipe throws an error
  luaunit.assertErrorMsgContains("No such recipe: nonexistent", function()
    khaoslib_recipe:load("nonexistent")
  end)
end

function TestRecipeModule:test_create_new_recipe()
  -- Test creating a new recipe from prototype table
  local recipe_data = {
    name = "new-recipe",
    category = "crafting",
    energy_required = 2.0,
    ingredients = {{type = "item", name = "iron-ore", amount = 2}},
    results = {{type = "item", name = "iron-plate", amount = 1}}
  }

  local recipe = khaoslib_recipe:load(recipe_data)

  luaunit.assertEquals(recipe.recipe.name, "new-recipe")
  luaunit.assertEquals(recipe.recipe.type, "recipe")
  luaunit.assertEquals(recipe.recipe.energy_required, 2.0)
end

function TestRecipeModule:test_add_ingredient()
  -- Setup
  data.raw.recipe["test-recipe"] = {
    type = "recipe",
    name = "test-recipe",
    ingredients = {},
    results = {{type = "item", name = "iron-plate", amount = 1}}
  }

  local recipe = khaoslib_recipe:load("test-recipe")

  -- Test
  recipe:add_ingredient({type = "item", name = "iron-ore", amount = 1})

  -- Assert
  luaunit.assertEquals(#recipe.recipe.ingredients, 1)
  luaunit.assertEquals(recipe.recipe.ingredients[1].name, "iron-ore")
  luaunit.assertEquals(recipe.recipe.ingredients[1].amount, 1)
end

function TestRecipeModule:test_add_duplicate_ingredient_ignored()
  -- Setup
  data.raw.recipe["test-recipe"] = {
    type = "recipe",
    name = "test-recipe",
    ingredients = {{type = "item", name = "iron-ore", amount = 1}},
    results = {{type = "item", name = "iron-plate", amount = 1}}
  }

  local recipe = khaoslib_recipe:load("test-recipe")

  -- Test - try to add duplicate ingredient
  recipe:add_ingredient({type = "item", name = "iron-ore", amount = 2})

  -- Assert - should still only have 1 ingredient
  luaunit.assertEquals(#recipe.recipe.ingredients, 1)
  luaunit.assertEquals(recipe.recipe.ingredients[1].amount, 1) -- Original amount preserved
end

function TestRecipeModule:test_add_unlock_integration()
  -- Setup
  data.raw.recipe["test-recipe"] = {
    type = "recipe",
    name = "test-recipe",
    ingredients = {},
    results = {}
  }
  data.raw.technology["test-tech"] = {
    type = "technology",
    name = "test-tech",
    effects = {}
  }

  local recipe = khaoslib_recipe:load("test-recipe")

  -- Test
  recipe:add_unlock("test-tech")

  -- Assert that the technology was tracked
  luaunit.assertNotNil(recipe.modified_technologies["test-tech"])
end

function TestRecipeModule:test_remove_unlock_integration()
  -- Setup
  data.raw.recipe["test-recipe"] = {
    type = "recipe",
    name = "test-recipe",
    ingredients = {},
    results = {}
  }
  data.raw.technology["test-tech"] = {
    type = "technology",
    name = "test-tech",
    effects = {{type = "unlock-recipe", recipe = "test-recipe"}}
  }

  local recipe = khaoslib_recipe:load("test-recipe")

  -- Test
  recipe:remove_unlock("test-tech")

  -- Assert that the technology was tracked
  luaunit.assertNotNil(recipe.modified_technologies["test-tech"])
end

function TestRecipeModule:test_method_chaining()
  -- Setup
  data.raw.recipe["test-recipe"] = {
    type = "recipe",
    name = "test-recipe",
    ingredients = {},
    results = {}
  }
  data.raw.technology["test-tech"] = {
    type = "technology",
    name = "test-tech",
    effects = {}
  }

  -- Test method chaining
  local recipe = khaoslib_recipe:load("test-recipe")
    :add_ingredient({type = "item", name = "iron-ore", amount = 1})
    :add_result({type = "item", name = "iron-plate", amount = 1})
    :add_unlock("test-tech")
    :set({energy_required = 2.0})

  -- Assert
  luaunit.assertEquals(#recipe.recipe.ingredients, 1)
  luaunit.assertEquals(#recipe.recipe.results, 1)
  luaunit.assertEquals(recipe.recipe.energy_required, 2.0)
  luaunit.assertNotNil(recipe.modified_technologies["test-tech"])
end

function TestRecipeModule:test_copy_recipe()
  -- Setup
  data.raw.recipe["original-recipe"] = {
    type = "recipe",
    name = "original-recipe",
    ingredients = {{type = "item", name = "iron-ore", amount = 1}},
    results = {{type = "item", name = "iron-plate", amount = 1}},
    energy_required = 1.0
  }

  local original = khaoslib_recipe:load("original-recipe")

  -- Test
  local copy = original:copy("copied-recipe")

  -- Assert
  luaunit.assertEquals(copy.recipe.name, "copied-recipe")
  luaunit.assertEquals(copy.recipe.energy_required, 1.0)
  luaunit.assertEquals(#copy.recipe.ingredients, 1)
  luaunit.assertEquals(copy.recipe.ingredients[1].name, "iron-ore")
end

-- Run the tests
os.exit(luaunit.LuaUnit.run())