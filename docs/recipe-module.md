# khaoslib Recipe Module Documentation

The recipe module provides a comprehensive API for manipulating Factorio recipe prototypes during the data stage. It offers a fluent interface with method chaining, robust error handling, and deep copying for data safety.

## Table of Contents

- [Quick Start](#quick-start)
- [Core Concepts](#core-concepts)
- [API Reference](#api-reference)
- [Common Patterns](#common-patterns)
- [Error Handling](#error-handling)
- [Performance Considerations](#performance-considerations)
- [Migration Guide](#migration-guide)

## Quick Start

```lua
local khaoslib_recipe = require("__khaoslib__.recipe")

-- Modify an existing recipe
khaoslib_recipe:load("iron-plate")
  :add_ingredient({type = "item", name = "carbon", amount = 1})
  :set({energy_required = 2.0})
  :commit()

-- Create a new recipe variant
khaoslib_recipe:load("electronic-circuit")
  :copy("advanced-circuit-with-gold-wire")
  :add_ingredient({type = "item", name = "gold-wire", amount = 2})
  :replace_result("electronic-circuit", {
    type = "item",
    name = "advanced-circuit",
    amount = 1,
  })
  :commit()
```

## Core Concepts

### Fluent API and Method Chaining

The recipe module uses a fluent interface that allows method chaining:

```lua
-- All these methods return self, enabling chaining
recipe:add_ingredient(ingredient)
  :remove_ingredient("old-ingredient")
  :set({energy_required = 5})
  :commit()
```

### Deep Copying and Data Safety

All operations use deep copying to prevent accidental modification of shared data:

```lua
local recipe1 = khaoslib_recipe:load("iron-plate")
local recipe2 = recipe1:copy("steel-plate") -- recipe1 is unchanged

-- Getting data always returns deep copies
local ingredients = recipe1:get_ingredients() -- safe to modify
```

### Ingredients vs Results

- **Ingredients**: Cannot have duplicates (Factorio requirement)
- **Results**: Can have duplicates, special handling functions provided

```lua
-- This prevents duplicates automatically
recipe:add_ingredient({type = "item", name = "iron-ore", amount = 5})
recipe:add_ingredient({type = "item", name = "iron-ore", amount = 10}) -- Ignored

-- This allows duplicates
recipe:add_result({type = "item", name = "byproduct", amount = 1})
recipe:add_result({type = "item", name = "byproduct", amount = 2}) -- Both added
```

### Options Tables

Many functions accept options tables for extensible configuration:

```lua
-- Remove all matching results
recipe:remove_result("byproduct", {all = true})

-- Replace all matching results
recipe:replace_result("old-item", new_item, {all = true})

-- Remove all matching ingredients
recipe:remove_ingredient(function(ingredient)
  return ingredient.type == "fluid"
end, {all = true})
```

## API Reference

### Core Methods

#### `khaoslib_recipe:load(recipe)`

Loads a recipe for manipulation or creates a new one.

**Parameters:**

- `recipe` (string|table): Recipe name or prototype table

**Returns:**

- `khaoslib.RecipeManipulator`: Manipulation object

**Examples:**

```lua
-- Load existing recipe
local recipe = khaoslib_recipe:load("iron-plate")

-- Create new recipe
local recipe = khaoslib_recipe:load({
  name = "my-recipe",
  category = "crafting",
  energy_required = 2.0,
  ingredients = {{type = "item", name = "iron-ore", amount = 1}},
  results = {{type = "item", name = "iron-plate", amount = 1}},
})
```

#### `recipe:get()`

Returns a deep copy of the recipe prototype.

```lua
local data = recipe:get()
-- data is safe to modify without affecting the original
```

#### `recipe:set(fields)`

Merges fields into the recipe.

```lua
recipe:set({
  energy_required = 5.0,
  category = "advanced-crafting",
  enabled = false,
})
```

#### `recipe:copy(new_name)`

Creates a deep copy with a new name.

```lua
local variant = recipe:copy("iron-plate-expensive")
```

#### `recipe:commit()`

Saves changes back to the data stage.

```lua
recipe:commit() -- Recipe is now available in data.raw.recipe
```

### Ingredient Methods

#### `recipe:get_ingredients()`

Returns deep copy of all ingredients.

```lua
local ingredients = recipe:get_ingredients()
for _, ingredient in ipairs(ingredients) do
  log("Ingredient: " .. ingredient.name .. " x" .. ingredient.amount)
end
```

#### `recipe:add_ingredient(ingredient)`

Adds ingredient if it doesn't exist (prevents duplicates).

```lua
recipe:add_ingredient({
  type = "item",
  name = "steel-plate",
  amount = 2,
})
```

#### `recipe:remove_ingredient(compare, options?)`

Removes matching ingredients.

```lua
-- By name (string) - removes first match by default
recipe:remove_ingredient("iron-ore")

-- By comparison function - removes first match by default
recipe:remove_ingredient(function(ingredient)
  return ingredient.amount > 10
end)

-- Remove all matching ingredients
recipe:remove_ingredient(function(ingredient)
  return ingredient.type == "fluid"
end, {all = true})
```

#### `recipe:replace_ingredient(old, new, options?)`

Replaces matching ingredients.

```lua
-- Replace first matching ingredient by default
recipe:replace_ingredient("iron-ore", {
  type = "item",
  name = "iron-plate",
  amount = 1
})

-- Replace all matching ingredients
recipe:replace_ingredient(function(ingredient)
  return ingredient.type == "fluid"
end, {
  type = "fluid",
  name = "water",
  amount = 10
}, {all = true})
```

#### `recipe:has_ingredient(compare)`

Checks if ingredient exists.

```lua
-- By name (string)
if recipe:has_ingredient("water") then
  -- Recipe uses water
end

-- By comparison function
if recipe:has_ingredient(function(ingredient)
  return ingredient.type == "fluid" and ingredient.amount > 100
end) then
  -- Recipe uses lots of fluid
end
```

### Result Methods

#### `recipe:get_results()`

Returns deep copy of all results.

#### `recipe:add_result(result)`

Adds result (duplicates allowed).

```lua
recipe:add_result({
  type = "item",
  name = "byproduct",
  amount = 1,
  probability = 0.1,
})
```

#### `recipe:remove_result(compare, options?)`

Removes matching results.

```lua
-- Remove first match by name (string) - default behavior
recipe:remove_result("unwanted-byproduct")

-- Remove all matches by name
recipe:remove_result("byproduct", {all = true})

-- Remove by comparison function - first match by default
recipe:remove_result(function(result)
  return result.probability and result.probability < 0.05
end)

-- Remove all matches by comparison function
recipe:remove_result(function(result)
  return result.probability and result.probability < 0.05
end, {all = true})
```

#### `recipe:replace_result(old, new, options?)`

Replaces matching results.

```lua
-- Replace first match by default
recipe:replace_result("iron-plate", {
  type = "item",
  name = "steel-plate",
  amount = 1,
})

-- Replace all matches
recipe:replace_result("byproduct", new_result, {all = true})

-- Replace all matches with comparison function
recipe:replace_result(function(result)
  return result.probability and result.probability < 0.1
end, {
  type = "item",
  name = "rare-metal",
  amount = 1,
  probability = 0.05
}, {all = true})
```

#### `recipe:count_matching_results(compare)`

Counts matching results (useful for duplicates).

```lua
-- Count by name (string)
local byproduct_count = recipe:count_matching_results("byproduct")
log("Recipe has " .. byproduct_count .. " byproduct results")

-- Count by comparison function
local rare_count = recipe:count_matching_results(function(result)
  return result.probability and result.probability < 0.1
end)
```

#### `recipe:get_matching_results(compare)`

Gets all matching results.

```lua
-- Get by name (string)
local byproducts = recipe:get_matching_results("byproduct")

-- Get by comparison function
local rare_results = recipe:get_matching_results(function(result)
  return result.probability and result.probability < 0.1
end)
```

## Common Patterns

### Recipe Modifications

```lua
-- Make recipe more expensive
khaoslib_recipe:load("electronic-circuit")
  :set({energy_required = (data.raw.recipe["electronic-circuit"].energy_required or 0.5) * 2})
  :commit()

-- Add alternative ingredients
local recipe = khaoslib_recipe:load("steel-plate")
if recipe:has_ingredient("iron-ore") then
  recipe:remove_ingredient("iron-ore")
    :add_ingredient({type = "item", name = "iron-plate", amount = 1})
    :add_ingredient({type = "item", name = "coal", amount = 1})
    :commit()
end
```

### Batch Operations

```lua
-- Modify multiple related recipes
local circuit_recipes = {"electronic-circuit", "advanced-circuit", "processing-unit"}
for _, recipe_name in ipairs(circuit_recipes) do
  if data.raw.recipe[recipe_name] then
    khaoslib_recipe:load(recipe_name)
      :set({enabled = false}) -- Require research
      :commit()
  end
end
```

### Recipe Variants

```lua
-- Create expensive variants
local base_recipes = {"iron-plate", "copper-plate", "steel-plate"}
for _, recipe_name in ipairs(base_recipes) do
  if data.raw.recipe[recipe_name] then
    khaoslib_recipe:load(recipe_name)
      :copy(recipe_name .. "-expensive")
      :set({
        energy_required = (data.raw.recipe[recipe_name].energy_required or 0.5) * 2,
        enabled = false,
      })
      :commit()
  end
end
```

### Complex Result Management

```lua
-- Remove low-probability byproducts from all recipes
for recipe_name, recipe_data in pairs(data.raw.recipe) do
  local recipe = khaoslib_recipe:load(recipe_name)

  -- Remove all results with probability < 5%
  recipe:remove_result(function(result)
    return result.probability and result.probability < 0.05
  end, {all = true})

  -- Only commit if we actually have results left
  if recipe:count_results() > 0 then
    recipe:commit()
  else
    recipe:remove() -- Delete recipes with no results
  end
end

-- Replace all fluid ingredients with water in specific recipes
local water_recipes = {"concrete", "sulfuric-acid", "battery"}
for _, recipe_name in ipairs(water_recipes) do
  if data.raw.recipe[recipe_name] then
    khaoslib_recipe:load(recipe_name)
      :replace_ingredient(function(ingredient)
        return ingredient.type == "fluid"
      end, {
        type = "fluid",
        name = "water",
        amount = 10
      }, {all = true})
      :commit()
  end
end
```

## Error Handling

The module provides comprehensive error checking with descriptive messages:

```lua
-- This will throw an error with a clear message
try {
  khaoslib_recipe:load("nonexistent-recipe")
} catch {
  -- Error: "No such recipe: nonexistent-recipe"
}

-- Invalid ingredient structure
try {
  recipe:add_ingredient({name = "iron-ore"}) -- Missing type and amount
} catch {
  -- Error: "ingredient parameter: Must have a type field of type string"
}
```

### Common Error Scenarios

1. **Recipe doesn't exist**: Check `data.raw.recipe[name]` first
2. **Invalid prototype structure**: Ensure required fields (type, name, amount)
3. **Duplicate recipe names**: Use unique names when creating new recipes
4. **Missing commits**: Changes aren't saved until `commit()` is called

### Safe Programming Patterns

```lua
-- Always check if recipe exists
if data.raw.recipe["my-recipe"] then
  local recipe = khaoslib_recipe:load("my-recipe")
  -- ... manipulate recipe
  recipe:commit()
end

-- Validate before creating new recipes
local new_name = "custom-recipe"
if not data.raw.recipe[new_name] then
  khaoslib_recipe:load({
    name = new_name,
    -- ... recipe definition
  }):commit()
end
```

## Performance Considerations

### Efficient Patterns

```lua
-- Good: Chain operations before committing
recipe:add_ingredient(ingredient1)
  :add_ingredient(ingredient2)
  :set({energy_required = 5})
  :commit() -- Single commit

-- Avoid: Multiple commits
recipe:add_ingredient(ingredient1):commit()
recipe:add_ingredient(ingredient2):commit() -- Less efficient
```

### Memory Usage

- Deep copying ensures safety but uses more memory
- Use `has_ingredient()` / `has_result()` to avoid unnecessary operations
- Consider bulk operations for large-scale modifications

### Large-Scale Modifications

```lua
-- Efficient bulk processing
local modifications = {}
for recipe_name, recipe_data in pairs(data.raw.recipe) do
  if recipe_data.category == "crafting" then
    modifications[recipe_name] = function()
      return khaoslib_recipe:load(recipe_name)
        :set({energy_required = recipe_data.energy_required * 1.5})
    end
  end
end

-- Apply all modifications
for recipe_name, modify_fn in pairs(modifications) do
  modify_fn():commit()
end
```

## Migration Guide

### From Raw data.raw Manipulation

```lua
-- Old way (error-prone)
local recipe = data.raw.recipe["iron-plate"]
recipe.energy_required = 2.0
table.insert(recipe.ingredients, {type = "item", name = "coal", amount = 1})

-- New way (safe and fluent)
khaoslib_recipe:load("iron-plate")
  :set({energy_required = 2.0})
  :add_ingredient({type = "item", name = "coal", amount = 1})
  :commit()
```

### From Custom Recipe Functions

```lua
-- Old custom function
function modify_recipe(recipe_name, changes)
  local recipe = data.raw.recipe[recipe_name]
  if recipe then
    for key, value in pairs(changes) do
      recipe[key] = value
    end
  end
end

-- New khaoslib approach
function modify_recipe(recipe_name, changes)
  if data.raw.recipe[recipe_name] then
    khaoslib_recipe:load(recipe_name):set(changes):commit()
  end
end
```

## Best Practices

1. **Always validate inputs**: Check recipe existence before loading
2. **Use method chaining**: More readable and efficient
3. **Commit strategically**: Group related changes before committing
4. **Handle errors gracefully**: Wrap operations in appropriate checks
5. **Document complex operations**: Use comments for non-obvious manipulations
6. **Test thoroughly**: Verify recipes work in-game after modifications

## Examples Repository

For more examples and real-world usage patterns, see the [khaoslib examples repository](https://github.com/QuingKhaos/khaoslib-examples) (if available).
