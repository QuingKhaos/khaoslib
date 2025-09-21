# Functional Programming Patterns in Factorio Modding

## Overview

This document identifies extensive use cases for functional programming patterns in Factorio mod development, based on comprehensive analysis of the Pyanodons, Krastorio2, and broader modding ecosystem. Functional programming offers powerful solutions for dynamic transformation, conditional logic, and maintainable code patterns that are particularly valuable in complex modding scenarios.

## Executive Summary

**Key Findings:**

- **High-Impact Areas**: Recipe ingredient/result transformations, technology prerequisite chains, prototype property calculations
- **Primary Benefits**: Reduced code duplication, improved maintainability, dynamic adaptation to game state
- **Ecosystem Demand**: Strong evidence from overhaul mods (Pyanodons, Krastorio2, Space Exploration) for dynamic transformation patterns
- **Implementation Strategy**: Extend existing list module foundation to support functional patterns across all prototype types

## Table of Contents

1. [Factorio Modding Context](#factorio-modding-context)
2. [Recipe System Functional Patterns](#recipe-system-functional-patterns)
3. [Technology System Functional Patterns](#technology-system-functional-patterns)
4. [Item & Fluid System Functional Patterns](#item--fluid-system-functional-patterns)
5. [Entity System Functional Patterns](#entity-system-functional-patterns)
6. [Cross-Prototype Functional Patterns](#cross-prototype-functional-patterns)
7. [Advanced Functional Composition](#advanced-functional-composition)
8. [Performance & Memory Considerations](#performance--memory-considerations)
9. [Implementation Roadmap](#implementation-roadmap)

## Factorio Modding Context

### Functional Programming Value Proposition in Modding

**Why Functional Patterns Matter for Factorio Modding:**

1. **Dynamic Adaptation**: Mods need to adapt based on other installed mods, settings, and game progression
2. **Complex Transformations**: Overhaul mods perform sophisticated ingredient/result/cost transformations
3. **Maintainability**: Functional patterns reduce code duplication when dealing with similar transformations
4. **Composability**: Build complex transformations from simple, reusable functions
5. **Declarative Logic**: Express transformation intent clearly and readably

### Current Ecosystem Analysis

**Evidence from Major Overhaul Mods:**

- **Pyanodons**: Extensive ingredient chain modifications, conditional recipe enablement
- **Krastorio2**: Dynamic cost scaling, alternative ingredient paths
- **Space Exploration**: Complex prerequisite chains, conditional technology unlocks
- **CompaktCircuit**: Multi-ingredient consolidation patterns

**Common Pain Points Addressed by Functional Patterns:**

- Repetitive ingredient transformation logic
- Complex conditional modification patterns
- Maintenance burden of hardcoded transformation tables
- Difficulty adapting to other mod combinations

## Recipe System Functional Patterns

### 1. Dynamic Ingredient Transformations

#### Pattern: Contextual Ingredient Replacement

```lua
local khaoslib_recipe = require("__khaoslib__.recipe")

-- Complexity-based ingredient transformation
local function create_complexity_scaler(complexity_threshold, scale_factor)
    return function(ingredient)
        local item_complexity = get_item_complexity(ingredient.name) or 1

        if item_complexity > complexity_threshold then
            ingredient.amount = math.max(1, math.floor(ingredient.amount * scale_factor))
            print(string.format("Scaled %s: complexity %d, new amount %d",
                ingredient.name, item_complexity, ingredient.amount))
        end

        return ingredient
    end
end

-- Apply complexity scaling to expensive recipes
local complexity_scaler = create_complexity_scaler(5, 0.7)

for recipe_name, recipe_data in pairs(data.raw.recipe) do
    if recipe_data.expensive then
        khaoslib_recipe:load(recipe_name)
            :replace_ingredient(function(ingredient)
                return ingredient.type == "item"
            end, complexity_scaler, {all = true})
            :commit()
    end
end
```

#### Pattern: Conditional Chain Replacement

```lua
-- Mod compatibility ingredient replacement chains
local function create_mod_compatibility_replacer(mod_name)
    local replacement_chains = {
        ["pyanodons"] = {
            ["iron-plate"] = function(ingredient)
                if data.raw.item["py-iron-plate"] then
                    ingredient.name = "py-iron-plate"
                    ingredient.amount = math.ceil(ingredient.amount * 1.2)
                end
                return ingredient
            end,
            ["copper-plate"] = function(ingredient)
                if data.raw.item["py-copper-plate"] then
                    ingredient.name = "py-copper-plate"
                    ingredient.amount = math.ceil(ingredient.amount * 1.1)
                end
                return ingredient
            end
        },
        ["krastorio2"] = {
            ["electronic-circuit"] = function(ingredient)
                if data.raw.item["kr-electronic-circuit"] then
                    ingredient.name = "kr-electronic-circuit"
                    -- Krastorio circuits are more efficient
                    ingredient.amount = math.max(1, math.floor(ingredient.amount * 0.8))
                end
                return ingredient
            end
        }
    }

    return replacement_chains[mod_name] or {}
end

-- Apply mod-specific compatibility transformations
if script.active_mods["pyanodons"] then
    local py_replacers = create_mod_compatibility_replacer("pyanodons")

    for recipe_name, _ in pairs(data.raw.recipe) do
        local recipe = khaoslib_recipe:load(recipe_name)

        for ingredient_name, replacer_fn in pairs(py_replacers) do
            if recipe:has_ingredient(ingredient_name) then
                recipe:replace_ingredient(ingredient_name, replacer_fn)
            end
        end

        recipe:commit()
    end
end
```

### 2. Result Transformation Patterns

#### Pattern: Yield Optimization Functions

```lua
-- Difficulty-based yield adjustment functions
local function create_yield_adjuster(difficulty_settings)
    return function(result)
        local base_yield = result.amount or 1
        local item_tier = get_item_tier(result.name) or 1

        local difficulty_multiplier = difficulty_settings.yield_multipliers[item_tier] or 1.0
        result.amount = math.max(1, math.floor(base_yield * difficulty_multiplier))

        -- Add probability adjustments for rare materials
        if item_tier >= 4 and not result.probability then
            result.probability = math.min(1.0, 0.7 + (difficulty_settings.rare_item_bonus or 0))
        end

        return result
    end
end

-- Apply yield adjustments based on startup settings
local difficulty_config = {
    yield_multipliers = {
        [1] = settings.startup["basic-yield-multiplier"].value,
        [2] = settings.startup["advanced-yield-multiplier"].value,
        [3] = settings.startup["rare-yield-multiplier"].value,
        [4] = settings.startup["legendary-yield-multiplier"].value
    },
    rare_item_bonus = settings.startup["rare-item-probability-bonus"].value
}

local yield_adjuster = create_yield_adjuster(difficulty_config)

-- Apply to all crafting recipes
for recipe_name, recipe_data in pairs(data.raw.recipe) do
    if recipe_data.category == "crafting" or recipe_data.category == "advanced-crafting" then
        khaoslib_recipe:load(recipe_name)
            :replace_result(function(result)
                return result.type == "item"
            end, yield_adjuster, {all = true})
            :commit()
    end
end
```

### 3. Energy and Time Scaling Functions

#### Pattern: Performance-Based Scaling

```lua
-- Machine efficiency scaling based on recipe complexity
local function create_efficiency_scaler(base_efficiency_factor)
    return function(recipe_data)
        local ingredient_count = #(recipe_data.ingredients or {})
        local result_count = #(recipe_data.results or {})
        local complexity_score = ingredient_count + result_count

        -- More complex recipes benefit more from efficiency improvements
        local efficiency_bonus = 1.0 + (complexity_score * 0.1 * base_efficiency_factor)

        local current_energy = recipe_data.energy_required or 0.5
        local new_energy = current_energy / efficiency_bonus

        print(string.format("Recipe %s: complexity %d, efficiency %.2f, energy %.2f -> %.2f",
            recipe_data.name, complexity_score, efficiency_bonus, current_energy, new_energy))

        return {energy_required = new_energy}
    end
end

-- Apply efficiency scaling to expensive recipes
local efficiency_scaler = create_efficiency_scaler(
    settings.startup["advanced-efficiency-factor"].value or 1.0
)

for recipe_name, recipe_data in pairs(data.raw.recipe) do
    if recipe_data.expensive then
        local scaling_data = efficiency_scaler(recipe_data)
        khaoslib_recipe:load(recipe_name):set(scaling_data):commit()
    end
end
```

## Technology System Functional Patterns

### 1. Prerequisite Chain Transformations

#### Pattern: Dependency Graph Rewriting

```lua
local khaoslib_technology = require("__khaoslib__.technology")

-- Prerequisite simplification for early game accessibility
local function create_prerequisite_simplifier(complexity_threshold)
    return function(prerequisite_name)
        local tech_data = data.raw.technology[prerequisite_name]
        if not tech_data then return prerequisite_name end

        local prereq_count = #(tech_data.prerequisites or {})
        local science_pack_count = #(tech_data.unit.ingredients or {})
        local complexity = prereq_count + science_pack_count

        if complexity > complexity_threshold then
            -- Find simpler alternative prerequisite
            local alternatives = find_alternative_prerequisites(prerequisite_name)
            if #alternatives > 0 then
                print(string.format("Simplified prerequisite: %s -> %s (complexity %d -> %d)",
                    prerequisite_name, alternatives[1], complexity,
                    get_technology_complexity(alternatives[1])))
                return alternatives[1]
            end
        end

        return prerequisite_name
    end
end

-- Apply prerequisite simplification for accessibility mods
if settings.startup["early-game-accessibility"].value then
    local simplifier = create_prerequisite_simplifier(8)

    -- Target technologies that unlock basic production capabilities
    local basic_production_techs = {
        "automation-2", "electronics", "steel-processing", "oil-processing"
    }

    for _, tech_name in ipairs(basic_production_techs) do
        khaoslib_technology:load(tech_name)
            :replace_prerequisite(function(prereq)
                return get_technology_complexity(prereq) > 5
            end, simplifier, {all = true})
            :commit()
    end
end
```

#### Pattern: Progressive Difficulty Scaling

```lua
-- Science pack cost scaling based on technology tier
local function create_science_cost_scaler(progression_settings)
    return function(science_ingredient)
        local tech_tier = get_technology_tier(science_ingredient.name)
        local progression_level = get_player_progression_level()

        local base_cost = science_ingredient.amount
        local scale_factor = progression_settings.tier_scales[tech_tier] or 1.0

        -- Adjust scaling based on player progression
        if progression_level < tech_tier then
            scale_factor = scale_factor * progression_settings.early_penalty
        elseif progression_level > tech_tier then
            scale_factor = scale_factor * progression_settings.late_bonus
        end

        science_ingredient.amount = math.max(1, math.floor(base_cost * scale_factor))

        print(string.format("Science cost scaling: %s tier %d, progression %d, scale %.2f, cost %d -> %d",
            science_ingredient.name, tech_tier, progression_level, scale_factor, base_cost, science_ingredient.amount))

        return science_ingredient
    end
end

-- Apply progressive difficulty scaling
local progression_config = {
    tier_scales = {
        [1] = 0.8,  -- Make basic science cheaper
        [2] = 1.0,  -- Keep intermediate science normal
        [3] = 1.3,  -- Make advanced science more expensive
        [4] = 1.6   -- Make space science much more expensive
    },
    early_penalty = 1.5,  -- Higher costs when ahead of progression
    late_bonus = 0.7      -- Lower costs when behind progression
}

local science_scaler = create_science_cost_scaler(progression_config)

-- Apply to military and production technologies
local target_categories = {"military", "production", "logistics"}

for tech_name, tech_data in pairs(data.raw.technology) do
    for _, category in ipairs(target_categories) do
        if string.find(tech_name, category) then
            khaoslib_technology:load(tech_name)
                :replace_science_pack(function(ingredient)
                    return ingredient.type == "item"
                end, science_scaler, {all = true})
                :commit()
            break
        end
    end
end
```

### 2. Effect Transformation Patterns

#### Pattern: Dynamic Recipe Unlock Management

```lua
-- Conditional recipe unlocking based on mod compatibility
local function create_recipe_unlock_manager(compatibility_rules)
    return function(effect)
        if effect.type ~= "unlock-recipe" then return effect end

        local recipe_name = effect.recipe
        local recipe_data = data.raw.recipe[recipe_name]

        if not recipe_data then
            print(string.format("Warning: Recipe %s not found, removing unlock effect", recipe_name))
            return nil  -- Remove this effect
        end

        -- Check compatibility rules
        for mod_name, rules in pairs(compatibility_rules) do
            if script.active_mods[mod_name] and rules.recipe_conflicts[recipe_name] then
                local replacement = rules.recipe_conflicts[recipe_name]
                print(string.format("Mod compatibility: Replacing recipe unlock %s -> %s",
                    recipe_name, replacement))
                effect.recipe = replacement
                break
            end
        end

        return effect
    end
end

-- Define compatibility rules for major overhaul mods
local compatibility_rules = {
    ["pyanodons"] = {
        recipe_conflicts = {
            ["steel-plate"] = "py-steel-plate",
            ["electronic-circuit"] = "py-electronic-circuit",
            ["advanced-circuit"] = "py-advanced-circuit"
        }
    },
    ["krastorio2"] = {
        recipe_conflicts = {
            ["electronic-circuit"] = "kr-basic-electronic-circuit",
            ["engine-unit"] = "kr-engine-unit"
        }
    }
}

local unlock_manager = create_recipe_unlock_manager(compatibility_rules)

-- Apply recipe unlock management to all technologies
for tech_name, _ in pairs(data.raw.technology) do
    local technology = khaoslib_technology:load(tech_name)

    -- Process all unlock-recipe effects
    local effects = technology:get_effects()
    local modified = false

    for i = #effects, 1, -1 do
        local effect = effects[i]
        if effect.type == "unlock-recipe" then
            local new_effect = unlock_manager(effect)
            if new_effect == nil then
                table.remove(effects, i)
                modified = true
            elseif new_effect ~= effect then
                effects[i] = new_effect
                modified = true
            end
        end
    end

    if modified then
        technology:set_effects(effects):commit()
    end
end
```

## Item & Fluid System Functional Patterns

### 1. Property Scaling Functions

#### Pattern: Stack Size Optimization

```lua
-- Dynamic stack size calculation based on item usage patterns
local function create_stack_size_optimizer(usage_analytics)
    return function(item_data)
        local item_name = item_data.name
        local usage_frequency = usage_analytics.frequency[item_name] or 0
        local recipe_complexity = usage_analytics.complexity[item_name] or 1

        -- Base stack size calculation
        local base_stack_size = item_data.stack_size or 50

        -- High-frequency items get larger stacks for QoL
        local frequency_multiplier = 1.0 + (usage_frequency * 0.2)

        -- Complex items get smaller stacks for balance
        local complexity_penalty = math.max(0.5, 1.0 - (recipe_complexity * 0.1))

        local optimized_stack_size = math.floor(base_stack_size * frequency_multiplier * complexity_penalty)
        optimized_stack_size = math.max(1, math.min(optimized_stack_size, 1000))  -- Clamp to reasonable range

        print(string.format("Stack size optimization: %s frequency %.2f, complexity %d, size %d -> %d",
            item_name, usage_frequency, recipe_complexity, base_stack_size, optimized_stack_size))

        return {stack_size = optimized_stack_size}
    end
end

-- Analyze item usage patterns across all recipes
local usage_analytics = analyze_item_usage_patterns()
local stack_optimizer = create_stack_size_optimizer(usage_analytics)

-- Apply stack size optimization
for item_name, item_data in pairs(data.raw.item) do
    local optimization = stack_optimizer(item_data)
    khaoslib_item:load(item_name):set(optimization):commit()
end
```

### 2. Fluid Property Transformations

#### Pattern: Temperature and Viscosity Scaling

```lua
-- Realistic fluid property calculation based on composition
local function create_fluid_property_calculator(realism_settings)
    return function(fluid_data)
        local fluid_name = fluid_data.name
        local composition = get_fluid_composition(fluid_name) -- Custom analysis function

        -- Calculate realistic temperature based on composition
        local base_temp = fluid_data.default_temperature or 15
        local composition_temp_offset = 0

        for component, percentage in pairs(composition) do
            local component_temp = realism_settings.component_temperatures[component] or 15
            composition_temp_offset = composition_temp_offset + (component_temp * percentage)
        end

        local realistic_temp = math.floor(base_temp + composition_temp_offset)

        -- Calculate viscosity for flow rate adjustments
        local viscosity_factor = calculate_viscosity_factor(composition, realistic_temp)

        print(string.format("Fluid realism: %s temp %d -> %d, viscosity %.2f",
            fluid_name, base_temp, realistic_temp, viscosity_factor))

        return {
            default_temperature = realistic_temp,
            max_temperature = realistic_temp + 100,
            -- Custom property for other mods to use
            viscosity_factor = viscosity_factor
        }
    end
end

-- Apply realistic fluid properties
if settings.startup["realistic-fluid-properties"].value then
    local realism_config = {
        component_temperatures = {
            ["crude-oil"] = 60,
            ["water"] = 15,
            ["petroleum-gas"] = -30,
            ["heavy-oil"] = 80,
            ["light-oil"] = 40
        }
    }

    local property_calculator = create_fluid_property_calculator(realism_config)

    for fluid_name, fluid_data in pairs(data.raw.fluid) do
        local properties = property_calculator(fluid_data)
        khaoslib_fluid:load(fluid_name):set(properties):commit()
    end
end
```

## Entity System Functional Patterns

### 1. Performance Scaling Functions

#### Pattern: Machine Efficiency Calculation

```lua
-- Dynamic machine performance based on technology progression
local function create_performance_scaler(tech_progression)
    return function(entity_data)
        local entity_name = entity_data.name
        local base_speed = entity_data.crafting_speed or 1.0
        local base_consumption = entity_data.energy_usage or "100kW"

        -- Calculate technology bonus based on unlocked techs
        local speed_bonus = 1.0
        local efficiency_bonus = 1.0

        for tech_name, bonus_data in pairs(tech_progression.speed_bonuses) do
            if data.raw.technology[tech_name] then
                speed_bonus = speed_bonus + bonus_data.speed_increase
                print(string.format("Speed bonus from %s: +%.1f%%", tech_name, bonus_data.speed_increase * 100))
            end
        end

        for tech_name, bonus_data in pairs(tech_progression.efficiency_bonuses) do
            if data.raw.technology[tech_name] then
                efficiency_bonus = efficiency_bonus + bonus_data.efficiency_increase
                print(string.format("Efficiency bonus from %s: +%.1f%%", tech_name, bonus_data.efficiency_increase * 100))
            end
        end

        local new_speed = base_speed * speed_bonus
        local new_consumption = parse_energy(base_consumption) / efficiency_bonus

        print(string.format("Entity scaling: %s speed %.2f -> %.2f, consumption %s -> %s",
            entity_name, base_speed, new_speed, base_consumption, format_energy(new_consumption)))

        return {
            crafting_speed = new_speed,
            energy_usage = format_energy(new_consumption)
        }
    end
end

-- Technology progression bonuses
local tech_progression = {
    speed_bonuses = {
        ["automation-2"] = {speed_increase = 0.1},
        ["automation-3"] = {speed_increase = 0.2},
        ["production-science-pack"] = {speed_increase = 0.15}
    },
    efficiency_bonuses = {
        ["energy-efficiency"] = {efficiency_increase = 0.2},
        ["advanced-energy-efficiency"] = {efficiency_increase = 0.3}
    }
}

local performance_scaler = create_performance_scaler(tech_progression)

-- Apply to all assembling machines
for entity_name, entity_data in pairs(data.raw["assembling-machine"]) do
    local scaling = performance_scaler(entity_data)
    khaoslib_entity:load(entity_name):set(scaling):commit()
end
```

## Cross-Prototype Functional Patterns

### 1. Ecosystem Transformation Functions

#### Pattern: Comprehensive Mod Integration

```lua
-- Holistic mod ecosystem integration using functional composition
local function create_ecosystem_integrator(integration_rules)
    return {
        recipe_transformer = function(recipe_data)
            local transformations = {}

            -- Apply ingredient transformations
            for _, rule in ipairs(integration_rules.ingredient_rules) do
                if rule.condition(recipe_data) then
                    table.insert(transformations, rule.transform)
                end
            end

            return function(ingredient)
                for _, transform in ipairs(transformations) do
                    ingredient = transform(ingredient)
                end
                return ingredient
            end
        end,

        technology_transformer = function(tech_data)
            local transformations = {}

            -- Apply prerequisite transformations
            for _, rule in ipairs(integration_rules.prerequisite_rules) do
                if rule.condition(tech_data) then
                    table.insert(transformations, rule.transform)
                end
            end

            return function(prerequisite)
                for _, transform in ipairs(transformations) do
                    prerequisite = transform(prerequisite)
                end
                return prerequisite
            end
        end
    }
end

-- Define comprehensive integration rules
local integration_rules = {
    ingredient_rules = {
        {
            condition = function(recipe) return recipe.category == "chemistry" end,
            transform = function(ingredient)
                if ingredient.type == "fluid" then
                    ingredient.amount = ingredient.amount * 1.2  -- More fluid for chemistry
                end
                return ingredient
            end
        },
        {
            condition = function(recipe) return string.find(recipe.name, "advanced") end,
            transform = function(ingredient)
                if get_item_tier(ingredient.name) < 3 then
                    ingredient.amount = ingredient.amount * 2  -- More basic materials for advanced recipes
                end
                return ingredient
            end
        }
    },
    prerequisite_rules = {
        {
            condition = function(tech) return tech.unit and #tech.unit.ingredients > 3 end,
            transform = function(prerequisite)
                -- Simplify prerequisites for complex technologies
                local simple_alternatives = find_prerequisite_alternatives(prerequisite)
                return simple_alternatives[1] or prerequisite
            end
        }
    }
}

-- Apply ecosystem integration
local integrator = create_ecosystem_integrator(integration_rules)

-- Process all recipes
for recipe_name, recipe_data in pairs(data.raw.recipe) do
    local recipe_transformer = integrator.recipe_transformer(recipe_data)

    khaoslib_recipe:load(recipe_name)
        :replace_ingredient(function() return true end, recipe_transformer, {all = true})
        :commit()
end

-- Process all technologies
for tech_name, tech_data in pairs(data.raw.technology) do
    local tech_transformer = integrator.technology_transformer(tech_data)

    khaoslib_technology:load(tech_name)
        :replace_prerequisite(function() return true end, tech_transformer, {all = true})
        :commit()
end
```

## Advanced Functional Composition

### 1. Pipeline Transformation Patterns

#### Pattern: Modular Transformation Pipelines

```lua
-- Composable transformation pipeline system
local TransformationPipeline = {}

function TransformationPipeline:new()
    local pipeline = {
        transformers = {},
        filters = {}
    }
    setmetatable(pipeline, {__index = self})
    return pipeline
end

function TransformationPipeline:add_filter(filter_fn, name)
    table.insert(self.filters, {fn = filter_fn, name = name or "unnamed"})
    return self
end

function TransformationPipeline:add_transformer(transform_fn, name)
    table.insert(self.transformers, {fn = transform_fn, name = name or "unnamed"})
    return self
end

function TransformationPipeline:execute(item)
    -- Apply filters first
    for _, filter in ipairs(self.filters) do
        if not filter.fn(item) then
            return item  -- Item doesn't pass filter, return unchanged
        end
    end

    -- Apply transformations in sequence
    local result = item
    for _, transformer in ipairs(self.transformers) do
        result = transformer.fn(result)
        print(string.format("Applied transformation '%s' to %s", transformer.name, tostring(result)))
    end

    return result
end

-- Example: Complex recipe ingredient transformation pipeline
local ingredient_pipeline = TransformationPipeline:new()
    :add_filter(function(ingredient)
        return ingredient.type == "item"
    end, "items-only")
    :add_filter(function(ingredient)
        return get_item_tier(ingredient.name) >= 2
    end, "advanced-items-only")
    :add_transformer(function(ingredient)
        -- Apply complexity scaling
        local complexity = get_item_complexity(ingredient.name)
        ingredient.amount = math.max(1, math.floor(ingredient.amount * (1.0 + complexity * 0.1)))
        return ingredient
    end, "complexity-scaling")
    :add_transformer(function(ingredient)
        -- Apply mod compatibility replacements
        local replacements = get_mod_replacements(ingredient.name)
        if replacements then
            ingredient.name = replacements.name
            ingredient.amount = ingredient.amount * replacements.amount_multiplier
        end
        return ingredient
    end, "mod-compatibility")

-- Apply pipeline to all recipes in a category
for recipe_name, recipe_data in pairs(data.raw.recipe) do
    if recipe_data.category == "advanced-crafting" then
        khaoslib_recipe:load(recipe_name)
            :replace_ingredient(function(ingredient)
                return ingredient.type == "item" and get_item_tier(ingredient.name) >= 2
            end, function(ingredient)
                return ingredient_pipeline:execute(ingredient)
            end, {all = true})
            :commit()
    end
end
```

### 2. Functional Composition Utilities

#### Pattern: Higher-Order Function Helpers

```lua
-- Utility functions for functional composition
local FunctionalUtils = {}

-- Compose multiple functions into a single function
function FunctionalUtils.compose(...)
    local functions = {...}
    return function(input)
        local result = input
        for i = #functions, 1, -1 do  -- Apply in reverse order
            result = functions[i](result)
        end
        return result
    end
end

-- Pipe functions (left-to-right composition)
function FunctionalUtils.pipe(...)
    local functions = {...}
    return function(input)
        local result = input
        for _, fn in ipairs(functions) do
            result = fn(result)
        end
        return result
    end
end

-- Conditional function application
function FunctionalUtils.when(condition, fn)
    return function(input)
        if condition(input) then
            return fn(input)
        end
        return input
    end
end

-- Memoization for expensive calculations
function FunctionalUtils.memoize(fn)
    local cache = {}
    return function(...)
        local key = table.concat({...}, "|")
        if cache[key] == nil then
            cache[key] = fn(...)
        end
        return cache[key]
    end
end

-- Example usage: Complex ingredient transformation
local ingredient_complexity = FunctionalUtils.memoize(function(item_name)
    -- Expensive calculation cached
    return calculate_item_complexity(item_name)
end)

local advanced_ingredient_transformer = FunctionalUtils.pipe(
    -- Step 1: Apply base scaling
    function(ingredient)
        ingredient.amount = ingredient.amount * 1.2
        return ingredient
    end,

    -- Step 2: Apply complexity adjustment (conditional)
    FunctionalUtils.when(
        function(ingredient) return ingredient_complexity(ingredient.name) > 5 end,
        function(ingredient)
            ingredient.amount = math.max(1, math.floor(ingredient.amount * 0.8))
            return ingredient
        end
    ),

    -- Step 3: Apply mod compatibility
    function(ingredient)
        return apply_mod_compatibility(ingredient)
    end
)

-- Use composed transformer
for recipe_name, _ in pairs(data.raw.recipe) do
    khaoslib_recipe:load(recipe_name)
        :replace_ingredient(function(ingredient)
            return ingredient.type == "item" and string.find(ingredient.name, "advanced")
        end, advanced_ingredient_transformer, {all = true})
        :commit()
end
```

## Performance & Memory Considerations

### Memory-Efficient Functional Patterns

#### Pattern: Lazy Evaluation and Streaming

```lua
-- Lazy evaluation for large-scale transformations
local LazyTransformer = {}

function LazyTransformer:new(data_source)
    local transformer = {
        source = data_source,
        operations = {}
    }
    setmetatable(transformer, {__index = self})
    return transformer
end

function LazyTransformer:filter(predicate)
    table.insert(self.operations, {type = "filter", fn = predicate})
    return self
end

function LazyTransformer:map(transform_fn)
    table.insert(self.operations, {type = "map", fn = transform_fn})
    return self
end

function LazyTransformer:execute_batch(batch_size)
    batch_size = batch_size or 100
    local processed = 0

    for key, value in pairs(self.source) do
        local result = value
        local should_process = true

        -- Apply operations in sequence
        for _, operation in ipairs(self.operations) do
            if operation.type == "filter" then
                if not operation.fn(result) then
                    should_process = false
                    break
                end
            elseif operation.type == "map" then
                result = operation.fn(result)
            end
        end

        if should_process then
            -- Process the transformed result
            self:process_result(key, result)
            processed = processed + 1

            -- Yield control periodically to prevent timeouts
            if processed % batch_size == 0 then
                print(string.format("Processed %d items, yielding control...", processed))
                coroutine.yield()
            end
        end
    end

    return processed
end

function LazyTransformer:process_result(key, result)
    -- Override in subclasses
    print(string.format("Processed: %s", key))
end

-- Recipe transformation with lazy evaluation
local RecipeTransformer = setmetatable({}, {__index = LazyTransformer})

function RecipeTransformer:process_result(recipe_name, transformed_data)
    khaoslib_recipe:load(recipe_name):set(transformed_data):commit()
end

-- Use lazy transformer for large-scale recipe modifications
local recipe_transformer = RecipeTransformer:new(data.raw.recipe)
    :filter(function(recipe) return recipe.category == "crafting" end)
    :map(function(recipe)
        return {
            energy_required = (recipe.energy_required or 0.5) * 1.2,
            enabled = recipe.enabled and true  -- Normalize boolean
        }
    end)

-- Execute in batches to prevent performance issues
recipe_transformer:execute_batch(50)
```

## Implementation Roadmap

### Phase 1: List Module Enhancement (v0.3.0)

**Scope**: Extend `khaoslib_list.replace()` to support functional replacements

**Key Changes**:

- Modify `khaoslib_list.replace()` signature to accept functions as `new_item` parameter
- Add comprehensive unit tests for functional replacement patterns
- Update documentation with functional examples

**Implementation Strategy**:

```lua
-- Enhanced replace function signature
khaoslib_list.replace(list, new_item_or_function, compare, options)
-- where new_item_or_function can be:
-- - table: Existing behavior (replace with static value)
-- - function: New behavior (function receives original item, returns transformed item)
```

### Phase 2: Recipe & Technology Module Integration (v0.3.0)

**Scope**: Automatic inheritance of functional replacement support

**Key Changes**:

- Update parameter documentation to reflect functional support
- Add comprehensive examples in module documentation
- Ensure all existing tests pass with enhanced functionality

**Zero Code Changes Required**: Due to delegation architecture, recipe and technology modules automatically inherit functional replacement capabilities.

### Phase 3: Additional Prototype Modules (v0.7.0)

**Scope**: Extend functional patterns to item, fluid, and entity modules

**Key Features**:

- Item property transformations (stack size, icons, flags)
- Fluid property calculations (temperature, viscosity, colors)
- Entity performance scaling (crafting speed, energy consumption)

### Phase 4: Advanced Functional Composition (v0.8.0)

**Scope**: Higher-order functions and composition utilities

**Key Features**:

- Transformation pipeline system
- Functional composition utilities (compose, pipe, when, memoize)
- Lazy evaluation for performance-critical operations

## Conclusion

Functional programming patterns offer significant value for Factorio modding, particularly in:

1. **Dynamic Adaptation**: Transformations that adapt based on game state, installed mods, and settings
2. **Code Reusability**: Elimination of repetitive transformation logic through composable functions
3. **Maintainability**: Clear, declarative expression of transformation intent
4. **Complex Logic**: Handling sophisticated conditional transformation patterns

The proposed implementation strategy builds on khaoslib's existing strong foundation while adding powerful new capabilities that address real-world modding challenges identified in the Pyanodons and Krastorio2 ecosystem analysis.

**Next Steps**: Implementation should follow the roadmap phases, starting with list module enhancement in v0.3.0 to establish the functional programming foundation for the entire khaoslib ecosystem.
