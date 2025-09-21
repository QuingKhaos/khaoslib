-- Commit-Based Architecture: Recipe State Persistence Example
-- Demonstrates how original recipe remains accessible until commit() is called

local khaoslib_recipe = require("__khaoslib__.recipe")

-- ========================================
-- KEY ARCHITECTURAL ADVANTAGE: DEFERRED COMMIT
-- ========================================

--[[
With the commit-based approach, the original recipe data remains unchanged
until commit() is explicitly called. This means callback functions can
still access the original ingredients even after remove_ingredient() calls.
]]

-- Example: Circuit consolidation where we need ALL original amounts
khaoslib_recipe:load("compaktprocessor")
    -- Step 1: Remove advanced circuits (but original recipe unchanged yet!)
    :remove_ingredient("advanced-circuit")

    -- Step 2: Remove processing units (but original recipe unchanged yet!)
    :remove_ingredient("processing-unit")

    -- Step 3: Replace electronic circuits with consolidated amount
    :replace_ingredient("electronic-circuit", function(ingredient)
        -- CRITICAL: We can still access the original recipe here!
        -- Even though we called remove_ingredient() above, the original
        -- recipe.ingredients table is unchanged until commit()

        local original_recipe = data.raw.recipe["compaktprocessor"]
        local total_circuits = ingredient.amount  -- Start with electronic circuits

        -- Access ingredients that were "removed" but still exist in original
        for _, orig_ingredient in pairs(original_recipe.ingredients) do
            if orig_ingredient.name == "advanced-circuit" then
                total_circuits = total_circuits + (orig_ingredient.amount * 2)
            elseif orig_ingredient.name == "processing-unit" then
                total_circuits = total_circuits + (orig_ingredient.amount * 4)
            end
        end

        ingredient.amount = total_circuits
        return ingredient
    end)

    -- Step 4: NOW the changes are applied to the actual recipe
    :commit()

-- ========================================
-- CONTRAST: Without Commit-Based Architecture
-- ========================================

--[[
If we applied changes immediately, this wouldn't work:

-- HYPOTHETICAL IMMEDIATE-CHANGE API (wouldn't work for consolidation):
khaoslib_recipe:load("recipe")
    :remove_ingredient("advanced-circuit")  -- Recipe modified immediately!
    :replace_ingredient("electronic-circuit", function(ingredient)
        -- advanced-circuit is already gone from recipe - can't access it!
        local advanced_amount = ??? -- No longer available!
    end)

This is why the commit-based architecture is crucial for complex transformations.
]]

-- ========================================
-- PRACTICAL EXAMPLE: Multi-Stage Consolidation
-- ========================================

-- Consolidate multiple ingredient types while preserving access to all originals
khaoslib_recipe:load("advanced-oil-processing")
    -- Remove all the individual oil products (but keep them accessible)
    :remove_ingredient("petroleum-gas")
    :remove_ingredient("light-oil")
    :remove_ingredient("heavy-oil")

    -- Replace with a single "oil-mix" ingredient calculated from all removed items
    :replace_ingredient("crude-oil", function(ingredient)
        local original_recipe = data.raw.recipe["advanced-oil-processing"]
        local total_oil_complexity = ingredient.amount  -- Base crude oil

        -- Access ALL the ingredients we "removed" to calculate complexity
        for _, orig_ingredient in pairs(original_recipe.ingredients) do
            if orig_ingredient.name == "petroleum-gas" then
                total_oil_complexity = total_oil_complexity + (orig_ingredient.amount * 0.1)
            elseif orig_ingredient.name == "light-oil" then
                total_oil_complexity = total_oil_complexity + (orig_ingredient.amount * 0.2)
            elseif orig_ingredient.name == "heavy-oil" then
                total_oil_complexity = total_oil_complexity + (orig_ingredient.amount * 0.3)
            end
        end

        ingredient.amount = math.ceil(total_oil_complexity)
        return ingredient
    end)

    :commit()  -- All changes applied atomically

-- ========================================
-- UTILITY FUNCTIONS BENEFIT FROM THIS TOO
-- ========================================

-- This helper function works because original recipe persists until commit
local function get_total_ingredient_value(recipe_name, ingredient_names_and_multipliers)
    local original_recipe = data.raw.recipe[recipe_name]
    local total_value = 0

    for _, orig_ingredient in pairs(original_recipe.ingredients) do
        for ingredient_name, multiplier in pairs(ingredient_names_and_multipliers) do
            if orig_ingredient.name == ingredient_name then
                total_value = total_value + (orig_ingredient.amount * multiplier)
            end
        end
    end

    return total_value
end

-- Use the utility function in consolidation
khaoslib_recipe:load("compaktprocessor")
    :remove_ingredient("advanced-circuit")
    :remove_ingredient("processing-unit")
    :replace_ingredient("electronic-circuit", function(ingredient)
        -- Calculate consolidated value from all circuit types
        local circuit_values = {
            ["electronic-circuit"] = 1,
            ["advanced-circuit"] = 2,
            ["processing-unit"] = 4
        }

        ingredient.amount = get_total_ingredient_value("compaktprocessor", circuit_values)
        return ingredient
    end)
    :commit()

--[[
ARCHITECTURAL BENEFITS SUMMARY:

1. **State Persistence**: Original recipe unchanged until commit()
2. **Order Independence**: Can remove ingredients before calculating replacements
3. **Complex Calculations**: Access all original data for consolidation math
4. **Atomic Changes**: All modifications applied together or not at all
5. **Utility Function Support**: Helper functions can rely on original state
6. **Error Recovery**: Can abandon changes before commit if validation fails

This is a HUGE advantage over immediate-change APIs and makes complex
ingredient transformations much more elegant and reliable.
]]