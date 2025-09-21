# Unified Static Function Design for Read-Only Operations

## Executive Summary

This document proposes converting read-only functions from object-oriented to static signatures with flexible
parameter types, eliminating API duplication while providing significant performance and usability benefits. The
proposal addresses technical limitations of having both `khaoslib_recipe:has_ingredient()` and
`khaoslib_recipe.has_ingredient()` while creating a unified, more intuitive API.

**Key Benefits:**

- **No API Duplication**: Single function signature for both manipulator and direct access
- **Performance Optimization**: Direct data.raw access without unnecessary deep copies
- **Better Usability**: More intuitive for read-only operations
- **Backward Compatibility**: Existing manipulator calls continue to work unchanged
- **Technical Feasibility**: Solves Lua function naming conflicts elegantly

**Recommendation**: Implement this design as part of v0.2.0 API consistency improvements.

## Problem Analysis

### Current API Duplication Issue

The existing design creates a fundamental conflict:

```lua
-- Current object-oriented approach
function khaoslib_recipe:has_ingredient(compare) -- Method on manipulator
  -- Implementation uses self.recipe
end

-- Proposed static function (from complementary API enhancement)
function khaoslib_recipe.has_ingredient(recipe_data, compare) -- CONFLICT!
  -- Same function name, different signature
end
```

**Problems with this approach:**

- **Lua limitation**: Cannot have both function signatures simultaneously
- **API confusion**: Two different ways to do the same thing
- **Maintenance burden**: Duplicate implementations and tests
- **Performance waste**: Object-oriented version always requires deep copy

### Current Performance Characteristics

```lua
-- Current approach (always involves deep copy)
local recipe = khaoslib_recipe:load("iron-plate")  -- Deep copy allocation
local has_wood = recipe:has_ingredient("wood")     -- Working on copy

-- Memory usage: ~1-5KB allocated per recipe load
-- Use case efficiency: Poor for simple read-only checks
```

## Proposed Solution: Unified Static Functions

### Core Design Principle

Convert read-only functions to static functions that accept flexible parameter types:

```lua
-- New unified signature
function khaoslib_recipe.has_ingredient(recipe, compare)
  -- recipe can be:
  -- 1. data.RecipeID (string) - direct data.raw access
  -- 2. khaoslib.RecipeManipulator - use manipulator's data
  -- 3. data.RecipePrototype - direct prototype data
end
```

### Implementation Strategy

#### Type Detection and Routing

```lua
function khaoslib_recipe.has_ingredient(recipe, compare)
  local recipe_data

  if type(recipe) == "string" then
    -- Direct data.raw access (most efficient)
    recipe_data = data.raw.recipe[recipe]
    if not recipe_data then
      error("Recipe '" .. recipe .. "' does not exist", 2)
    end
  elseif type(recipe) == "table" then
    if getmetatable(recipe) == khaoslib_recipe and recipe._recipe then
      -- khaoslib.RecipeManipulator - use internal recipe data
      recipe_data = recipe._recipe
    elseif recipe.type == "recipe" and recipe.name then
      -- Raw recipe prototype (may be incomplete/draft state)
      recipe_data = recipe
    else
      error("Invalid recipe table: expected manipulator or prototype with type='recipe' and name", 2)
    end
  else
    error("recipe parameter must be string, manipulator, or prototype table", 2)
  end

  -- Unified implementation logic
  return khaoslib_list.has(recipe_data.ingredients, compare)
end
```

### Backward Compatibility Strategy

The key insight is that `obj:method()` is syntactic sugar for `obj.method(obj)`:

```lua
-- These are equivalent due to Lua's colon operator
local recipe = khaoslib_recipe:load("iron-plate")

-- Current usage (will continue to work)
local has_wood_1 = recipe:has_ingredient("wood")

-- Equivalent static call (new capability)
local has_wood_2 = khaoslib_recipe.has_ingredient(recipe, "wood")

-- Direct access (new capability, most efficient)
local has_wood_3 = khaoslib_recipe.has_ingredient("iron-plate", "wood")
```

**Implementation for backward compatibility:**

```lua
-- Remove the current method implementation
-- function khaoslib_recipe:has_ingredient(compare) -- DELETE THIS

-- Add static function that handles both cases
function khaoslib_recipe.has_ingredient(recipe, compare)
  -- Implementation handles all parameter types
end

-- The colon operator automatically provides 'self' as first parameter
-- No additional code needed for backward compatibility!
```

## Detailed API Design

### Recipe Module Static Functions

#### Core Read-Only Functions

```lua
-- Ingredient analysis
khaoslib_recipe.has_ingredient(recipe, compare)
khaoslib_recipe.get_ingredients(recipe)
khaoslib_recipe.count_ingredients(recipe)

-- Result analysis
khaoslib_recipe.has_result(recipe, compare)
khaoslib_recipe.get_results(recipe)
khaoslib_recipe.count_results(recipe)
khaoslib_recipe.count_matching_results(recipe, compare)
khaoslib_recipe.get_matching_results(recipe, compare)

-- Recipe properties
khaoslib_recipe.get_energy_required(recipe)
khaoslib_recipe.get_category(recipe)
khaoslib_recipe.is_enabled(recipe)
```

#### Usage Patterns

```lua
-- Pattern 1: Direct access (new capability, most efficient)
if khaoslib_recipe.has_ingredient("steel-plate", "iron-plate") then
  -- No deep copy, direct data.raw access
end

-- Pattern 2: Manipulator-based (existing pattern, still works)
local recipe = khaoslib_recipe:load("steel-plate")
if recipe:has_ingredient("iron-plate") then  -- Equivalent to above
  -- Works because recipe:method() = khaoslib_recipe.method(recipe)
end

-- Pattern 3: Bulk analysis (new efficient pattern)
local iron_recipes = {}
for recipe_name, recipe_data in pairs(data.raw.recipe) do
  if khaoslib_recipe.has_ingredient(recipe_data, "iron-ore") then
    table.insert(iron_recipes, recipe_name)
  end
end
-- No allocations during loop!
```

### Technology Module Static Functions

#### Core Read-Only Functions

```lua
-- Prerequisite analysis
khaoslib_technology.has_prerequisite(technology, compare)
khaoslib_technology.get_prerequisites(technology)
khaoslib_technology.count_prerequisites(technology)

-- Effect analysis
khaoslib_technology.has_effect(technology, compare)
khaoslib_technology.get_effects(technology)
khaoslib_technology.count_effects(technology)

-- Science pack analysis
khaoslib_technology.has_science_pack(technology, compare)
khaoslib_technology.get_science_packs(technology)

-- Convenience functions (already exist as static)
khaoslib_technology.exists(technology_name)
khaoslib_technology.find(filter_function)
```

## Implementation Plan

### Phase 1: Recipe Module Conversion (High Priority)

**Target Functions:**

- `has_ingredient` → `khaoslib_recipe.has_ingredient(recipe, compare)`
- `get_ingredients` → `khaoslib_recipe.get_ingredients(recipe)`
- `count_ingredients` → `khaoslib_recipe.count_ingredients(recipe)`
- `has_result` → `khaoslib_recipe.has_result(recipe, compare)`
- `get_results` → `khaoslib_recipe.get_results(recipe)`
- `count_results` → `khaoslib_recipe.count_results(recipe)`
- `count_matching_results` → `khaoslib_recipe.count_matching_results(recipe, compare)`
- `get_matching_results` → `khaoslib_recipe.get_matching_results(recipe, compare)`

**Implementation Steps:**

1. Replace method implementations with static function implementations
2. Add parameter type detection and routing logic
3. Update documentation with new usage patterns
4. Add comprehensive tests for all parameter types
5. Verify backward compatibility with existing test suite

**Estimated Time:** 2-3 days

### Phase 2: Technology Module Conversion (High Priority)

**Target Functions:**

- `has_prerequisite` → `khaoslib_technology.has_prerequisite(technology, compare)`
- `get_prerequisites` → `khaoslib_technology.get_prerequisites(technology)`
- `count_prerequisites` → `khaoslib_technology.count_prerequisites(technology)`
- `has_effect` → `khaoslib_technology.has_effect(technology, compare)`
- `get_effects` → `khaoslib_technology.get_effects(technology)`
- `count_effects` → `khaoslib_technology.count_effects(technology)`

**Implementation Steps:**

1. Apply same conversion pattern as Recipe module
2. Ensure consistency with existing `exists` and `find` static functions
3. Update documentation and tests
4. Add missing `exists` and `find` functions to Recipe module for consistency

**Estimated Time:** 2-3 days

### Phase 3: Documentation and Examples (Medium Priority)

**Documentation Updates:**

1. **Performance guidelines**: When to use direct access vs manipulators
2. **Migration examples**: Converting existing code to use efficient patterns
3. **Best practices**: Choosing the right approach for different scenarios
4. **API reference**: Complete parameter type documentation

**Estimated Time:** 1-2 days

### Phase 4: Discovery Functions (Lower Priority)

**Additional static functions for enhanced discovery:**

```lua
-- Recipe discovery
khaoslib_recipe.find_by_ingredient(ingredient_name)
khaoslib_recipe.find_by_result(result_name)
khaoslib_recipe.find_by_category(category_name)

-- Technology discovery
khaoslib_technology.find_by_prerequisite(prereq_name)
khaoslib_technology.find_by_unlock_recipe(recipe_name)
```

**Estimated Time:** 1-2 days

## Performance Analysis

### Memory Usage Comparison

```lua
-- Current approach (always allocates)
local recipe = khaoslib_recipe:load("iron-plate")  -- ~2KB allocation
local has_wood = recipe:has_ingredient("wood")     -- Using allocated copy

-- New direct access approach (zero allocation)
local has_wood = khaoslib_recipe.has_ingredient("iron-plate", "wood")  -- Direct data.raw access

-- Memory savings: ~2KB per recipe check
-- Performance improvement: Eliminates deep copy overhead
```

### Batch Operation Efficiency

```lua
-- Current approach (inefficient for batch analysis)
local iron_recipes = {}
for recipe_name, _ in pairs(data.raw.recipe) do
  local recipe = khaoslib_recipe:load(recipe_name)  -- 2KB * 500 recipes = 1MB allocated
  if recipe:has_ingredient("iron-ore") then
    table.insert(iron_recipes, recipe_name)
  end
end
-- Total allocation: ~1MB for 500 recipes

-- New approach (efficient)
local iron_recipes = {}
for recipe_name, recipe_data in pairs(data.raw.recipe) do
  if khaoslib_recipe.has_ingredient(recipe_data, "iron-ore") then  -- Zero allocation
    table.insert(iron_recipes, recipe_name)
  end
end
-- Total allocation: ~0KB for analysis
```

## Error Handling Strategy

### Parameter Validation Rationale

The validation approach focuses on essential prototype identification rather than completeness:

- **String IDs**: Direct validation against `data.raw.recipe[name]` existence
- **Manipulator objects**: Identified using `getmetatable()` for proper type checking and `._recipe` field for
  internal state access
- **Raw prototypes**: Validated using `type == "recipe"` and `name` field presence

**Improved Manipulator Detection**: Using `getmetatable(recipe) == khaoslib_recipe and recipe._recipe` provides:

- **Proper type safety**: Ensures we're dealing with actual khaoslib manipulator objects
- **Better encapsulation**: Uses `_recipe` prefix following Lua conventions for private properties
- **Robust validation**: Prevents false positives from tables that happen to have a `recipe` field

This approach supports **draft/incomplete prototypes** that may be missing fields like `ingredients`
during construction or modification phases, while still ensuring the prototype can be properly identified
and processed.

### Parameter Validation

```lua
function khaoslib_recipe.has_ingredient(recipe, compare)
  -- Validate and normalize recipe parameter
  local recipe_data = normalize_recipe_parameter(recipe)
  if not recipe_data then
    error("Invalid recipe parameter: expected string ID, manipulator, or prototype table", 2)
  end

  -- Validate compare parameter (same as current implementation)
  if not compare then
    error("compare parameter is required", 2)
  end

  -- Use existing comparison logic
  return khaoslib_list.has(recipe_data.ingredients, compare)
end

function normalize_recipe_parameter(recipe)
  if type(recipe) == "string" then
    local recipe_data = data.raw.recipe[recipe]
    if not recipe_data then
      error("Recipe '" .. recipe .. "' does not exist", 3)
    end
    return recipe_data
  elseif type(recipe) == "table" then
    if getmetatable(recipe) == khaoslib_recipe and recipe._recipe then
      -- khaoslib.RecipeManipulator
      return recipe._recipe
    elseif recipe.type == "recipe" and recipe.name then
      -- Raw recipe prototype (may be incomplete/draft state)
      -- Only validate essential fields: type and name are required for prototype identification
      -- Other fields like ingredients may be missing in draft/construction state
      return recipe
    else
      return nil -- Invalid table format
    end
  else
    return nil -- Invalid parameter type
  end
end
```

### Consistent Error Messages

All error messages should follow the established khaoslib patterns:

```lua
-- Parameter type errors
"recipe parameter: expected string ID, manipulator, or prototype table, got " .. type(recipe)

-- Missing recipe errors
"Recipe '" .. recipe_name .. "' does not exist"

-- Missing parameter errors
"compare parameter is required"
```

## Migration Strategy

### Backward Compatibility Guarantee

**All existing code continues to work unchanged:**

```lua
-- Existing code (continues to work)
local recipe = khaoslib_recipe:load("iron-plate")
if recipe:has_ingredient("iron-ore") then
  -- This still works because recipe:has_ingredient("iron-ore")
  -- becomes khaoslib_recipe.has_ingredient(recipe, "iron-ore")
end
```

### Recommended Migration Patterns

**For read-only operations, prefer direct access:**

```lua
-- Old pattern (still works, but less efficient)
local recipe = khaoslib_recipe:load("iron-plate")
if recipe:has_ingredient("iron-ore") then
  local ingredients = recipe:get_ingredients()
end

-- New recommended pattern (more efficient)
if khaoslib_recipe.has_ingredient("iron-plate", "iron-ore") then
  local ingredients = khaoslib_recipe.get_ingredients("iron-plate")
end

-- For complex workflows, load once and reuse
local recipe = khaoslib_recipe:load("iron-plate")
if recipe:has_ingredient("iron-ore") then
  recipe:remove_ingredient("iron-ore")
    :add_ingredient({type = "item", name = "processed-iron-ore", amount = 1})
    :commit()
end
```

## Testing Strategy

### Test Coverage Requirements

1. **Parameter type handling**: Test all supported parameter types
2. **Backward compatibility**: Ensure existing tests continue to pass
3. **Performance verification**: Benchmark new vs old approaches
4. **Error handling**: Validate error messages and edge cases

### Test Implementation

```lua
-- Test parameter type flexibility
function TestRecipeModule:test_has_ingredient_parameter_types()
  -- Test with string ID
  luaunit.assertTrue(khaoslib_recipe.has_ingredient("iron-plate", "iron-ore"))

  -- Test with manipulator
  local recipe = khaoslib_recipe:load("iron-plate")
  luaunit.assertTrue(khaoslib_recipe.has_ingredient(recipe, "iron-ore"))

  -- Test with raw prototype
  local recipe_data = data.raw.recipe["iron-plate"]
  luaunit.assertTrue(khaoslib_recipe.has_ingredient(recipe_data, "iron-ore"))

  -- Test backward compatibility (colon operator)
  luaunit.assertTrue(recipe:has_ingredient("iron-ore"))
end
```

## Feedback on Proposal

### Strengths of This Approach

1. **Elegant Technical Solution**: Solves the function naming conflict perfectly using Lua's colon operator semantics

2. **Significant Performance Benefits**: Direct data.raw access eliminates unnecessary allocations for read-only operations

3. **Backward Compatibility**: Existing code continues to work without changes

4. **Intuitive API Design**: Read-only operations feel more natural as static functions

5. **Unified Implementation**: Single implementation handles all use cases, reducing maintenance burden

6. **Flexible Parameter Types**: Supports efficient direct access while maintaining manipulator compatibility

### Potential Concerns and Mitigations

1. **Learning Curve**: Developers need to understand when to use direct access vs manipulators
   - **Mitigation**: Clear documentation with performance guidelines and examples

2. **API Consistency**: Mixing static and instance methods might feel inconsistent
   - **Mitigation**: Read-only operations being static actually makes the API more semantic

3. **Parameter Validation Overhead**: Type detection adds small runtime cost
   - **Mitigation**: Type detection is minimal compared to deep copy elimination

4. **Testing Complexity**: Need to test multiple parameter types for each function
   - **Mitigation**: Systematic test patterns can be reused across functions

### Recommendations for Implementation

1. **Prioritize Recipe Module**: Recipe module has more read-only functions and bigger performance impact

2. **Comprehensive Documentation**: Include performance comparisons and clear usage guidelines

3. **Gradual Rollout**: Implement and test one module at a time to validate the approach

4. **Performance Benchmarks**: Measure and document the performance improvements

5. **Community Education**: Provide migration examples and best practices

## Conclusion

This proposal represents an excellent evolution of the khaoslib API design. It solves real technical limitations
while providing significant performance benefits for common use cases. The approach is elegant, backward-compatible,
and aligns well with the principle of making read-only operations efficient while maintaining the power of
manipulators for modification workflows.

The unified static function design should be implemented as part of the v0.2.0 API consistency improvements, as it
directly addresses module consistency while providing tangible performance benefits.

**Recommendation**: Proceed with implementation in the proposed phases, starting with the Recipe module to validate
the approach and measure performance improvements.
