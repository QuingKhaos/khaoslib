-- Functional Replacement API: CompaktCircuit Consolidation Example
-- Demonstrates how callback functions can access and combine multiple ingredient values

local khaoslib_recipe = require("__khaoslib__.recipe")

-- ========================================
-- CURRENT APPROACH (Verbose Multi-Step)
-- ========================================

-- Example 1: Manual extraction and calculation
local recipe = data.raw["recipe"]["compaktprocessor"]
local electronic_circuit_amount = 0
local advanced_circuit_amount = 0
local processing_unit_amount = 0

for _, ingredient in pairs(recipe.ingredients) do
    if ingredient.name == "electronic-circuit" then
        electronic_circuit_amount = ingredient.amount
    elseif ingredient.name == "advanced-circuit" then
        advanced_circuit_amount = ingredient.amount
    elseif ingredient.name == "processing-unit" then
        processing_unit_amount = ingredient.amount
    end
end

-- Replace with combined amount
khaoslib_recipe:load(recipe.name)
    :replace_ingredient("electronic-circuit", {
        type = "item",
        name = "electronic-circuit",
        amount = electronic_circuit_amount + advanced_circuit_amount + processing_unit_amount
    })
    :remove_ingredient("advanced-circuit")
    :remove_ingredient("processing-unit")
    :commit()

-- Example 2: Using static utility functions (better, but still multi-step)
local new_amount =
    khaoslib_recipe.get_ingredient_amount("compaktprocessor", "electronic-circuit") +
    khaoslib_recipe.get_ingredient_amount("compaktprocessor", "advanced-circuit") +
    khaoslib_recipe.get_ingredient_amount("compaktprocessor", "processing-unit")

khaoslib_recipe:load("compaktprocessor")
    :replace_ingredient("electronic-circuit", {type = "item", name = "electronic-circuit", amount = new_amount})
    :remove_ingredient("advanced-circuit")
    :remove_ingredient("processing-unit")
    :commit()

-- ========================================
-- PROPOSED FUNCTIONAL APPROACH
-- ========================================

-- Option 1: Access recipe context within callback (most elegant)
khaoslib_recipe:load("compaktprocessor")
    :replace_ingredient("electronic-circuit", function(ingredient)
        -- Access to current recipe context allows combining multiple ingredients
        local current_recipe = data.raw.recipe["compaktprocessor"]
        local total_circuits = ingredient.amount  -- Start with current electronic-circuit amount

        -- Add amounts from other circuit types that will be removed
        for _, other_ingredient in pairs(current_recipe.ingredients) do
            if other_ingredient.name == "advanced-circuit" then
                total_circuits = total_circuits + other_ingredient.amount
            elseif other_ingredient.name == "processing-unit" then
                total_circuits = total_circuits + other_ingredient.amount
            end
        end

        ingredient.amount = total_circuits
        return ingredient
    end)
    :remove_ingredient("advanced-circuit")
    :remove_ingredient("processing-unit")
    :commit()

-- Option 2: Using static utility functions within callback (cleaner)
khaoslib_recipe:load("compaktprocessor")
    :replace_ingredient("electronic-circuit", function(ingredient)
        -- Combine current amount with other circuit types
        ingredient.amount = ingredient.amount +
            khaoslib_recipe.get_ingredient_amount("compaktprocessor", "advanced-circuit") +
            khaoslib_recipe.get_ingredient_amount("compaktprocessor", "processing-unit")
        return ingredient
    end)
    :remove_ingredient("advanced-circuit")
    :remove_ingredient("processing-unit")
    :commit()

-- Option 3: Generic circuit consolidation function (reusable)
local function consolidate_circuits(ingredient)
    local recipe_name = "compaktprocessor"  -- Could be passed as upvalue

    -- Start with current ingredient amount
    local total_amount = ingredient.amount

    -- Add advanced circuits (2x value since they're more expensive)
    local advanced_amount = khaoslib_recipe.get_ingredient_amount(recipe_name, "advanced-circuit")
    total_amount = total_amount + (advanced_amount * 2)

    -- Add processing units (4x value since they're most expensive)
    local processing_amount = khaoslib_recipe.get_ingredient_amount(recipe_name, "processing-unit")
    total_amount = total_amount + (processing_amount * 4)

    ingredient.amount = total_amount
    return ingredient
end

khaoslib_recipe:load("compaktprocessor")
    :replace_ingredient("electronic-circuit", consolidate_circuits)
    :remove_ingredient("advanced-circuit")
    :remove_ingredient("processing-unit")
    :commit()

-- ========================================
-- ADVANCED: Multi-Recipe Circuit Consolidation
-- ========================================

-- Apply circuit consolidation to multiple CompaktCircuit recipes
local compakt_recipes = {
    "compaktprocessor",
    "compaktcircuit-base",
    "compaktcircuit-advanced",
    "compaktcircuit-processing"
}

-- Reusable consolidation logic
local function create_circuit_consolidator(recipe_name)
    return function(ingredient)
        -- Dynamic consolidation based on what exists in each recipe
        local total = ingredient.amount

        -- Check for advanced circuits
        if khaoslib_recipe.has_ingredient(recipe_name, "advanced-circuit") then
            total = total + (khaoslib_recipe.get_ingredient_amount(recipe_name, "advanced-circuit") * 2)
        end

        -- Check for processing units
        if khaoslib_recipe.has_ingredient(recipe_name, "processing-unit") then
            total = total + (khaoslib_recipe.get_ingredient_amount(recipe_name, "processing-unit") * 4)
        end

        ingredient.amount = total
        return ingredient
    end
end

-- Apply to all CompaktCircuit recipes
for _, recipe_name in ipairs(compakt_recipes) do
    if data.raw.recipe[recipe_name] then
        khaoslib_recipe:load(recipe_name)
            :replace_ingredient("electronic-circuit", create_circuit_consolidator(recipe_name))
            :remove_ingredient("advanced-circuit")
            :remove_ingredient("processing-unit")
            :commit()
    end
end

--[[
BENEFITS OF FUNCTIONAL APPROACH:

1. **Logic Co-location**: Calculation logic is right where it's used
2. **Context Access**: Can reference other ingredients in the same recipe
3. **Reusable Patterns**: Create consolidation functions for similar recipes
4. **Dynamic Calculation**: Handles recipes with different ingredient combinations
5. **Maintainable**: No manual extraction loops or complex pre-processing
6. **Self-Documenting**: The transformation intent is clear from the callback

COMPARISON:
- Current approach: 15+ lines of manual extraction + calculation + application
- Functional approach: 5-8 lines with embedded logic
- Advanced approach: Reusable pattern for multiple similar recipes
--]]