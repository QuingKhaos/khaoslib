# Technology Module Documentation

The Technology Module provides a comprehensive, fluent API for manipulating Factorio technology prototypes during the
data stage. It supports method chaining, deep copying for data safety, and robust error handling.

## Table of Contents

- [Overview](#overview)
- [Usage](#usage)
- [Basic Usage](#basic-usage)
- [API Reference](#api-reference)
  - [Loading Technologies](#loading-technologies)
  - [Basic Operations](#basic-operations)
  - [Prerequisite Management](#prerequisite-management)
  - [Effect Management](#effect-management)
  - [Unlock Recipe Helpers](#unlock-recipe-helpers)
  - [Science Pack Management](#science-pack-management)
  - [Utility Functions](#utility-functions)
- [Advanced Examples](#advanced-examples)
- [Best Practices](#best-practices)
- [Error Handling](#error-handling)

## Overview

The Technology Module enables you to:

- **Load and modify existing technologies** with a fluent API
- **Create new technologies** from prototype tables
- **Manage prerequisites** with duplicate prevention
- **Manipulate effects** including specialized unlock-recipe helpers
- **Control science pack costs** with full manipulation support
- **Discover technologies** using custom filter functions
- **Ensure data safety** with automatic deep copying

## Usage

```lua
local khaoslib_technology = require("__khaoslib__.technology")

```

## Basic Usage

### Loading and Modifying Technologies

```lua
-- Load an existing technology and modify it
khaoslib_technology:load("electronics")
  :add_prerequisite("basic-tech")
  :add_unlock_recipe("advanced-circuit")
  :set({unit = {count = 150, time = 30, ingredients = {
      {"automation-science-pack", 1},
      {"logistic-science-pack", 1},
    }}})
  :commit()

```

### Creating New Technologies

```lua
-- Create a new technology from scratch
khaoslib_technology:load({
  name = "advanced-electronics",
  icon = "__mymod__/graphics/technology/advanced-electronics.png",
  prerequisites = {"electronics", "steel-processing"},
  effects = {
    {type = "unlock-recipe", recipe = "advanced-circuit"}
  },
  unit = {
    count = 200,
    time = 45,
    ingredients = {
      {"automation-science-pack", 1},
      {"logistic-science-pack", 1}
    }
  }
}):commit()

```

### Copying Technologies

```lua
-- Create a variant of an existing technology
khaoslib_technology:load("electronics")
  :copy("electronics-advanced")
  :set({unit = {count = 300, time = 60, ingredients = {
      {"automation-science-pack", 1},
      {"logistic-science-pack", 1},
    }}})
  :add_unlock_recipe("advanced-electronic-circuit")
  :commit()

```

### Common Modding Scenarios

#### Moving Recipes Between Technologies

```lua
-- Move a recipe from one technology to another
-- Check raw data first to avoid unnecessary deep copy
local automation_tech = data.raw.technology["automation"]
local has_inserter = false
if automation_tech and automation_tech.effects then
  for _, effect in ipairs(automation_tech.effects) do
    if effect.type == "unlock-recipe" and effect.recipe == "inserter" then
      has_inserter = true
      break
    end
  end
end

if has_inserter then
  khaoslib_technology:load("automation")
    :remove_unlock_recipe("inserter")
    :commit()

  khaoslib_technology:load("logistics")
    :add_unlock_recipe("inserter")
    :commit()
end
```

#### Balancing Technology Costs

```lua
-- Rebalance expensive technologies
local expensive_techs = khaoslib_technology.find(function(tech)
  return tech.unit and tech.unit.count and tech.unit.count > 1000
end)

for _, tech_name in ipairs(expensive_techs) do
  local tech_data = data.raw.technology[tech_name]  -- Direct access, no deep copy
  local current_cost = tech_data.unit.count
  khaoslib_technology:load(tech_name)
    :set({
      unit = {
        count = math.floor(current_cost * 0.8),  -- 20% cost reduction
        time = 45
      }
    })
    :commit()
end
```

#### Adding Mod Integration

```lua
-- Add compatibility with popular mods
if mods["Krastorio2"] then
  khaoslib_technology:load("my-advanced-tech")
    :add_prerequisite("kr-advanced-tech")
    :add_unlock_recipe("kr-compatible-recipe")
    :commit()
end

if mods["space-exploration"] then
  khaoslib_technology:load("my-space-tech")
    :set_prerequisites({"se-space-science-pack"})
    :set({
      unit = {
        ingredients = {
          {"automation-science-pack", 1},
          {"logistic-science-pack", 1},
          {"se-rocket-science-pack", 1}
        }
      }
    })
    :commit()
end
```

## API Reference

### Loading Technologies

#### `khaoslib_technology:load(technology)`

Loads a technology for manipulation or creates a new one.

**Parameters:**

- `technology` (string|table): Technology name or prototype table

**Returns:**

- `TechnologyManipulator`: Object for chaining operations

**Examples:**

```lua
-- Load existing technology
local tech = khaoslib_technology:load("electronics")

-- Create new technology
local tech = khaoslib_technology:load({
  name = "my-tech",
  prerequisites = {"basic-tech"},
  effects = {{type = "unlock-recipe", recipe = "my-recipe"}}
})

```

### Basic Operations

#### `tech:get()`

Gets a deep copy of the technology prototype.

**Returns:**

- `TechnologyPrototype`: Deep copy of the technology data

#### `tech:set(fields)`

Merges fields into the technology.

**Parameters:**

- `fields` (table): Fields to merge (cannot include name or type)

**Returns:**

- `TechnologyManipulator`: Self for chaining

#### `tech:copy(new_name)`

Creates a copy with a different name.

**Parameters:**

- `new_name` (string): Name for the new technology

**Returns:**

- `TechnologyManipulator`: New manipulator for the copy

#### `tech:commit()`

Commits changes to the data stage.

**Returns:**

- `TechnologyManipulator`: Self for chaining

#### `tech:remove()`

Removes the technology from the data stage.

**Returns:**

- `TechnologyManipulator`: Self for chaining

### Prerequisite Management

#### `tech:get_prerequisites()`

Gets all prerequisite technology names.

**Returns:**

- `string[]`: Array of prerequisite names

#### `tech:set_prerequisites(prerequisites)`

Sets the prerequisite list, replacing existing ones.

**Parameters:**

- `prerequisites` (string[]): Array of prerequisite names

#### `tech:count_prerequisites()`

Gets the number of prerequisites.

**Returns:**

- `number`: Count of prerequisites

#### `tech:has_prerequisite(compare)`

Checks if technology has a matching prerequisite.

**Parameters:**

- `compare` (string|function): Name or comparison function

**Returns:**

- `boolean`: True if prerequisite exists

**Examples:**

```lua
-- Check by name
if tech:has_prerequisite("electronics") then
  -- Has electronics prerequisite
end

-- Check with function
if tech:has_prerequisite(function(prereq)
  return prereq:match("^advanced%-")
end) then
  -- Has advanced prerequisites
end
```

#### `tech:add_prerequisite(prerequisite)`

Adds a prerequisite if it doesn't already exist.

**Parameters:**

- `prerequisite` (string): Prerequisite name to add

#### `tech:remove_prerequisite(compare, options?)`

Removes matching prerequisites.

**Parameters:**

- `compare` (string|function): Name or comparison function

- `options` (table, optional): Options with `all` field

**Examples:**

```lua
-- Remove single prerequisite
tech:remove_prerequisite("old-tech")

-- Remove all matching prerequisites
tech:remove_prerequisite(function(prereq)
  return prereq:match("^deprecated%-")
end, {all = true})

```

#### `tech:replace_prerequisite(old_prerequisite, new_prerequisite, options?)`

Replaces matching prerequisites.

**Parameters:**

- `old_prerequisite` (string|function): Name or comparison function

- `new_prerequisite` (string): New prerequisite name

- `options` (table, optional): Options with `all` field

#### `tech:clear_prerequisites()`

Removes all prerequisites.

### Effect Management

#### `tech:get_effects()`

Gets all effects granted by the technology.

**Returns:**

- `Modifier[]`: Array of effect objects

#### `tech:set_effects(effects)`

Sets the effect list, replacing existing ones.

**Parameters:**

- `effects` (Modifier[]): Array of effect objects

#### `tech:count_effects()`

Gets the number of effects.

**Returns:**

- `number`: Count of effects

#### `tech:has_effect(compare_fn)`

Checks if technology has a matching effect.

**Parameters:**

- `compare_fn` (function): Comparison function

**Returns:**

- `boolean`: True if effect exists

#### `tech:add_effect(effect)`

Adds an effect to the technology.

**Parameters:**

- `effect` (Modifier): Effect object to add

#### `tech:remove_effect(compare_fn, options?)`

Removes matching effects.

**Parameters:**

- `compare_fn` (function): Comparison function

- `options` (table, optional): Options with `all` field

#### `tech:replace_effect(compare_fn, new_effect, options?)`

Replaces matching effects.

**Parameters:**

- `compare_fn` (function): Comparison function

- `new_effect` (Modifier): New effect object

- `options` (table, optional): Options with `all` field

#### `tech:clear_effects()`

Removes all effects.

### Unlock Recipe Helpers

#### `tech:get_unlock_recipes()`

Gets all recipe names unlocked by this technology.

**Returns:**

- `string[]`: Array of recipe names

#### `tech:count_unlock_recipes()`

Gets the number of unlock-recipe effects.

**Returns:**

- `number`: Count of unlock-recipe effects

#### `tech:has_unlock_recipe(recipe)`

Checks if technology unlocks a specific recipe.

**Parameters:**

- `recipe` (string): Recipe name to check

**Returns:**

- `boolean`: True if recipe is unlocked

#### `tech:add_unlock_recipe(recipe, modifier?)`

Adds an unlock-recipe effect.

**Parameters:**

- `recipe` (string): Recipe name to unlock

- `modifier` (table, optional): Additional modifier fields

#### `tech:remove_unlock_recipe(recipe, options?)`

Removes unlock-recipe effects for a recipe.

**Parameters:**

- `recipe` (string): Recipe name to remove

- `options` (table, optional): Options with `all` field

#### `tech:replace_unlock_recipe(old_recipe, new_recipe, options?)`

Replaces unlock-recipe effects.

**Parameters:**

- `old_recipe` (string): Recipe name to replace

- `new_recipe` (string): New recipe name

- `options` (table, optional): Options with `all` field

### Science Pack Management

Science packs define the research cost of technologies (what science packs and amounts are needed). These methods
provide complete control over technology research costs, similar to recipe ingredient management.

#### `tech:get_science_packs()`

Gets all science packs for the technology.

**Returns:**

- `ResearchIngredient[]`: Deep copy of the science pack list

**Examples:**

```lua
local tech = khaoslib_technology:load("electronics")
local science_packs = tech:get_science_packs()
for _, science_pack in ipairs(science_packs) do
  log("Requires: " .. science_pack[1] .. " x" .. science_pack[2])
end
```

#### `tech:set_science_packs(science_packs)`

Sets the science pack list, replacing existing ones.

**Parameters:**

- `science_packs` (ResearchIngredient[]): Array of science packs

**Examples:**

```lua
tech:set_science_packs({
  {"automation-science-pack", 1},
  {"logistic-science-pack", 1}
})
```

#### `tech:count_science_packs()`

Gets the number of science packs.

**Returns:**

- `number`: Count of science packs

#### `tech:has_science_pack(compare)`

Checks if technology has a matching science pack.

**Parameters:**

- `compare` (string|function): Science pack name or comparison function

**Returns:**

- `boolean`: True if science pack exists

**Examples:**

```lua
-- By name
if tech:has_science_pack("automation-science-pack") then
  -- Technology requires automation science
end

-- By comparison function
if tech:has_science_pack(function(science_pack)
  return science_pack[2] > 2
end) then
  -- Technology has expensive science packs
end
```

#### `tech:add_science_pack(science_pack)`

Adds a science pack if it doesn't already exist (prevents duplicates).

**Parameters:**

- `science_pack` (ResearchIngredient): Science pack to add

**Examples:**

```lua
tech:add_science_pack({"chemical-science-pack", 1})
```

#### `tech:remove_science_pack(compare, options?)`

Removes matching science packs.

**Parameters:**

- `compare` (string|function): Science pack name or comparison function
- `options` (table, optional): Options with `all` field

**Examples:**

```lua
-- Remove by name (first match by default)
tech:remove_science_pack("military-science-pack")

-- Remove by function (first match by default)
tech:remove_science_pack(function(science_pack)
  return science_pack[2] > 3
end)

-- Remove all matching science packs
tech:remove_science_pack(function(science_pack)
  return science_pack[1]:match("%-science%-pack$")
end, {all = true})
```

#### `tech:replace_science_pack(old_science_pack, new_science_pack, options?)`

Replaces matching science packs with a new science pack.

**Parameters:**

- `old_science_pack` (string|function): Science pack name or comparison function
- `new_science_pack` (ResearchIngredient): New science pack to replace with
- `options` (table, optional): Options with `all` field

**Examples:**

```lua
-- Replace by name (first match by default)
tech:replace_science_pack("automation-science-pack", {"automation-science-pack", 2})  -- Double the cost

-- Replace with function (first match by default)
tech:replace_science_pack(function(science_pack)
  return science_pack[2] == 1
end, {"universal-science-pack", 1})

-- Replace all matching science packs
tech:replace_science_pack(function(science_pack)
  return science_pack[1]:match("^basic%-")
end, {"advanced-science-pack", 1}, {all = true})
```

#### `tech:clear_science_packs()`

Removes all science packs from the technology.

**Examples:**

```lua
tech:clear_science_packs() -- Technology now costs nothing
```

### Utility Functions

#### `khaoslib_technology.exists(technology_name)`

Checks if a technology exists in the data stage.

**Parameters:**

- `technology_name` (string): Technology name to check

**Returns:**

- `boolean`: True if technology exists

#### `khaoslib_technology.find(filter_fn)`

Finds all technologies matching a filter function.

**Parameters:**

- `filter_fn` (function): Function that takes a TechnologyPrototype and returns boolean

**Returns:**

- `string[]`: Array of matching technology names

**Examples:**

```lua
-- Find military technologies
local military_techs = khaoslib_technology.find(function(tech)
  return tech.name:match("^military%-")
end)

-- Find technologies with many prerequisites
local complex_techs = khaoslib_technology.find(function(tech)
  return tech.prerequisites and #tech.prerequisites > 5
end)

```

## Advanced Examples

### Creating Technology Chains

```lua
-- Create a progressive technology chain for advanced materials
local base_tech = khaoslib_technology:load({
  name = "advanced-materials-1",
  icon = "__mymod__/graphics/technology/advanced-materials-1.png",
  prerequisites = {"steel-processing", "plastics"},
  effects = {
    {type = "unlock-recipe", recipe = "carbon-fiber"},
    {type = "unlock-recipe", recipe = "composite-plate"}
  },
  unit = {
    count = 100,
    time = 30,
    ingredients = {
      {"automation-science-pack", 1},
      {"logistic-science-pack", 1}
    }
  }
}):commit()

-- Create the next tier that depends on the first
khaoslib_technology:load({
  name = "advanced-materials-2",
  icon = "__mymod__/graphics/technology/advanced-materials-2.png",
  prerequisites = {"advanced-materials-1", "chemical-science-pack"},
  effects = {
    {type = "unlock-recipe", recipe = "nano-composite"},
    {type = "unlock-recipe", recipe = "reinforced-plate"}
  },
  unit = {
    count = 200,
    time = 45,
    ingredients = {
      {"automation-science-pack", 1},
      {"logistic-science-pack", 1},
      {"chemical-science-pack", 1}
    }
  }
}):commit()
```

### Mod Compatibility and Integration

```lua
-- Integrate with other mods by checking for their technologies
if khaoslib_technology.exists("kr-advanced-tech") then
  -- Krastorio 2 is present, integrate with their tech tree
  khaoslib_technology:load("my-advanced-tech")
    :add_prerequisite("kr-advanced-tech")
    :set({
      unit = {
        count = 500,  -- Make it more expensive with K2
        time = 60,
        ingredients = {
          {"automation-science-pack", 1},
          {"logistic-science-pack", 1},
          {"chemical-science-pack", 1},
          {"production-science-pack", 1}
        }
      }
    })
    :commit()
else
  -- Vanilla game, use simpler prerequisites
  khaoslib_technology:load("my-advanced-tech")
    :set_prerequisites({"advanced-electronics", "plastics"})
    :commit()
end
```

### Recipe Gating and Progression Control

```lua
-- Move expensive recipes to later in the tech tree
local expensive_recipes = {"rocket-fuel", "low-density-structure", "processing-unit"}

for _, recipe_name in ipairs(expensive_recipes) do
  -- Find all technologies that currently unlock this recipe
  local techs_with_recipe = khaoslib_technology.find(function(tech)
    if not tech.effects then return false end
    for _, effect in ipairs(tech.effects) do
      if effect.type == "unlock-recipe" and effect.recipe == recipe_name then
        return true
      end
    end
    return false
  end)

  -- Remove from early technologies
  for _, tech_name in ipairs(techs_with_recipe) do
    if tech_name:match("^basic%-") or tech_name:match("^early%-") then
      khaoslib_technology:load(tech_name)
        :remove_unlock_recipe(recipe_name)
        :commit()
    end
  end

  -- Add to appropriate late-game technology
  if khaoslib_technology.exists("rocket-silo") then
    khaoslib_technology:load("rocket-silo")
      :add_unlock_recipe(recipe_name)
      :commit()
  end
end
```

### Complex Prerequisite Manipulation

```lua
-- Remove military prerequisites except science packs for peaceful gameplay
local tech = khaoslib_technology:load("example-tech")
tech:remove_prerequisite(function(prereq)
  return prereq:match("^military%-") and not prereq:match("%-science%-")
end, {all = true})
  :add_prerequisite("peaceful-research")
  :commit()

-- Rebalance technology dependencies for difficulty mods
local high_tier_techs = khaoslib_technology.find(function(tech)
  return tech.prerequisites and #tech.prerequisites > 3
end)

for _, tech_name in ipairs(high_tier_techs) do
  khaoslib_technology:load(tech_name)
    :add_prerequisite("advanced-research-methodology")
    :set({
      unit = {
        count_formula = "2^(L-6)*1000",  -- Exponential scaling
        time = 60
      }
    })
    :commit()
end
```

### science pack Management and Rebalancing

```lua
-- Rebalance science pack costs for difficulty mods
local expensive_techs = khaoslib_technology.find(function(tech)
  return tech.unit and tech.unit.count and tech.unit.count > 1000
end)

for _, tech_name in ipairs(expensive_techs) do
  local tech = khaoslib_technology:load(tech_name)

  -- Double the cost of expensive science packs (requires manual iteration)
  local science_packs_to_replace = {}
  for _, science_pack in ipairs(tech:get_science_packs()) do
    if science_pack[2] >= 2 then
      table.insert(science_packs_to_replace, {
        old = science_pack[1],
        new = {science_pack[1], science_pack[2] * 2}
      })
    end
  end

  for _, replacement in ipairs(science_packs_to_replace) do
    tech:replace_science_pack(replacement.old, replacement.new)
  end

  -- Add premium science requirement for very expensive techs
  local tech_data = tech:get()
  if tech_data.unit and tech_data.unit.count and tech_data.unit.count > 5000 then
    tech:add_science_pack({"space-science-pack", 1})
  end

  tech:commit()
end

-- Standardize early game science costs
local early_techs = khaoslib_technology.find(function(tech)
  return tech.unit and tech.unit.count and tech.unit.count <= 50
end)

for _, tech_name in ipairs(early_techs) do
  khaoslib_technology:load(tech_name)
    :set_science_packs({{"automation-science-pack", 1}})
    :set({unit = {count = 30, time = 15}})  -- Standardize cost and time
    :commit()
end

-- Add mod integration for science pack overhauls
if mods["ScienceCostTweakerM"] then
  -- Replace vanilla science packs with modded equivalents
  local vanilla_packs = {
    "automation-science-pack",
    "logistic-science-pack",
    "chemical-science-pack",
    "military-science-pack",
    "production-science-pack",
    "utility-science-pack"
  }

  local modded_packs = {
    "sct-automation-science-pack",
    "sct-logistic-science-pack",
    "sct-chemical-science-pack",
    "sct-military-science-pack",
    "sct-production-science-pack",
    "sct-utility-science-pack"
  }

  for i, vanilla_pack in ipairs(vanilla_packs) do
    local modded_pack = modded_packs[i]
    if data.raw.item[modded_pack] then
      local affected_techs = khaoslib_technology.find(function(tech)
        if not (tech.unit and tech.unit.ingredients) then return false end
        -- Check raw data directly for efficiency
        for _, science_pack in ipairs(tech.unit.ingredients) do
          if science_pack[1] == vanilla_pack then
            return true
          end
        end
        return false
      end)

      for _, tech_name in ipairs(affected_techs) do
        khaoslib_technology:load(tech_name)
          :replace_science_pack(vanilla_pack, {modded_pack, 1})
          :commit()
      end
    end
  end
end
```

### Dynamic Technology Generation

```lua
-- Generate technologies for different ore types
local ore_types = {"iron", "copper", "uranium", "coal"}
local processing_levels = {
  {name = "basic", multiplier = 1, prerequisites = {"automation"}},
  {name = "advanced", multiplier = 2, prerequisites = {"advanced-electronics"}},
  {name = "superior", multiplier = 4, prerequisites = {"production-science-pack"}}
}

for _, ore in ipairs(ore_types) do
  for _, level in ipairs(processing_levels) do
    local tech_name = level.name .. "-" .. ore .. "-processing"

    khaoslib_technology:load({
      name = tech_name,
      icon = "__mymod__/graphics/technology/" .. tech_name .. ".png",
      prerequisites = level.prerequisites,
      effects = {
        {
          type = "unlock-recipe",
          recipe = level.name .. "-" .. ore .. "-smelting"
        }
      },
      unit = {
        count = 50 * level.multiplier,
        time = 15 * level.multiplier,
        ingredients = {
          {"automation-science-pack", 1}
        }
      }
    }):commit()
  end
end
```

### Effect Manipulation with Custom Logic

```lua
-- Remove all unlock-recipe effects for chemistry recipes in a "no chemistry" mod
tech:remove_effect(function(effect)
  return effect.type == "unlock-recipe" and
    data.raw.recipe[effect.recipe] and
    data.raw.recipe[effect.recipe].category == "chemistry"
end, {all = true})

-- Replace productivity bonuses with speed bonuses for fast-paced gameplay
local productivity_techs = khaoslib_technology.find(function(tech)
  if not tech.effects then return false end
  for _, effect in ipairs(tech.effects) do
    if effect.type == "ammo-damage" or effect.type == "gun-speed" then
      return false -- Skip military techs
    end
    if effect.type and effect.type:match("productivity") then
      return true
    end
  end
  return false
end)

for _, tech_name in ipairs(productivity_techs) do
  local tech = khaoslib_technology:load(tech_name)

  -- Replace productivity effects with speed effects
  tech:remove_effect(function(effect)
    return effect.type and effect.type:match("productivity")
  end, {all = true})

  tech:add_effect({
    type = "laboratory-speed",
    modifier = 0.2
  }):commit()
end
```

### Technology Discovery and Analysis

```lua
-- Find and analyze technologies for balance checking
local smelting_techs = khaoslib_technology.find(function(tech)
  if not tech.effects then return false end
  for _, effect in ipairs(tech.effects) do
    if effect.type == "unlock-recipe" and
       effect.recipe and
       effect.recipe:match("smelting") then
      return true
    end
  end
  return false
end)

-- Generate a balance report
log("=== Smelting Technology Analysis ===")
for _, tech_name in ipairs(smelting_techs) do
  local tech_data = data.raw.technology[tech_name]  -- Direct access, no deep copy
  local tech_manipulator = khaoslib_technology:load(tech_name)
  local recipe_count = tech_manipulator:count_unlock_recipes()
  local prereq_count = #(tech_data.prerequisites or {})

  log(string.format("Tech: %s | Recipes: %d | Prerequisites: %d | Cost: %d",
    tech_name, recipe_count, prereq_count, tech_data.unit.count or 0))
end
```

### Conditional Technology Modifications

```lua
-- Create different tech trees based on settings or mod presence
local function setup_technology_variants()
  local settings = settings.startup["mymod-difficulty"].value

  if settings == "easy" then
    -- Reduce costs and prerequisites for easy mode
    local complex_techs = khaoslib_technology.find(function(tech)
      return tech.unit and tech.unit.count and tech.unit.count > 200
    end)

    for _, tech_name in ipairs(complex_techs) do
      local tech_data = data.raw.technology[tech_name]  -- Direct access, no deep copy
      khaoslib_technology:load(tech_name)
        :set({
          unit = {
            count = math.floor((tech_data.unit.count or 0) * 0.5),
            time = 15  -- Faster research
          }
        })
        :commit()
    end

  elseif settings == "hard" then
    -- Add complexity and new prerequisites
    local all_techs = khaoslib_technology.find(function() return true end)

    for _, tech_name in ipairs(all_techs) do
      if not tech_name:match("^basic%-") then
        local tech_data = data.raw.technology[tech_name]  -- Direct access, no deep copy
        khaoslib_technology:load(tech_name)
          :add_prerequisite("research-methodology")
          :set({
            unit = {
              count = math.floor((tech_data.unit.count or 100) * 2),
              time = 60
            }
          })
          :commit()
      end
    end
  end
end

setup_technology_variants()

```

## Best Practices

### Method Chaining

Use method chaining for readable, fluent operations:

```lua
-- Good
khaoslib_technology:load("electronics")
  :add_prerequisite("basic-tech")
  :add_unlock_recipe("advanced-circuit")
  :set({unit = {count = 200}})
  :commit()

-- Avoid
local tech = khaoslib_technology:load("electronics")
tech:add_prerequisite("basic-tech")
tech:add_unlock_recipe("advanced-circuit")
tech:set({unit = {count = 200}})
tech:commit()

```

### Bulk Operations

For multiple technologies, use utility functions and loops:

```lua
-- Find technologies first, then modify
local target_techs = khaoslib_technology.find(function(tech)
  return tech.name:match("^old%-")
end)

for _, tech_name in ipairs(target_techs) do
  khaoslib_technology:load(tech_name)
    :replace_unlock_recipe("old-recipe", "new-recipe")
    :commit()
end
```

### Existence Checking

Always check existence before operations:

```lua
if khaoslib_technology.exists("target-tech") then
  khaoslib_technology:load("target-tech")
    :add_prerequisite("new-prereq")
    :commit()
end
```

### Deep Copying Safety

The module automatically handles deep copying, so you don't need to worry about reference sharing:

```lua
-- This is safe - the module handles deep copying internally
local tech_data = khaoslib_technology:load("electronics"):get()
-- Modifying tech_data won't affect the original

```

### Performance Optimization

Avoid unnecessary deep copies by checking raw data before using the API:

```lua
-- Inefficient - creates deep copy just to check
if khaoslib_technology:load("automation"):has_unlock_recipe("inserter") then
  -- ...
end

-- Efficient - check raw data first
local automation_tech = data.raw.technology["automation"]
local has_inserter = false
if automation_tech and automation_tech.effects then
  for _, effect in ipairs(automation_tech.effects) do
    if effect.type == "unlock-recipe" and effect.recipe == "inserter" then
      has_inserter = true
      break
    end
  end
end

if has_inserter then
  -- Only load when we need to modify
  khaoslib_technology:load("automation"):remove_unlock_recipe("inserter"):commit()
end

-- For reading data, use direct access
local tech_data = data.raw.technology["my-tech"]  -- No deep copy
local cost = tech_data.unit.count

-- For modifying, use the API
khaoslib_technology:load("my-tech"):set({unit = {count = cost * 2}}):commit()

```

## Error Handling

The module provides comprehensive error handling with descriptive messages:

### Common Errors

```lua
-- Technology doesn't exist
khaoslib_technology:load("nonexistent-tech")
-- Error: No such technology: nonexistent-tech

-- Invalid parameter type
tech:add_prerequisite(123)
-- Error: prerequisite parameter: Expected string, got number

-- Trying to create technology with existing name
khaoslib_technology:load({name = "electronics"})
-- Error: A technology with the name electronics already exists

```

### Error Prevention

- Use `khaoslib_technology.exists()` to check before loading
- Validate your data before passing to functions
- Use the `{all = true}` option carefully with remove/replace operations

## Performance Notes

- All operations use deep copying to ensure data stage safety
- Method chaining is efficient - intermediate states are not committed
- Use `has_prerequisite()` and `has_effect()` before expensive operations
- Function comparisons enable powerful but potentially expensive matching
- Bulk operations with `find()` are more efficient than individual checks
