-- Advanced Recipe Transformation Examples
-- Demonstrates sophisticated functional replacement patterns

local khaoslib_recipe = require("__khaoslib__..recipe")

-- Example 1: Multi-Recipe Batch Processing with Conditional Logic
print("=== Example 1: Intelligent Recipe Balancing ===")

-- Define rebalancing rules based on recipe complexity
local function create_ingredient_rebalancer(target_difficulty)
    return function(ingredient)
        local expensive_items = {
            ["processing-unit"] = 10,
            ["advanced-circuit"] = 6,
            ["electronic-circuit"] = 3,
            ["copper-cable"] = 1,
            ["iron-plate"] = 1
        }

        local complexity_score = expensive_items[ingredient.name] or 2

        if complexity_score > target_difficulty then
            -- Replace expensive items with cheaper alternatives
            local replacements = {
                ["processing-unit"] = "electronic-circuit",
                ["advanced-circuit"] = "electronic-circuit"
            }

            if replacements[ingredient.name] then
                ingredient.name = replacements[ingredient.name]
                -- Compensate with increased quantity
                ingredient.amount = math.ceil(ingredient.amount * (complexity_score / target_difficulty))
            end
        end

        return ingredient
    end
end

-- Apply intelligent rebalancing to AAI mod recipes
local aai_recipes = {"aai-signal-transmitter", "aai-zone-expander", "aai-data-storage-tank"}
local target_difficulty = 4  -- Medium complexity target

for _, recipe_name in ipairs(aai_recipes) do
    if data.raw.recipe[recipe_name] then
        print("Rebalancing recipe: " .. recipe_name)

        khaoslib_recipe:load(recipe_name)
            :replace_ingredient("processing-unit", create_ingredient_rebalancer(target_difficulty))
            :replace_ingredient("advanced-circuit", create_ingredient_rebalancer(target_difficulty))
            :commit()
    end
end

-- Example 2: Dynamic Scaling Based on Recipe Context
print("\n=== Example 2: Context-Aware Recipe Scaling ===")

-- Scale ingredients based on recipe's total material cost
local function create_context_aware_scaler(recipe_name)
    return function(ingredient)
        local recipe = data.raw.recipe[recipe_name]
        local total_ingredients = #recipe.ingredients

        -- Scale expensive ingredients down in complex recipes
        if total_ingredients > 5 and ingredient.name == "processing-unit" then
            ingredient.name = "advanced-circuit"
            ingredient.amount = math.max(1, math.floor(ingredient.amount * 0.75))
            print(string.format("  Scaled %s in complex recipe %s", ingredient.name, recipe_name))
        elseif total_ingredients <= 3 and ingredient.amount > 1 then
            -- Increase amounts in simple recipes for balance
            ingredient.amount = math.ceil(ingredient.amount * 1.2)
            print(string.format("  Increased %s amount in simple recipe %s", ingredient.name, recipe_name))
        end

        return ingredient
    end
end

-- Apply context-aware scaling
local test_recipes = {"electronic-circuit", "aai-signal-transmitter", "advanced-circuit"}
for _, recipe_name in ipairs(test_recipes) do
    if data.raw.recipe[recipe_name] then
        khaoslib_recipe:load(recipe_name)
            :replace_ingredient("processing-unit", create_context_aware_scaler(recipe_name))
            :replace_ingredient("copper-cable", create_context_aware_scaler(recipe_name))
            :commit()
    end
end

-- Example 3: Progressive Difficulty Adjustment
print("\n=== Example 3: Progressive Difficulty Curve ===")

-- Create difficulty tiers for different game phases
local difficulty_tiers = {
    early = {max_complexity = 3, expensive_threshold = 5},
    mid = {max_complexity = 6, expensive_threshold = 8},
    late = {max_complexity = 10, expensive_threshold = 15}
}

local function create_tier_appropriate_replacement(tier_name)
    local tier = difficulty_tiers[tier_name]

    return function(ingredient)
        local item_costs = {
            ["wood"] = 1,
            ["iron-plate"] = 1,
            ["copper-plate"] = 1,
            ["steel-plate"] = 2,
            ["electronic-circuit"] = 3,
            ["advanced-circuit"] = 6,
            ["processing-unit"] = 12
        }

        local ingredient_cost = item_costs[ingredient.name] or 5
        local effective_cost = ingredient_cost * ingredient.amount

        if effective_cost > tier.expensive_threshold then
            print(string.format("  Tier %s: Replacing expensive %s (cost: %d)",
                tier_name, ingredient.name, effective_cost))

            -- Find appropriate replacement for this tier
            for replacement, cost in pairs(item_costs) do
                if cost <= tier.max_complexity and cost < ingredient_cost then
                    ingredient.name = replacement
                    -- Adjust amount to maintain relative value
                    ingredient.amount = math.ceil(effective_cost / cost)
                    break
                end
            end
        end

        return ingredient
    end
end

-- Apply progressive difficulty to different recipe categories
local recipe_categories = {
    early = {"inserter", "transport-belt", "burner-inserter"},
    mid = {"electronic-circuit", "assembling-machine-1", "lab"},
    late = {"advanced-circuit", "processing-unit", "rocket-part"}
}

for tier_name, recipes in pairs(recipe_categories) do
    print(string.format("Applying %s tier adjustments:", tier_name))

    for _, recipe_name in ipairs(recipes) do
        if data.raw.recipe[recipe_name] then
            khaoslib_recipe:load(recipe_name)
                :replace_ingredient("processing-unit", create_tier_appropriate_replacement(tier_name))
                :replace_ingredient("advanced-circuit", create_tier_appropriate_replacement(tier_name))
                :commit()
        end
    end
end

-- Example 4: Performance-Optimized Bulk Operations
print("\n=== Example 4: High-Performance Bulk Transformations ===")

-- Pre-compute replacement mappings for optimal performance
local bulk_replacements = {
    -- Pyanodons compatibility mappings
    pyanodons = {
        ["processing-unit"] = {type = "item", name = "electronic-circuit", amount = 4},
        ["advanced-circuit"] = {type = "item", name = "electronic-circuit", amount = 2},
        ["low-density-structure"] = {type = "item", name = "steel-plate", amount = 6}
    },

    -- Early game accessibility mappings
    early_game = {
        ["steel-plate"] = {type = "item", name = "iron-plate", amount = 3},
        ["advanced-circuit"] = {type = "item", name = "electronic-circuit", amount = 2}
    }
}-- Apply high-performance bulk transformations using has_ingredient() optimization
local mod_prefixes = {"aai-", "py", "bob-", "angel-"}
local processed_count = 0

for recipe_name, _ in pairs(data.raw.recipe) do
    -- Check if recipe belongs to specific mods
    for _, prefix in ipairs(mod_prefixes) do
        if string.find(recipe_name, prefix) then
            -- Apply Pyanodons compatibility using optimized approach
            for ingredient_name, replacement in pairs(bulk_replacements.pyanodons) do
                if khaoslib_recipe.has_ingredient(recipe_name, ingredient_name) then
                    processed_count = processed_count + 1
                    khaoslib_recipe:load(recipe_name)
                        :replace_ingredient(ingredient_name, replacement)
                        :commit()
                end
            end

            break
        end
    end
end

print(string.format("Applied high-performance transformations to %d ingredients", processed_count))-- Example 5: Advanced Conditional Transformations
print("\n=== Example 5: Multi-Condition Recipe Intelligence ===")

-- Sophisticated transformation logic with multiple conditions
local function create_intelligent_transformer(options)
    options = options or {}
    local preserve_ratios = options.preserve_ratios or true
    local max_amount_increase = options.max_amount_increase or 3
    local compatibility_mode = options.compatibility_mode or "pyanodons"

    return function(ingredient)
        local original_ingredient = {
            name = ingredient.name,
            amount = ingredient.amount,
            type = ingredient.type
        }

        -- Compatibility-specific logic
        if compatibility_mode == "pyanodons" then
            local py_replacements = {
                ["processing-unit"] = {name = "electronic-circuit", multiplier = 2.5},
                ["advanced-circuit"] = {name = "electronic-circuit", multiplier = 1.5},
                ["rocket-fuel"] = {name = "solid-fuel", multiplier = 4}
            }

            local replacement = py_replacements[ingredient.name]
            if replacement then
                ingredient.name = replacement.name

                if preserve_ratios then
                    local new_amount = math.ceil(ingredient.amount * replacement.multiplier)
                    ingredient.amount = math.min(new_amount, ingredient.amount * max_amount_increase)
                end

                print(string.format("  Pyanodons: %s (%d) -> %s (%d)",
                    original_ingredient.name, original_ingredient.amount,
                    ingredient.name, ingredient.amount))
            end
        end

        -- Additional conditions can be added here for other compatibility modes

        return ingredient
    end
end

-- Apply intelligent transformations with different configurations
local intelligence_configs = {
    conservative = {preserve_ratios = true, max_amount_increase = 2, compatibility_mode = "pyanodons"},
    aggressive = {preserve_ratios = false, max_amount_increase = 5, compatibility_mode = "pyanodons"},
    balanced = {preserve_ratios = true, max_amount_increase = 3, compatibility_mode = "pyanodons"}
}

local target_recipes = {"aai-signal-transmitter", "rocket-part", "satellite"}

for config_name, config in pairs(intelligence_configs) do
    print(string.format("Applying %s configuration:", config_name))

    for _, recipe_name in ipairs(target_recipes) do
        if data.raw.recipe[recipe_name] then
            khaoslib_recipe:load(recipe_name)
                :replace_ingredient("processing-unit", create_intelligent_transformer(config))
                :replace_ingredient("rocket-fuel", create_intelligent_transformer(config))
                :commit()
        end
    end
end

print("\n=== Advanced Functional Replacement Examples Completed ===")
print("These examples demonstrate the power and flexibility of the functional replacement API:")
print("1. Context-aware transformations based on recipe complexity")
print("2. Progressive difficulty scaling for different game phases")
print("3. High-performance bulk operations with zero-argument callbacks")
print("4. Intelligent multi-condition replacement logic")
print("5. Configurable transformation strategies for different mod compatibility needs")
