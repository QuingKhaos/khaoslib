# Fluent API Design Patterns for Factorio Prototype Manipulation

## Overview

This document identifies extensive use cases for fluent API design patterns in Factorio mod development, based on
comprehensive analysis of the Pyanodons, Krastorio2, and broader modding ecosystem. Fluent APIs provide intuitive,
readable, and maintainable interfaces for complex prototype manipulation tasks that are common in overhaul modding.

## Executive Summary

**Key Findings:**

- **High-Impact Areas**: Multi-step prototype modifications, conditional logic chains, bulk operations across
  prototype types
- **Primary Benefits**: Improved code readability, reduced boilerplate, enhanced developer experience
- **Ecosystem Demand**: Strong evidence from complex mods requiring extensive prototype manipulation workflows
- **Implementation Strategy**: Extend current manipulator pattern to support advanced chaining, conditional
  operations, and cross-prototype relationships

## Table of Contents

1. [Fluent API Design Principles](#fluent-api-design-principles)
2. [Current Implementation Analysis](#current-implementation-analysis)
3. [Recipe Manipulation Fluent Patterns](#recipe-manipulation-fluent-patterns)
4. [Technology Manipulation Fluent Patterns](#technology-manipulation-fluent-patterns)
5. [Item & Fluid Fluent Patterns](#item--fluid-fluent-patterns)
6. [Entity Manipulation Fluent Patterns](#entity-manipulation-fluent-patterns)
7. [Cross-Prototype Fluent Operations](#cross-prototype-fluent-operations)
8. [Advanced Fluent Composition](#advanced-fluent-composition)
9. [Performance & Memory Considerations](#performance--memory-considerations)
10. [Implementation Roadmap](#implementation-roadmap)

## Fluent API Design Principles

### Core Principles for Factorio Modding

**1. Method Chaining**: Every operation returns the manipulator object for continued chaining

**2. Readable Intent**: Method names clearly express the intended operation

**3. Contextual Fluency**: Operations flow naturally from one to the next

**4. Error Prevention**: Design prevents common mistakes through API structure

**5. Performance Awareness**: Chaining doesn't create unnecessary object copies

### Fluent API Benefits in Modding Context

**Developer Experience Benefits:**

- **Reduced Cognitive Load**: Complex operations expressed as readable sequences
- **IDE Support**: Method chaining enables better autocomplete and discovery
- **Error Reduction**: Fluent patterns prevent common parameter ordering mistakes
- **Maintainability**: Changes to complex operations are easier to understand and modify

**Factorio-Specific Benefits:**

- **Multi-Step Operations**: Recipe/technology modifications often require many related changes
- **Conditional Logic**: Settings-based or mod-compatibility conditional operations
- **Bulk Operations**: Processing many prototypes with similar transformation patterns
- **Relationship Management**: Managing complex relationships between recipes, technologies,
  and other prototypes

## Current Implementation Analysis

### Existing Fluent Patterns in khaoslib

**Strong Foundation in Recipe Module:**

```lua
-- Current fluent recipe manipulation
khaoslib_recipe:load("steel-plate")
  :add_ingredient({type = "item", name = "coal", amount = 1})
  :remove_ingredient("iron-ore")
  :set({energy_required = 3.2})
  :add_unlock("advanced-metallurgy")
  :commit()
```

**Technology Module Fluent Operations:**

```lua
-- Current fluent technology manipulation
khaoslib_technology:load("electronics")
  :add_prerequisite("basic-tech")
  :add_unlock_recipe("electronic-circuit-advanced")
  :replace_science_pack("automation-science-pack", {"automation-science-pack", 2})
  :commit()
```

### Gaps and Enhancement Opportunities

**Missing Fluent Patterns:**

1. **Conditional Operations**: If/when/unless patterns for settings-based logic
2. **Bulk Operations**: Fluent processing of multiple prototypes
3. **Cross-Prototype Operations**: Fluent management of prototype relationships
4. **Query and Filter Chaining**: Fluent discovery and filtering operations
5. **Transaction Management**: Fluent batch operations with rollback capabilities

## Recipe Manipulation Fluent Patterns

### 1. Enhanced Conditional Operations

#### Pattern: Fluent Conditional Chains

```lua
-- Enhanced recipe manipulator with conditional fluent operations
local enhanced_recipe = khaoslib_recipe:load("electronic-circuit")
  :when(settings.startup["expensive-electronics"].value, function(recipe)
    return recipe
      :multiply_ingredient_amounts(2.0)
      :set({energy_required = recipe:get().energy_required * 1.5})
  end)
  :when_mod_active("pyanodons", function(recipe)
    return recipe
      :replace_ingredient("copper-plate", {type = "item", name = "py-copper-plate", amount = 2})
      :add_ingredient({type = "item", name = "py-solder", amount = 1})
  end)
  :unless(data.raw.item["basic-electronic-circuit"], function(recipe)
    return recipe:add_result({type = "item", name = "basic-electronic-circuit", amount = 1})
  end)
  :commit()
```

#### Pattern: Settings-Based Fluent Configuration

```lua
-- Settings-driven recipe configuration
local RecipeConfigurator = {}

function RecipeConfigurator:new(recipe_name)
  local configurator = khaoslib_recipe:load(recipe_name)

  -- Add fluent configuration methods
  function configurator:configure_difficulty()
    local difficulty = settings.startup["recipe-difficulty"].value

    return self
      :when(difficulty == "easy", function(recipe)
        return recipe:multiply_ingredient_amounts(0.8):set({energy_required = recipe:get().energy_required * 0.8})
      end)
      :when(difficulty == "normal", function(recipe)
        return recipe  -- No changes for normal difficulty
      end)
      :when(difficulty == "hard", function(recipe)
        return recipe:multiply_ingredient_amounts(1.5):set({energy_required = recipe:get().energy_required * 1.3})
      end)
      :when(difficulty == "marathon", function(recipe)
        return recipe:multiply_ingredient_amounts(2.0):set({energy_required = recipe:get().energy_required * 2.0})
      end)
  end

  function configurator:configure_mod_compatibility()
    return self
      :when_mod_active("bobs-plates", function(recipe)
        return recipe:replace_ingredients_matching(".*-plate$", function(ingredient)
          ingredient.name = "bob-" .. ingredient.name
          return ingredient
        end)
      end)
      :when_mod_active("angels-smelting", function(recipe)
        return recipe:add_ingredient({type = "item", name = "angels-smelting-catalyst", amount = 1})
      end)
  end

  return configurator
end

-- Usage
RecipeConfigurator:new("steel-plate")
  :configure_difficulty()
  :configure_mod_compatibility()
  :commit()
```

### 2. Bulk Operations with Fluent Interface

#### Pattern: Recipe Collection Fluent Processing

```lua
-- Fluent bulk recipe processing
local RecipeCollection = {}

function RecipeCollection:new(recipe_names_or_filter)
  local collection = {
    recipes = {},
    operations = {}
  }

  -- Initialize collection
  if type(recipe_names_or_filter) == "function" then
    -- Filter function provided
    for recipe_name, recipe_data in pairs(data.raw.recipe) do
      if recipe_names_or_filter(recipe_data) then
        table.insert(collection.recipes, recipe_name)
      end
    end
  else
    -- List of recipe names provided
    collection.recipes = recipe_names_or_filter or {}
  end

  setmetatable(collection, {__index = self})
  return collection
end

function RecipeCollection:filter(predicate)
  local filtered_recipes = {}
  for _, recipe_name in ipairs(self.recipes) do
    local recipe_data = data.raw.recipe[recipe_name]
    if recipe_data and predicate(recipe_data) then
      table.insert(filtered_recipes, recipe_name)
    end
  end
  self.recipes = filtered_recipes
  return self
end

function RecipeCollection:map(operation_fn)
  table.insert(self.operations, operation_fn)
  return self
end

function RecipeCollection:when(condition, operation_fn)
  if condition then
    return self:map(operation_fn)
  end
  return self
end

function RecipeCollection:execute()
  local processed_count = 0

  for _, recipe_name in ipairs(self.recipes) do
    local recipe = khaoslib_recipe:load(recipe_name)

    -- Apply all operations in sequence
    for _, operation in ipairs(self.operations) do
      recipe = operation(recipe)
    end

    recipe:commit()
    processed_count = processed_count + 1
  end

  print(string.format("Processed %d recipes", processed_count))
  return processed_count
end

-- Usage: Fluent bulk recipe processing
RecipeCollection:new(function(recipe)
  return recipe.category == "smelting"
end)
  :filter(function(recipe) return recipe.energy_required and recipe.energy_required > 1.0 end)
  :map(function(recipe)
    return recipe:set({energy_required = recipe:get().energy_required * 0.8})
  end)
  :when(settings.startup["fast-smelting"].value, function(recipe)
    return recipe:multiply_ingredient_amounts(0.9)
  end)
  :execute()
```

### 3. Ingredient Chain Fluent Operations

#### Pattern: Complex Ingredient Manipulation Chains

```lua
-- Enhanced ingredient manipulation with fluent chaining
function khaoslib_recipe:transform_ingredients()
  local transformer = {
    recipe = self,
    transformations = {}
  }

  function transformer:scale_by_tier(scale_factors)
    table.insert(self.transformations, function(ingredient)
      local tier = get_item_tier(ingredient.name) or 1
      local scale = scale_factors[tier] or 1.0
      ingredient.amount = math.max(1, math.floor(ingredient.amount * scale))
      return ingredient
    end)
    return self
  end

  function transformer:replace_by_pattern(pattern, replacement_fn)
    table.insert(self.transformations, function(ingredient)
      if string.match(ingredient.name, pattern) then
        return replacement_fn(ingredient)
      end
      return ingredient
    end)
    return self
  end

  function transformer:add_catalysts(catalyst_rules)
    table.insert(self.transformations, function(ingredient)
      for pattern, catalyst in pairs(catalyst_rules) do
        if string.match(ingredient.name, pattern) then
          -- This transformation would trigger adding a catalyst
          -- (implementation would need to track this for later application)
          print(string.format("Catalyst needed: %s for %s", catalyst, ingredient.name))
        end
      end
      return ingredient
    end)
    return self
  end

  function transformer:apply()
    -- Apply all transformations to ingredients
    for _, transformation in ipairs(self.transformations) do
      self.recipe:replace_ingredient(function() return true end, transformation, {all = true})
    end
    return self.recipe
  end

  return transformer
end

-- Usage: Complex ingredient transformation chain
khaoslib_recipe:load("advanced-circuit")
  :transform_ingredients()
    :scale_by_tier({[1] = 0.8, [2] = 1.0, [3] = 1.2, [4] = 1.5})
    :replace_by_pattern(".*%-plate$", function(ingredient)
      ingredient.name = "processed-" .. ingredient.name
      return ingredient
    end)
    :add_catalysts({
      ["electronic.*"] = "electronic-catalyst",
      [".*-circuit"] = "circuit-catalyst"
    })
    :apply()
  :commit()
```

## Technology Manipulation Fluent Patterns

### 1. Prerequisite Chain Fluent Management

#### Pattern: Technology Dependency Graph Operations

```lua
-- Enhanced technology manipulator with dependency management
function khaoslib_technology:manage_dependencies()
  local manager = {
    technology = self,
    dependency_rules = {}
  }

  function manager:simplify_prerequisites(complexity_threshold)
    table.insert(self.dependency_rules, function(tech)
      local prerequisites = tech:get_prerequisites()
      local simplified = {}

      for _, prereq_name in ipairs(prerequisites) do
        local prereq_complexity = get_technology_complexity(prereq_name)
        if prereq_complexity <= complexity_threshold then
          table.insert(simplified, prereq_name)
        else
          -- Find simpler alternative
          local alternatives = find_simpler_prerequisites(prereq_name, complexity_threshold)
          for _, alt in ipairs(alternatives) do
            table.insert(simplified, alt)
          end
        end
      end

      return tech:set_prerequisites(simplified)
    end)
    return self
  end

  function manager:add_progressive_prerequisites(progression_map)
    table.insert(self.dependency_rules, function(tech)
      local tech_tier = get_technology_tier(tech:get().name)
      local required_prereqs = progression_map[tech_tier] or {}

      for _, prereq in ipairs(required_prereqs) do
        if not tech:has_prerequisite(prereq) then
          tech:add_prerequisite(prereq)
        end
      end

      return tech
    end)
    return self
  end

  function manager:remove_redundant_prerequisites()
    table.insert(self.dependency_rules, function(tech)
      local prerequisites = tech:get_prerequisites()
      local essential_prereqs = {}

      for _, prereq_name in ipairs(prerequisites) do
        if not is_prerequisite_redundant(prereq_name, prerequisites) then
          table.insert(essential_prereqs, prereq_name)
        end
      end

      return tech:set_prerequisites(essential_prereqs)
    end)
    return self
  end

  function manager:apply()
    local tech = self.technology
    for _, rule in ipairs(self.dependency_rules) do
      tech = rule(tech)
    end
    return tech
  end

  return manager
end

-- Usage: Complex dependency management
khaoslib_technology:load("advanced-electronics-2")
  :manage_dependencies()
    :simplify_prerequisites(8)  -- Remove prerequisites with complexity > 8
    :add_progressive_prerequisites({
      [1] = {"automation"},
      [2] = {"automation", "logistics"},
      [3] = {"automation", "logistics", "chemical-science-pack"},
      [4] = {"automation", "logistics", "chemical-science-pack", "production-science-pack"}
    })
    :remove_redundant_prerequisites()
    :apply()
  :commit()
```

### 2. Science Pack Cost Fluent Operations

#### Pattern: Dynamic Science Pack Management

```lua
-- Fluent science pack cost management
function khaoslib_technology:manage_science_costs()
  local manager = {
    technology = self,
    cost_rules = {}
  }

  function manager:scale_by_difficulty(difficulty_settings)
    table.insert(self.cost_rules, function(tech)
      local difficulty = settings.startup["science-difficulty"].value
      local scale_factor = difficulty_settings[difficulty] or 1.0

      return tech:replace_science_pack(function() return true end, function(science_pack)
        science_pack.amount = math.max(1, math.floor(science_pack.amount * scale_factor))
        return science_pack
      end, {all = true})
    end)
    return self
  end

  function manager:add_progressive_packs(progression_rules)
    table.insert(self.cost_rules, function(tech)
      local tech_tier = get_technology_tier(tech:get().name)
      local required_packs = progression_rules[tech_tier] or {}

      for _, pack_data in ipairs(required_packs) do
        if not tech:has_science_pack(pack_data.name) then
          tech:add_science_pack({type = "item", name = pack_data.name, amount = pack_data.amount})
        end
      end

      return tech
    end)
    return self
  end

  function manager:balance_costs(balancing_rules)
    table.insert(self.cost_rules, function(tech)
      local total_cost = calculate_total_science_cost(tech)

      if total_cost > balancing_rules.max_total_cost then
        local reduction_factor = balancing_rules.max_total_cost / total_cost
        tech:replace_science_pack(function() return true end, function(science_pack)
          science_pack.amount = math.max(1, math.floor(science_pack.amount * reduction_factor))
          return science_pack
        end, {all = true})
      end

      return tech
    end)
    return self
  end

  function manager:apply()
    local tech = self.technology
    for _, rule in ipairs(self.cost_rules) do
      tech = rule(tech)
    end
    return tech
  end

  return manager
end

-- Usage: Complex science cost management
khaoslib_technology:load("space-science-pack")
  :manage_science_costs()
    :scale_by_difficulty({
      easy = 0.7,
      normal = 1.0,
      hard = 1.4,
      marathon = 2.0
    })
    :add_progressive_packs({
      [4] = {
        {name = "space-science-pack", amount = 1},
        {name = "utility-science-pack", amount = 1}
      }
    })
    :balance_costs({max_total_cost = 1000})
    :apply()
  :commit()
```

## Item & Fluid Fluent Patterns

### 1. Item Property Fluent Configuration

#### Pattern: Comprehensive Item Management

```lua
-- Fluent item property management
local ItemConfigurator = {}

function ItemConfigurator:new(item_name)
  local configurator = {
    item_name = item_name,
    property_modifications = {}
  }

  function configurator:optimize_stack_size(usage_analytics)
    table.insert(self.property_modifications, function(item_data)
      local usage_frequency = usage_analytics.frequency[self.item_name] or 0
      local complexity = usage_analytics.complexity[self.item_name] or 1

      local base_stack_size = item_data.stack_size or 50
      local frequency_multiplier = 1.0 + (usage_frequency * 0.2)
      local complexity_penalty = math.max(0.5, 1.0 - (complexity * 0.1))

      local optimized_size = math.floor(base_stack_size * frequency_multiplier * complexity_penalty)
      optimized_size = math.max(1, math.min(optimized_size, 1000))

      return {stack_size = optimized_size}
    end)
    return self
  end

  function configurator:add_quality_tiers(tier_settings)
    table.insert(self.property_modifications, function(item_data)
      local modifications = {}

      for tier_name, tier_data in pairs(tier_settings) do
        local tier_item_name = string.format("%s-%s", self.item_name, tier_name)

        -- Create quality tier item
        local tier_item = util.table.deepcopy(item_data)
        tier_item.name = tier_item_name
        tier_item.localised_name = {
          "",
          {"item-name." .. self.item_name},
          " (",
          {"quality-tier." .. tier_name},
          ")"
        }

        -- Apply tier-specific modifications
        if tier_data.stack_size_multiplier then
          tier_item.stack_size = math.floor((tier_item.stack_size or 50) * tier_data.stack_size_multiplier)
        end

        data.raw.item[tier_item_name] = tier_item
        print(string.format("Created quality tier: %s", tier_item_name))
      end

      return modifications
    end)
    return self
  end

  function configurator:configure_recycling(recycling_rules)
    table.insert(self.property_modifications, function(item_data)
      if recycling_rules.enable_recycling then
        -- Create recycling recipe
        local recycling_recipe = {
          type = "recipe",
          name = self.item_name .. "-recycling",
          category = "recycling",
          energy_required = recycling_rules.energy_required or 1.0,
          ingredients = {{type = "item", name = self.item_name, amount = 1}},
          results = recycling_rules.results or {}
        }

        data.raw.recipe[recycling_recipe.name] = recycling_recipe
        print(string.format("Created recycling recipe: %s", recycling_recipe.name))
      end

      return {}
    end)
    return self
  end

  function configurator:apply()
    local item_data = data.raw.item[self.item_name]
    if not item_data then
      error(string.format("Item %s not found", self.item_name))
    end

    local final_modifications = {}

    for _, modification_fn in ipairs(self.property_modifications) do
      local modifications = modification_fn(item_data)
      for key, value in pairs(modifications) do
        final_modifications[key] = value
      end
    end

    -- Apply final modifications
    for key, value in pairs(final_modifications) do
      item_data[key] = value
    end

    return self
  end

  setmetatable(configurator, {__index = self})
  return configurator
end

-- Usage: Comprehensive item configuration
ItemConfigurator:new("electronic-circuit")
  :optimize_stack_size({
    frequency = {["electronic-circuit"] = 0.8},
    complexity = {["electronic-circuit"] = 2}
  })
  :add_quality_tiers({
    basic = {stack_size_multiplier = 1.0},
    improved = {stack_size_multiplier = 1.2},
    advanced = {stack_size_multiplier = 1.5}
  })
  :configure_recycling({
    enable_recycling = true,
    energy_required = 2.0,
    results = {
      {type = "item", name = "copper-cable", amount = 2},
      {type = "item", name = "iron-plate", amount = 1}
    }
  })
  :apply()
```

### 2. Fluid Property Fluent Management

#### Pattern: Realistic Fluid Properties

```lua
-- Fluent fluid property management
local FluidConfigurator = {}

function FluidConfigurator:new(fluid_name)
  local configurator = {
    fluid_name = fluid_name,
    property_calculations = {}
  }

  function configurator:calculate_realistic_properties(composition_data)
    table.insert(self.property_calculations, function(fluid_data)
      local composition = composition_data[self.fluid_name] or {}

      -- Calculate realistic temperature
      local base_temp = fluid_data.default_temperature or 15
      local composition_temp_offset = 0

      for component, percentage in pairs(composition) do
        local component_temp = get_component_temperature(component) or 15
        composition_temp_offset = composition_temp_offset + (component_temp * percentage)
      end

      local realistic_temp = math.floor(base_temp + composition_temp_offset)

      -- Calculate viscosity and flow properties
      local viscosity = calculate_fluid_viscosity(composition, realistic_temp)

      return {
        default_temperature = realistic_temp,
        max_temperature = realistic_temp + 100,
        viscosity_factor = viscosity,
        flow_to_energy_ratio = calculate_flow_energy_ratio(viscosity)
      }
    end)
    return self
  end

  function configurator:add_temperature_variants(variant_rules)
    table.insert(self.property_calculations, function(fluid_data)
      for variant_name, variant_data in pairs(variant_rules) do
        local variant_fluid_name = string.format("%s-%s", self.fluid_name, variant_name)

        local variant_fluid = util.table.deepcopy(fluid_data)
        variant_fluid.name = variant_fluid_name
        variant_fluid.default_temperature = variant_data.temperature
        variant_fluid.max_temperature = variant_data.max_temperature or variant_data.temperature + 100

        -- Adjust color based on temperature
        if variant_data.temperature > 100 then
          variant_fluid.base_color = tint_color_hot(variant_fluid.base_color or {r=1, g=1, b=1})
        elseif variant_data.temperature < 0 then
          variant_fluid.base_color = tint_color_cold(variant_fluid.base_color or {r=1, g=1, b=1})
        end

        data.raw.fluid[variant_fluid_name] = variant_fluid
        print(string.format("Created temperature variant: %s at %d°C",
          variant_fluid_name, variant_data.temperature))
      end

      return {}
    end)
    return self
  end

  function configurator:configure_processing_recipes(processing_rules)
    table.insert(self.property_calculations, function(fluid_data)
      for process_name, process_data in pairs(processing_rules) do
        local recipe_name = string.format("%s-%s", self.fluid_name, process_name)

        local processing_recipe = {
          type = "recipe",
          name = recipe_name,
          category = process_data.category or "chemistry",
          energy_required = process_data.energy_required or 2.0,
          ingredients = {
            {type = "fluid", name = self.fluid_name, amount = process_data.input_amount or 100}
          },
          results = process_data.results or {}
        }

        -- Add additional ingredients if specified
        for _, ingredient in ipairs(process_data.additional_ingredients or {}) do
          table.insert(processing_recipe.ingredients, ingredient)
        end

        data.raw.recipe[recipe_name] = processing_recipe
        print(string.format("Created processing recipe: %s", recipe_name))
      end

      return {}
    end)
    return self
  end

  function configurator:apply()
    local fluid_data = data.raw.fluid[self.fluid_name]
    if not fluid_data then
      error(string.format("Fluid %s not found", self.fluid_name))
    end

    local final_properties = {}

    for _, calculation_fn in ipairs(self.property_calculations) do
      local properties = calculation_fn(fluid_data)
      for key, value in pairs(properties) do
        final_properties[key] = value
      end
    end

    -- Apply final properties
    for key, value in pairs(final_properties) do
      fluid_data[key] = value
    end

    return self
  end

  setmetatable(configurator, {__index = self})
  return configurator
end

-- Usage: Comprehensive fluid configuration
FluidConfigurator:new("crude-oil")
  :calculate_realistic_properties({
    ["crude-oil"] = {
      ["hydrocarbon"] = 0.8,
      ["sulfur-compound"] = 0.15,
      ["water"] = 0.05
    }
  })
  :add_temperature_variants({
    heated = {temperature = 200, max_temperature = 300},
    cooled = {temperature = -20, max_temperature = 50}
  })
  :configure_processing_recipes({
    distillation = {
      category = "oil-processing",
      energy_required = 5.0,
      input_amount = 100,
      results = {
        {type = "fluid", name = "heavy-oil", amount = 25},
        {type = "fluid", name = "light-oil", amount = 45},
        {type = "fluid", name = "petroleum-gas", amount = 55}
      }
    },
    cracking = {
      category = "chemistry",
      energy_required = 3.0,
      input_amount = 40,
      additional_ingredients = {
        {type = "fluid", name = "steam", amount = 30}
      },
      results = {
        {type = "fluid", name = "light-oil", amount = 30}
      }
    }
  })
  :apply()
```

## Entity Manipulation Fluent Patterns

### 1. Machine Performance Fluent Configuration

#### Pattern: Dynamic Performance Scaling

```lua
-- Fluent entity performance management
local EntityPerformanceManager = {}

function EntityPerformanceManager:new(entity_name)
  local manager = {
    entity_name = entity_name,
    performance_rules = {}
  }

  function manager:scale_by_technology_progression(tech_bonuses)
    table.insert(self.performance_rules, function(entity_data)
      local speed_bonus = 1.0
      local efficiency_bonus = 1.0
      local productivity_bonus = 0.0

      for tech_name, bonus_data in pairs(tech_bonuses) do
        if data.raw.technology[tech_name] then
          speed_bonus = speed_bonus + (bonus_data.speed or 0)
          efficiency_bonus = efficiency_bonus + (bonus_data.efficiency or 0)
          productivity_bonus = productivity_bonus + (bonus_data.productivity or 0)
        end
      end

      local base_speed = entity_data.crafting_speed or 1.0
      local base_consumption = parse_energy_value(entity_data.energy_usage or "100kW")

      return {
        crafting_speed = base_speed * speed_bonus,
        energy_usage = format_energy_value(base_consumption / efficiency_bonus),
        base_productivity = productivity_bonus
      }
    end)
    return self
  end

  function manager:add_module_slots(slot_configuration)
    table.insert(self.performance_rules, function(entity_data)
      local module_slots = slot_configuration.base_slots or 2

      -- Scale module slots based on entity tier
      local entity_tier = get_entity_tier(self.entity_name)
      module_slots = module_slots + (entity_tier - 1)

      return {
        module_specification = {
          module_slots = module_slots,
          module_info_icon_shift = {0, 0.5},
          module_info_multi_row_initial_height_modifier = -0.3,
          module_info_icon_scale = 0.9
        },
        allowed_effects = slot_configuration.allowed_effects or {"consumption", "speed", "productivity", "pollution"}
      }
    end)
    return self
  end

  function manager:configure_pollution_scaling(pollution_rules)
    table.insert(self.performance_rules, function(entity_data)
      local base_pollution = entity_data.energy_usage_per_minute or 0
      local pollution_multiplier = pollution_rules.base_multiplier or 1.0

      -- Adjust pollution based on efficiency improvements
      if entity_data.crafting_speed and entity_data.crafting_speed > 1.0 then
        pollution_multiplier = pollution_multiplier * (1.0 + (entity_data.crafting_speed - 1.0) * 0.5)
      end

      return {
        energy_usage_per_minute = base_pollution * pollution_multiplier,
        pollution = {
          min_pollution_to_show = pollution_rules.min_to_show or 0.1,
          ageing = pollution_rules.ageing or 1
        }
      }
    end)
    return self
  end

  function manager:apply()
    local entity_data = data.raw["assembling-machine"][self.entity_name] or
                        data.raw["furnace"][self.entity_name] or
                        data.raw["mining-drill"][self.entity_name]

    if not entity_data then
      error(string.format("Entity %s not found in expected categories", self.entity_name))
    end

    local final_modifications = {}

    for _, rule_fn in ipairs(self.performance_rules) do
      local modifications = rule_fn(entity_data)
      for key, value in pairs(modifications) do
        final_modifications[key] = value
      end
    end

    -- Apply final modifications
    for key, value in pairs(final_modifications) do
      entity_data[key] = value
    end

    return self
  end

  setmetatable(manager, {__index = self})
  return manager
end

-- Usage: Comprehensive entity performance configuration
EntityPerformanceManager:new("assembling-machine-2")
  :scale_by_technology_progression({
    ["automation-2"] = {speed = 0.1, efficiency = 0.05},
    ["automation-3"] = {speed = 0.2, efficiency = 0.1},
    ["production-science-pack"] = {productivity = 0.1}
  })
  :add_module_slots({
    base_slots = 3,
    allowed_effects = {"consumption", "speed", "productivity"}
  })
  :configure_pollution_scaling({
    base_multiplier = 0.8,
    min_to_show = 0.05,
    ageing = 0.9
  })
  :apply()
```

## Cross-Prototype Fluent Operations

### 1. Recipe-Technology Relationship Management

#### Pattern: Fluent Cross-Prototype Coordination

```lua
-- Fluent cross-prototype relationship management
local PrototypeRelationshipManager = {}

function PrototypeRelationshipManager:new()
  local manager = {
    operations = {},
    recipe_tech_relationships = {},
    item_recipe_dependencies = {}
  }

  function manager:coordinate_recipe_technology_unlocks()
    table.insert(self.operations, function()
      -- Analyze recipe complexity and assign appropriate technology unlocks
      for recipe_name, recipe_data in pairs(data.raw.recipe) do
        local complexity = calculate_recipe_complexity(recipe_data)
        local suggested_tech = suggest_technology_for_recipe(recipe_name, complexity)

        if suggested_tech and data.raw.technology[suggested_tech] then
          -- Add recipe unlock to technology
          khaoslib_technology:load(suggested_tech)
            :add_unlock_recipe(recipe_name)
            :commit()

          -- Disable recipe by default (unlocked by technology)
          khaoslib_recipe:load(recipe_name)
            :set({enabled = false})
            :commit()

          print(string.format("Coordinated: Recipe %s -> Technology %s", recipe_name, suggested_tech))
        end
      end
    end)
    return self
  end

  function manager:balance_ingredient_availability()
    table.insert(self.operations, function()
      -- Ensure all recipe ingredients are available when the recipe is unlocked
      for recipe_name, recipe_data in pairs(data.raw.recipe) do
        local unlocking_techs = find_technologies_unlocking_recipe(recipe_name)

        for _, tech_name in ipairs(unlocking_techs) do
          local technology = khaoslib_technology:load(tech_name)
          local recipe = khaoslib_recipe:load(recipe_name)

          -- Check if all ingredients are available at this tech level
          local ingredients = recipe:get_ingredients()
          for _, ingredient in ipairs(ingredients) do
            if not is_ingredient_available_at_tech_level(ingredient, tech_name) then
              -- Find prerequisite technology that unlocks this ingredient
              local ingredient_tech = find_technology_unlocking_ingredient(ingredient.name)
              if ingredient_tech then
                technology:add_prerequisite(ingredient_tech)
                print(string.format("Added prerequisite: %s -> %s (for ingredient %s)",
                  tech_name, ingredient_tech, ingredient.name))
              end
            end
          end

          technology:commit()
        end
      end
    end)
    return self
  end

  function manager:optimize_production_chains()
    table.insert(self.operations, function()
      -- Analyze and optimize production chains for better game flow
      local production_chains = analyze_production_chains()

      for chain_name, chain_data in pairs(production_chains) do
        -- Identify bottlenecks in the production chain
        local bottlenecks = identify_chain_bottlenecks(chain_data)

        for _, bottleneck in ipairs(bottlenecks) do
          if bottleneck.type == "recipe" then
            -- Optimize bottleneck recipe
            khaoslib_recipe:load(bottleneck.name)
              :when(bottleneck.issue == "slow", function(recipe)
                local current_energy = recipe:get().energy_required or 0.5
                return recipe:set({energy_required = current_energy * 0.8})
              end)
              :when(bottleneck.issue == "expensive", function(recipe)
                return recipe:multiply_ingredient_amounts(0.9)
              end)
              :commit()

            print(string.format("Optimized bottleneck recipe: %s in chain %s",
              bottleneck.name, chain_name))
          end
        end
      end
    end)
    return self
  end

  function manager:execute()
    print("Executing cross-prototype relationship management...")

    for i, operation in ipairs(self.operations) do
      print(string.format("Executing operation %d/%d", i, #self.operations))
      operation()
    end

    print("Cross-prototype relationship management completed")
    return self
  end

  setmetatable(manager, {__index = self})
  return manager
end

-- Usage: Comprehensive cross-prototype coordination
PrototypeRelationshipManager:new()
  :coordinate_recipe_technology_unlocks()
  :balance_ingredient_availability()
  :optimize_production_chains()
  :execute()
```

## Advanced Fluent Composition

### 1. Fluent Query and Filter Chains

#### Pattern: Advanced Prototype Discovery

```lua
-- Advanced fluent querying system
local PrototypeQuery = {}

function PrototypeQuery:new(prototype_type)
  local query = {
    prototype_type = prototype_type,
    filters = {},
    transformations = {},
    results = nil
  }

  function query:where(field, operator, value)
    table.insert(self.filters, function(prototype)
      local field_value = prototype[field]

      if operator == "=" or operator == "==" then
        return field_value == value
      elseif operator == "!=" or operator == "~=" then
        return field_value ~= value
      elseif operator == ">" then
        return field_value and field_value > value
      elseif operator == "<" then
        return field_value and field_value < value
      elseif operator == ">=" then
        return field_value and field_value >= value
      elseif operator == "<=" then
        return field_value and field_value <= value
      elseif operator == "contains" then
        return field_value and string.find(tostring(field_value), value)
      elseif operator == "matches" then
        return field_value and string.match(tostring(field_value), value)
      else
        error("Unknown operator: " .. operator)
      end
    end)
    return self
  end

  function query:where_custom(filter_fn)
    table.insert(self.filters, filter_fn)
    return self
  end

  function query:order_by(field, direction)
    table.insert(self.transformations, function(results)
      table.sort(results, function(a, b)
        local a_val = a[field] or 0
        local b_val = b[field] or 0

        if direction == "desc" then
          return a_val > b_val
        else
          return a_val < b_val
        end
      end)
      return results
    end)
    return self
  end

  function query:limit(count)
    table.insert(self.transformations, function(results)
      local limited = {}
      for i = 1, math.min(count, #results) do
        table.insert(limited, results[i])
      end
      return limited
    end)
    return self
  end

  function query:group_by(field)
    table.insert(self.transformations, function(results)
      local groups = {}
      for _, result in ipairs(results) do
        local group_key = result[field] or "undefined"
        if not groups[group_key] then
          groups[group_key] = {}
        end
        table.insert(groups[group_key], result)
      end
      return groups
    end)
    return self
  end

  function query:execute()
    local raw_data = data.raw[self.prototype_type] or {}
    local results = {}

    -- Apply filters
    for prototype_name, prototype_data in pairs(raw_data) do
      local passes_filters = true

      for _, filter in ipairs(self.filters) do
        if not filter(prototype_data) then
          passes_filters = false
          break
        end
      end

      if passes_filters then
        table.insert(results, {name = prototype_name, data = prototype_data})
      end
    end

    -- Apply transformations
    for _, transformation in ipairs(self.transformations) do
      results = transformation(results)
    end

    self.results = results
    return self
  end

  function query:get_names()
    if not self.results then
      self:execute()
    end

    local names = {}
    for _, result in ipairs(self.results) do
      table.insert(names, result.name)
    end
    return names
  end

  function query:get_data()
    if not self.results then
      self:execute()
    end

    return self.results
  end

  function query:apply(operation_fn)
    local names = self:get_names()
    local count = 0

    for _, name in ipairs(names) do
      operation_fn(name)
      count = count + 1
    end

    print(string.format("Applied operation to %d %s prototypes", count, self.prototype_type))
    return count
  end

  setmetatable(query, {__index = self})
  return query
end

-- Usage: Advanced fluent querying and batch operations
PrototypeQuery:new("recipe")
  :where("category", "=", "smelting")
  :where("energy_required", ">", 1.0)
  :where_custom(function(recipe)
    return #(recipe.ingredients or {}) <= 2  -- Simple recipes only
  end)
  :order_by("energy_required", "desc")
  :limit(10)
  :apply(function(recipe_name)
    khaoslib_recipe:load(recipe_name)
      :set({energy_required = data.raw.recipe[recipe_name].energy_required * 0.8})
      :commit()
  end)

-- Complex technology querying
local expensive_techs = PrototypeQuery:new("technology")
  :where_custom(function(tech)
    if not tech.unit or not tech.unit.ingredients then return false end
    local total_cost = 0
    for _, ingredient in ipairs(tech.unit.ingredients) do
      total_cost = total_cost + (ingredient[2] or ingredient.amount or 0)
    end
    return total_cost > 100
  end)
  :where("unit", "!=", nil)
  :order_by("name", "asc")
  :get_names()

-- Apply cost reduction to expensive technologies
for _, tech_name in ipairs(expensive_techs) do
  khaoslib_technology:load(tech_name)
    :replace_science_pack(function() return true end, function(science_pack)
      science_pack.amount = math.max(1, math.floor(science_pack.amount * 0.8))
      return science_pack
    end, {all = true})
    :commit()
end
```

## Performance & Memory Considerations

### Memory-Efficient Fluent Patterns

#### Pattern: Lazy Execution and Resource Management

```lua
-- Memory-efficient fluent operations with lazy execution
local LazyFluentOperator = {}

function LazyFluentOperator:new(prototype_type)
  local operator = {
    prototype_type = prototype_type,
    operation_queue = {},
    batch_size = 50,
    executed = false
  }

  function operator:batch_size(size)
    self.batch_size = size
    return self
  end

  function operator:filter(predicate)
    table.insert(self.operation_queue, {
      type = "filter",
      operation = predicate
    })
    return self
  end

  function operator:transform(transform_fn)
    table.insert(self.operation_queue, {
      type = "transform",
      operation = transform_fn
    })
    return self
  end

  function operator:when(condition, operation_fn)
    if condition then
      table.insert(self.operation_queue, {
        type = "conditional",
        operation = operation_fn
      })
    end
    return self
  end

  function operator:execute_lazy()
    if self.executed then
      print("Warning: Operator already executed")
      return self
    end

    local raw_data = data.raw[self.prototype_type] or {}
    local processed_count = 0
    local batch_count = 0

    print(string.format("Starting lazy execution for %s prototypes", self.prototype_type))

    for prototype_name, prototype_data in pairs(raw_data) do
      local should_process = true
      local current_data = prototype_data

      -- Apply operations in sequence
      for _, queued_operation in ipairs(self.operation_queue) do
        if queued_operation.type == "filter" then
          if not queued_operation.operation(current_data) then
            should_process = false
            break
          end
        elseif queued_operation.type == "transform" then
          current_data = queued_operation.operation(current_data)
        elseif queued_operation.type == "conditional" then
          current_data = queued_operation.operation(current_data)
        end
      end

      if should_process then
        -- Apply final modifications
        self:apply_modifications(prototype_name, current_data)
        processed_count = processed_count + 1

        -- Yield control periodically to prevent timeout
        if processed_count % self.batch_size == 0 then
          batch_count = batch_count + 1
          print(string.format("Processed batch %d (%d items total)", batch_count, processed_count))

          -- Force garbage collection to manage memory
          if batch_count % 5 == 0 then
            collectgarbage("collect")
          end
        end
      end
    end

    print(string.format("Lazy execution completed: %d prototypes processed", processed_count))
    self.executed = true

    return self
  end

  function operator:apply_modifications(prototype_name, modified_data)
    -- Override in subclasses for prototype-specific modification application
    print(string.format("Applied modifications to %s", prototype_name))
  end

  setmetatable(operator, {__index = self})
  return operator
end

-- Recipe-specific lazy operator
local LazyRecipeOperator = setmetatable({}, {__index = LazyFluentOperator})

function LazyRecipeOperator:apply_modifications(recipe_name, modified_data)
  -- Extract modifications and apply via khaoslib_recipe
  local modifications = {}

  if modified_data.energy_required then
    modifications.energy_required = modified_data.energy_required
  end

  if modified_data.enabled ~= nil then
    modifications.enabled = modified_data.enabled
  end

  if next(modifications) then
    khaoslib_recipe:load(recipe_name):set(modifications):commit()
  end
end

-- Usage: Memory-efficient bulk recipe processing
LazyRecipeOperator:new("recipe")
  :batch_size(25)  -- Smaller batches for memory efficiency
  :filter(function(recipe)
    return recipe.category == "crafting" or recipe.category == "advanced-crafting"
  end)
  :when(settings.startup["energy-efficiency-mode"].value, function(recipe)
    recipe.energy_required = (recipe.energy_required or 0.5) * 0.8
    return recipe
  end)
  :transform(function(recipe)
    -- Normalize enabled field
    recipe.enabled = recipe.enabled ~= false
    return recipe
  end)
  :execute_lazy()
```

## Implementation Roadmap

### Phase 1: Core Fluent Enhancements (v0.3.0)

**Scope**: Enhance existing recipe and technology modules with advanced fluent patterns

**Key Features**:

- Conditional operation methods (`when`, `unless`, `when_mod_active`)
- Enhanced chaining with inline transformations
- Improved error handling in fluent chains

**Implementation**:

```lua
-- Add to existing recipe module
function khaoslib_recipe:when(condition, operation_fn)
  if condition then
    return operation_fn(self)
  end
  return self
end

function khaoslib_recipe:unless(condition, operation_fn)
  if not condition then
    return operation_fn(self)
  end
  return self
end

function khaoslib_recipe:when_mod_active(mod_name, operation_fn)
  if script.active_mods[mod_name] then
    return operation_fn(self)
  end
  return self
end
```

### Phase 2: Bulk Operation Framework (v0.4.0)

**Scope**: Add fluent bulk operation capabilities

**Key Features**:

- Fluent collection processing (`RecipeCollection`, `TechnologyCollection`)
- Advanced filtering and transformation chains
- Lazy evaluation for performance

**Implementation Strategy**:

- Build on existing manipulator foundation
- Add collection wrapper classes
- Implement lazy execution patterns

### Phase 3: Query and Discovery API (v0.4.0)

**Scope**: Advanced prototype discovery with fluent interface

**Key Features**:

- SQL-like query interface (`PrototypeQuery`)
- Fluent filtering, sorting, and grouping
- Integration with bulk operations

### Phase 4: Cross-Prototype Relationships (v0.8.0)

**Scope**: Fluent management of prototype relationships

**Key Features**:

- Recipe-technology coordination
- Ingredient availability analysis
- Production chain optimization

### Phase 5: Advanced Prototype Modules (v0.7.0)

**Scope**: Fluent APIs for item, fluid, and entity prototypes

**Key Features**:

- Item property configuration chains
- Fluid property calculation flows
- Entity performance scaling chains

## Conclusion

Fluent API design patterns offer substantial benefits for Factorio modding:

1. **Enhanced Readability**: Complex operations expressed as natural, readable chains
2. **Reduced Errors**: Method chaining prevents parameter ordering mistakes
3. **Improved Maintainability**: Changes to complex operations are easier to understand and modify
4. **Better Developer Experience**: IDE support, discoverability, and intuitive workflows

The proposed implementation builds on khaoslib's strong foundation while adding powerful fluent patterns that address
real-world modding challenges identified in the Pyanodons and Krastorio2 ecosystem analysis.

**Next Steps**: Implementation should follow the roadmap phases, starting with core fluent enhancements in v0.3.0 to
establish advanced chaining patterns throughout the khaoslib ecosystem.
