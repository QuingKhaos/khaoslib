-- API Comparison: Current vs Proposed Functional Replacement API
-- Demonstrates practical examples of code improvements

local khaoslib_recipe = require("__khaoslib__.recipe")

-- ========================================
-- SCENARIO 1: Simple Ingredient Replacement
-- ========================================

-- CURRENT APPROACH: Verbose manual extraction
-- Step 1: Extract original amount manually
local recipe = data.raw["recipe"]["aai-signal-transmitter"]
local processing_unit_amount = 0

for _, ingredient in pairs(recipe.ingredients) do
    if ingredient.name == "processing-unit" then
        processing_unit_amount = ingredient.amount
        break
    end
end

-- Step 2: Create replacement with hard-coded structure
khaoslib_recipe:load("aai-signal-transmitter")
    :replace_ingredient("processing-unit", {
        type = "item",
        name = "electronic-circuit",
        amount = processing_unit_amount  -- Manually extracted value
    })
    :commit()

-- PROPOSED APPROACH: Clean and flexible alternatives

-- Option 1: Static replacement (when amount is known)
khaoslib_recipe:load("aai-signal-transmitter")
    :replace_ingredient("processing-unit", {
        type = "item",
        name = "electronic-circuit",
        amount = 3
    })
    :commit()

-- Option 2: Dynamic transformation (preserves original amount automatically)
khaoslib_recipe:load("aai-signal-transmitter")
    :replace_ingredient("processing-unit", function(ingredient)
        ingredient.name = "electronic-circuit"
        -- Amount automatically preserved from original!
        return ingredient
    end)
    :commit()

-- Benefits: 10+ lines -> 3-5 lines, automatic amount preservation, maintainable

-- ========================================
-- SCENARIO 2: Complex Multi-Recipe Transformation
-- ========================================

-- CURRENT APPROACH: External preprocessing required
-- Must extract data from each recipe manually
local recipes_to_process = {"aai-signal-transmitter", "aai-zone-expander"}
local extracted_data = {}

for _, recipe_name in ipairs(recipes_to_process) do
    local recipe = data.raw["recipe"][recipe_name]
    extracted_data[recipe_name] = {}

    for _, ingredient in pairs(recipe.ingredients) do
        if ingredient.name == "processing-unit" then
            extracted_data[recipe_name].processing_unit_amount = ingredient.amount
        end
        if ingredient.name == "advanced-circuit" then
            extracted_data[recipe_name].advanced_circuit_amount = ingredient.amount
        end
    end
end

-- Then apply transformations with hard-coded values
for _, recipe_name in ipairs(recipes_to_process) do
    local data = extracted_data[recipe_name]

    khaoslib_recipe:load(recipe_name)
        :replace_ingredient("processing-unit", {
            type = "item",
            name = "electronic-circuit",
            amount = math.ceil(data.processing_unit_amount * 1.5)
        })
        :replace_ingredient("advanced-circuit", {
            type = "item",
            name = "electronic-circuit",
            amount = data.advanced_circuit_amount
        })
        :commit()
end

-- PROPOSED APPROACH: Direct, clean transformation with embedded logic
local recipes_to_process = {"aai-signal-transmitter", "aai-zone-expander"}

for _, recipe_name in ipairs(recipes_to_process) do
    khaoslib_recipe:load(recipe_name)
        :replace_ingredient("processing-unit", function(ingredient)
            ingredient.name = "electronic-circuit"
            ingredient.amount = math.ceil(ingredient.amount * 1.5)  -- 50% increase
            return ingredient
        end)
        :replace_ingredient("advanced-circuit", function(ingredient)
            ingredient.name = "electronic-circuit"
            -- Amount automatically preserved
            return ingredient
        end)
        :commit()
end

-- Benefits: 30+ lines -> 12 lines, no manual data extraction, self-documenting logic

-- ========================================
-- SCENARIO 3: Performance-Critical Operations
-- ========================================

-- CURRENT APPROACH: Manual optimization required
-- Pre-extract all data to avoid repeated lookups
local bulk_replacements = {}
for recipe_name, recipe in pairs(data.raw.recipe) do
    if string.find(recipe_name, "aai-") then
        for _, ingredient in pairs(recipe.ingredients) do
            if ingredient.name == "processing-unit" then
                bulk_replacements[recipe_name] = {
                    type = "item",
                    name = "electronic-circuit",
                    amount = ingredient.amount * 2
                }
            end
        end
    end
end

-- Apply pre-computed replacements
for recipe_name, replacement in pairs(bulk_replacements) do
    khaoslib_recipe:load(recipe_name)
        :replace_ingredient("processing-unit", replacement)
        :commit()
end

-- PROPOSED APPROACH: Optimized with has_ingredient() check
-- Use has_ingredient() to avoid unnecessary manipulator loading
local multiplier = 2
local replacement = {type = "item", name = "electronic-circuit", amount = 3 * multiplier}

for recipe_name, _ in pairs(data.raw.recipe) do
    if string.find(recipe_name, "aai-") and khaoslib_recipe.has_ingredient(recipe_name, "processing-unit") then
        khaoslib_recipe:load(recipe_name)
            :replace_ingredient("processing-unit", replacement)
            :commit()
    end
end

-- Benefits: Optimal performance, cleaner code, no unnecessary manipulator loading

-- ========================================
-- SCENARIO 4: Conditional Transformations
-- ========================================

-- CURRENT APPROACH: External analysis required
-- Must analyze recipes externally and create complex mapping
local recipe_analysis = {}
for recipe_name, recipe in pairs(data.raw.recipe) do
    local complexity = #recipe.ingredients
    local has_expensive_items = false

    for _, ingredient in pairs(recipe.ingredients) do
        if ingredient.name == "processing-unit" or ingredient.name == "advanced-circuit" then
            has_expensive_items = true
            recipe_analysis[recipe_name] = {
                complexity = complexity,
                expensive = has_expensive_items,
                original_amount = ingredient.amount
            }
        end
    end
end

-- Apply conditional logic externally
for recipe_name, analysis in pairs(recipe_analysis) do
    local replacement
    if analysis.complexity > 5 then
        replacement = {type = "item", name = "electronic-circuit", amount = analysis.original_amount * 2}
    else
        replacement = {type = "item", name = "electronic-circuit", amount = analysis.original_amount}
    end

    khaoslib_recipe:load(recipe_name)
        :replace_ingredient("processing-unit", replacement)
        :commit()
end

-- PROPOSED APPROACH: Embedded intelligence
-- Conditional logic embedded directly in transformation
for recipe_name, recipe in pairs(data.raw.recipe) do
    khaoslib_recipe:load(recipe_name)
        :replace_ingredient("processing-unit", function(ingredient)
            local recipe_complexity = #recipe.ingredients

            ingredient.name = "electronic-circuit"
            if recipe_complexity > 5 then
                ingredient.amount = ingredient.amount * 2  -- Double for complex recipes
            end
            -- Simple recipes keep original amount automatically

            return ingredient
        end)
        :commit()
end

-- Benefits: Logic co-located with transformation, no external analysis required, readable

-- ========================================
-- SUMMARY: API Comparison Results
-- ========================================

--[[
PERFORMANCE COMPARISON SUMMARY:

Code Complexity Reduction:
• Simple replacements: 10+ lines -> 3 lines (70% reduction)
• Complex transformations: 30+ lines -> 12 lines (60% reduction)
• Conditional logic: 25+ lines -> 8 lines (68% reduction)

Performance Improvements:
• has_ingredient() checks: Avoid unnecessary manipulator loading
• Function-based transformations: Automatic optimization vs manual extraction
• Bulk operations: No manual pre-processing required

Maintainability Benefits:
• Logic co-located with transformations
• No manual data extraction required
• Automatic adaptation to recipe changes
• Self-documenting transformation intent

Developer Experience:
• Dramatic reduction in boilerplate code
• Intuitive functional programming patterns
• Consistent API across all replacement operations
• Performance optimizations happen automatically

CONCLUSION: Functional API provides massive improvements in:
1. Code readability and maintainability (60-70% line reduction)
2. Performance (optimized checks prevent wasted work)
3. Developer productivity (eliminate boilerplate)
4. API consistency (same patterns across all modules)
5. Extensible design (can add zero-argument callbacks if real use cases emerge)
--]]
