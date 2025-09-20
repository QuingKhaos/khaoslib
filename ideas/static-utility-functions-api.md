# Static Utility Functions as Complementary API Enhancement

## Executive Summary

Analysis of the Factorio modding ecosystem reveals that the current manipulator-first API design
is well-aligned with actual usage patterns, where mods primarily focus on creating and modifying
prototypes rather than analyzing existing data. However, there are compelling use cases for adding
static utility functions as a complementary addition to handle occasional analysis needs more efficiently.

**Key Findings:**

- **Current API**: Manipulator-first approach is optimal for the modification-heavy Factorio modding ecosystem
- **Modding Reality**: Analysis of 4000+ mods shows Content (2072), Overhaul (117), and Tweaks (2039)
  categories are primarily write-heavy
- **Complementary Opportunity**: Static utilities can efficiently handle occasional analysis needs
  without replacing core manipulator approach
- **Recommended Solution**: Add static utility functions alongside existing manipulator API for specific use cases

**Implementation Priority:** MEDIUM - With v0.2.0 pre-release status, we can add static utilities
as a complementary enhancement without disrupting the proven manipulator-first design that aligns
with actual Factorio modding patterns.

## Background: Understanding Factorio Modding Patterns

### Current API Philosophy (Well-Designed for Modding)

Khaoslib was designed with a "manipulator-first" approach where all operations go through
manipulator objects, which aligns well with Factorio modding patterns:

```lua
-- Current recommended pattern
local recipe = khaoslib_recipe:load("iron-plate")  -- Deep copy allocated
if recipe:has_ingredient("iron-ore") then          -- Working on copy
  local ingredients = recipe:get_ingredients()     -- Another deep copy
end
```

**Strengths of This Design for Factorio Modding:**

- **Modification-Focused**: Optimized for the primary modding activity (changing prototypes)
- **Safety**: Isolated copies prevent accidental mutations of game data
- **Fluent Interface**: Method chaining enables complex modifications in readable code
- **Consistency**: Same interface works for creation, modification, and complex operations

### Factorio Modding Ecosystem Analysis

Analysis of the Factorio mod portal reveals the actual usage patterns:

**Mod Categories and Their Patterns:**

- **Content Mods (2072)**: Primarily add new recipes, items, technologies - **Creation-Heavy**
- **Overhaul Mods (117)**: Massively modify existing systems, add new content - **Modification-Heavy**
- **Tweaks Mods (2039)**: Balance and gameplay adjustments to existing content - **Modification-Heavy**

**Actual Usage Patterns:**

- **Dominant pattern**: Modification and creation of prototypes (what manipulators excel at)
- **Secondary pattern**: Conditional modifications based on existing content analysis
- **Occasional pattern**: Pure analysis for compatibility checking or discovery

**Why Manipulator-First Design Is Optimal:**

- Most operations involve changing prototype data, not just reading it
- Complex overhaul mods (like Pyanodons) built their own manipulator libraries
- Method chaining supports complex modification workflows elegantly

**Memory Characteristics:**

- Large modpacks can have 500+ recipes
- Each recipe can be 1-5KB of data
- Analysis operations don't need data isolation
- Temporary allocations are freed after startup

### The Niche Use Case: Pure Analysis

While modification is the dominant pattern, there are specific scenarios where pure analysis
would benefit from a more efficient approach:

```lua
-- Example: Compatibility mod scanning for conflicts (uncommon but real use case)
local wood_recipes = {}
for recipe_name, _ in pairs(data.raw.recipe) do
  local recipe = khaoslib_recipe:load(recipe_name)  -- Deep copy: significant allocation
  if recipe:has_ingredient("wood") then             -- Simple boolean check on copy
    table.insert(wood_recipes, recipe_name)
  end
  -- Manipulator discarded, memory wasted for analysis-only operation
end

-- This is inefficient when you only need the analysis, not modification capability
-- But this represents a minority of actual khaoslib usage patterns
```

## Proposed Enhancement: Complementary Static Utility Functions

### Core Concept

Add module-level static functions alongside the existing manipulator API to efficiently handle
the occasional pure analysis use cases:

```lua
-- Efficient analysis pattern (for the occasional pure analysis scenario)
local wood_recipes = {}
for recipe_name, recipe_data in pairs(data.raw.recipe) do
  if khaoslib_recipe.has_ingredient(recipe_data, "wood") then  -- Direct data.raw access
    table.insert(wood_recipes, recipe_name)
  end
end

-- Or even better: dedicated discovery functions
local wood_recipes = khaoslib_recipe.find_by_ingredient("wood")

-- Memory allocation: Only for results, no temporary manipulator objects
-- Use case: Analysis-only scenarios (minority of khaoslib usage)
```

### Proposed Static API

#### Recipe Module Static Functions

```lua
-- Ingredient analysis (most common operations)
khaoslib_recipe.has_ingredient(recipe_data, ingredient_name)
khaoslib_recipe.has_ingredient(recipe_data, comparison_function)
khaoslib_recipe.get_ingredients(recipe_data)
khaoslib_recipe.count_ingredients(recipe_data)
khaoslib_recipe.get_ingredient_amount(recipe_data, ingredient_name)

-- Result analysis
khaoslib_recipe.has_result(recipe_data, result_name)
khaoslib_recipe.has_result(recipe_data, comparison_function)
khaoslib_recipe.get_results(recipe_data)
khaoslib_recipe.count_results(recipe_data)
khaoslib_recipe.count_matching_results(recipe_data, comparison)

-- Discovery utilities (high-value for modpack compatibility)
khaoslib_recipe.find_by_ingredient(ingredient_name)
khaoslib_recipe.find_by_ingredient(comparison_function)
khaoslib_recipe.find_by_result(result_name)
khaoslib_recipe.find_by_category(category_name)
khaoslib_recipe.find_by_energy_required(min_energy, max_energy)

-- Recipe validation and analysis
khaoslib_recipe.is_enabled(recipe_data)
khaoslib_recipe.get_crafting_category(recipe_data)
khaoslib_recipe.get_energy_required(recipe_data)
khaoslib_recipe.uses_fluid_ingredients(recipe_data)
khaoslib_recipe.produces_fluid_results(recipe_data)
```

#### Technology Module Static Functions

```lua
-- Prerequisite analysis
khaoslib_technology.has_prerequisite(tech_data, prereq_name)
khaoslib_technology.has_prerequisite(tech_data, comparison_function)
khaoslib_technology.get_prerequisites(tech_data)
khaoslib_technology.count_prerequisites(tech_data)

-- Effect analysis
khaoslib_technology.has_effect(tech_data, comparison_function)
khaoslib_technology.get_effects(tech_data)
khaoslib_technology.get_unlock_recipes(tech_data)
khaoslib_technology.unlocks_recipe(tech_data, recipe_name)

-- Science pack analysis
khaoslib_technology.has_science_pack(tech_data, science_pack_name)
khaoslib_technology.get_science_packs(tech_data)
khaoslib_technology.get_total_science_cost(tech_data)

-- Discovery utilities
khaoslib_technology.find_by_prerequisite(prereq_name)
khaoslib_technology.find_by_unlock_recipe(recipe_name)
khaoslib_technology.find_by_science_pack(science_pack_name)
khaoslib_technology.find_research_path(from_tech, to_tech)
```

### Usage Pattern Guidelines

#### Pattern 1: Pure Analysis (Good Use Case for Static Functions)

```lua
-- GOOD USE CASE: Static utilities for analysis-only scenarios
local compatibility_report = {
  wood_recipes = khaoslib_recipe.find_by_ingredient("wood"),
  fluid_recipes = khaoslib_recipe.find_by_ingredient(function(ing) return ing.type == "fluid" end),
  complex_recipes = khaoslib_recipe.find_by_ingredient_count(5, nil), -- 5+ ingredients
  expensive_recipes = khaoslib_recipe.find_by_energy_required(10, nil), -- 10+ seconds
}

-- Memory usage: Minimal (only result data)
-- Performance: Good for pure analysis scenarios
-- Use case: Compatibility checking, mod analysis tools
-- Note: This is a minority use case in typical Factorio modding
```

#### Pattern 2: Discovery + Selective Modification (Excellent Hybrid Use Case)

```lua
-- EXCELLENT USE CASE: Static discovery + manipulator modification
local iron_recipes = khaoslib_recipe.find_by_ingredient("iron-ore")

for _, recipe_name in ipairs(iron_recipes) do
  -- Only create manipulator when modification is needed
  khaoslib_recipe:load(recipe_name)
    :replace_ingredient("iron-ore", {type = "item", name = "processed-iron-ore", amount = 1})
    :commit()
end

-- Memory usage: Efficient (manipulators only for modified recipes)
-- Performance: Good (lightweight discovery, targeted modification)
-- Pattern: This combines the best of both approaches
-- Use case: Common in overhaul and tweak mods
```

#### Pattern 3: Bulk Modification (Keep Using Manipulators)

```lua
-- CURRENT APPROACH REMAINS OPTIMAL: Manipulators for bulk modifications
for recipe_name, recipe_data in pairs(data.raw.recipe) do
  if has_complex_modification_logic(recipe_data) then
    khaoslib_recipe:load(recipe_name)
      :multiply_ingredient_amounts(2.0)
      :set_energy_required(recipe_data.energy_required * 1.5)
      :add_ingredient({type = "item", name = "complexity-token", amount = 1})
      :commit()
  end
end

-- Memory usage: Reasonable (manipulators created as needed for modifications)
-- Performance: Good (optimized for the primary use case)
-- Pattern: This is the bread and butter of Factorio modding
-- Use case: The majority of khaoslib usage scenarios
```

## Implementation Strategy

### Phase 1: Discovery Functions (High Priority)

Implement discovery functions that complement the existing manipulator API:

1. **Recipe discovery**: `find_by_ingredient`, `find_by_result`, `find_by_category`
2. **Technology discovery**: `find_by_prerequisite`, `find_by_unlock_recipe`
3. **Batch analysis**: `count_by_ingredient`, `analyze_complexity`
4. **Compatibility utilities**: Functions commonly needed by compatibility mods

**Estimated Implementation Time**: 2-3 days
**Expected Benefits**: Efficient discovery for hybrid workflows

### Phase 2: Analysis Utilities (Lower Priority)

Add analysis functions for pure analysis scenarios:

1. **Property checking**: `has_ingredient`, `has_result`, `get_energy_required`
2. **Compatibility utilities**: Common compatibility mod patterns
3. **Validation functions**: Recipe/technology consistency checking

**Estimated Implementation Time**: 1-2 weeks
**Expected Benefits**: Support for compatibility and debugging tools

### Phase 3: Documentation and Examples (High Priority)

Document the complementary nature of static utilities:

1. **Usage patterns**: When to use static functions vs manipulators
2. **Hybrid examples**: Discovery + modification workflows
3. **Best practices**: Leveraging both approaches effectively

**Estimated Implementation Time**: 1 week
**Expected Benefits**: Clear guidance on using both APIs optimally

### Phase 4: Integration (Ongoing)

Ensure static functions work well alongside manipulators:

1. **Consistent interfaces**: Static functions use same parameter patterns as manipulators
2. **Data compatibility**: Static functions return data compatible with manipulator input
3. **Clear use cases**: Documentation clearly explains when to use each approach
4. **Performance validation**: Benchmarks confirm benefits for intended use cases

## Technical Implementation Details

### Function Signatures and Error Handling

```lua
-- Static functions should mirror manipulator behavior but work with data.raw directly
function khaoslib_recipe.has_ingredient(recipe_data, compare)
  -- Parameter validation
  if type(recipe_data) ~= "table" then
    error("recipe_data parameter: Expected table, got " .. type(recipe_data), 2)
  end
  if type(compare) ~= "string" and type(compare) ~= "function" then
    error("compare parameter: Expected string or function, got " .. type(compare), 2)
  end

  -- Use same logic as manipulator version, but work directly with data
  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.name == compare end
  end

  return khaoslib_list.has(recipe_data.ingredients, compare_fn)
end

-- Discovery functions return arrays of names (consistent with current patterns)
function khaoslib_recipe.find_by_ingredient(compare)
  local results = {}
  for recipe_name, recipe_data in pairs(data.raw.recipe) do
    if khaoslib_recipe.has_ingredient(recipe_data, compare) then
      table.insert(results, recipe_name)
    end
  end
  return results
end
```

### Data Safety and Immutability

Static functions must ensure they don't accidentally mutate `data.raw`:

```lua
-- Always return deep copies of mutable data
function khaoslib_recipe.get_ingredients(recipe_data)
  if type(recipe_data) ~= "table" then
    error("recipe_data parameter: Expected table, got " .. type(recipe_data), 2)
  end

  -- Return deep copy to prevent accidental mutation
  return util.table.deepcopy(recipe_data.ingredients or {})
end

-- Read-only checks can work directly with data (no mutation risk)
function khaoslib_recipe.has_ingredient(recipe_data, compare)
  -- Safe to work directly with data.raw for read-only operations
  -- No copying needed for boolean results
end
```

### Performance Testing and Benchmarks

**Note**: The performance improvements described in this document are theoretical projections
based on analysis of the different approaches. Actual benefits should be validated through
comprehensive benchmarking.

Implement comprehensive benchmarks to measure actual performance improvements:

```lua
-- Benchmark: Discovery operations
local function benchmark_discovery()
  local start_time = os.clock()
  local results = khaoslib_recipe.find_by_ingredient("iron-ore")
  local discovery_time = os.clock() - start_time

  log("Discovery operation: " .. discovery_time .. "s, " .. #results .. " results found")
end
```

## Usage Guide

### Choosing the Right Approach

**Use Manipulators When:**

- Modifying recipe or technology data
- Creating new prototypes
- Complex multi-step operations
- Need for fluent method chaining

**Use Static Functions When:**

- Pure analysis or discovery operations
- Compatibility checking
- Batch analysis across many prototypes
- Memory efficiency is important for analysis

### Adoption Strategy

Static functions complement existing workflows:

1. **Discovery operations**: Use `find_by_*` functions to locate prototypes of interest
2. **Analysis tasks**: Use static functions for checking properties without modification
3. **Hybrid workflows**: Combine static discovery with manipulator modification
4. **Compatibility patterns**: Use static utilities for mod compatibility analysis

## Expected Impact and Benefits

### Performance Improvements

Static functions provide performance benefits for specific use cases:

- **Analysis operations**: Reduced memory allocation for pure analysis scenarios
- **Discovery operations**: Efficient iteration without temporary object creation
- **Hybrid workflows**: Optimized discovery phase followed by targeted modifications

### Code Quality Improvements

**Readability:**

Static functions can provide cleaner code for analysis scenarios:

```lua
-- Analysis with static functions
if khaoslib_recipe.has_ingredient(data.raw.recipe["iron-plate"], "iron-ore") then
  local amount = khaoslib_recipe.get_ingredient_amount(data.raw.recipe["iron-plate"], "iron-ore")
end

-- Discovery operations
local iron_recipes = khaoslib_recipe.find_by_ingredient("iron-ore")
```

**Maintainability:**

- Clear separation between analysis and modification operations
- Lightweight analysis functions reduce memory pressure for discovery scenarios
- Consistent API patterns across both static and manipulator approaches

### Developer Experience

**Faster Development Cycles:**

- Reduced startup time for modpack testing
- More responsive development environment
- Clearer performance characteristics

**Better Debugging:**

- Less memory pressure reduces OOM errors during development
- Simpler call stacks for read operations
- Clear distinction between analysis and modification phases

## Pre-Release Context: Opportunity for Clean Integration

**Important Update**: Since khaoslib v0.2.0 has not been released yet, we have the opportunity
to add static utilities in a clean, well-integrated way without disrupting existing design decisions.

### Freedom to Add Enhancements

**No Existing Users**: The recipe and technology modules are still pre-release, meaning:

- We can add static functions without backward compatibility concerns
- API design can be optimized for both manipulator and static approaches
- Documentation can present both approaches from the start
- No need to retrofit static functions into an already-released API

**Complementary Design**: Instead of replacing the manipulator approach, we can:

- **Add static functions as a complementary enhancement**
- Keep manipulators as the primary tool for modification-heavy workflows
- Optimize static utilities for the specific analysis and discovery use cases
- Create a cohesive API that supports both modification and analysis patterns

### Revised Recommendations

**Maintain Current Design**: Keep manipulator-first API as the primary approach

**Add Complementary Enhancement**: Add static functions for specific use cases

#### Integrated API Design

```lua
local khaoslib_recipe = require("__khaoslib__.recipe")

-- PRIMARY API: Manipulators for modification workflows (majority of use cases)
khaoslib_recipe:load("iron-plate")
  :replace_ingredient("iron-ore", new_ingredient)
  :set_energy_required(32)
  :commit()

-- COMPLEMENTARY API: Static functions for discovery and analysis
local iron_recipes = khaoslib_recipe.find_by_ingredient("iron-ore")
local has_iron = khaoslib_recipe.has_ingredient(data.raw.recipe["iron-plate"], "iron-ore")

-- HYBRID PATTERN: Discovery + targeted modification
local target_recipes = khaoslib_recipe.find_by_ingredient("wood")
for _, recipe_name in ipairs(target_recipes) do
  khaoslib_recipe:load(recipe_name)
    :replace_ingredient("wood", {type = "item", name = "processed-wood", amount = 1})
    :commit()
end
```

#### Module Structure

```lua
-- Primary interface: Manipulator creation and modification
khaoslib_recipe:load(recipe_name)     -- Returns manipulator for modifications
khaoslib_recipe:create(recipe_data)   -- Returns manipulator for new recipes

-- Complementary interface: Static utilities for discovery and analysis
khaoslib_recipe.find_by_ingredient(compare)
khaoslib_recipe.has_ingredient(recipe_data, compare)
khaoslib_recipe.count_ingredients(recipe_data)
-- ... analysis and discovery functions as static utilities
```

### Optimal Implementation Strategy

#### Implementation Approach

**Add Complementary Static Functions**: Implement static functions alongside existing manipulator API

1. **Implement discovery functions**: `find_by_ingredient`, `find_by_result`, etc.
2. **Add analysis utilities**: `has_ingredient`, `count_ingredients`, etc.
3. **Ensure API consistency**: Static functions use similar patterns to manipulators
4. **Document usage patterns**: Clear guidance on when to use each approach

### Updated Benefits

**Design Benefits**:

- **Complementary APIs**: Manipulators and static functions serve different use cases optimally
- **Maintained strengths**: Manipulator-first design remains optimal for modification workflows
- **Enhanced capabilities**: Static functions efficiently handle analysis and discovery scenarios
- **Cohesive design**: Both approaches follow consistent patterns and conventions

**Implementation Benefits**:

- **Targeted optimization**: Each approach optimized for its specific use cases
- **Maintained performance**: No degradation of existing manipulator performance
- **Enhanced efficiency**: Analysis scenarios get dedicated efficient implementations
- **Clear boundaries**: Well-defined use cases for each approach reduce confusion

**User Benefits**:

- **Right tool for the job**: Users can choose the optimal approach for each scenario
- **Smooth learning curve**: Familiar manipulator patterns for complex modifications
- **Efficient analysis**: Lightweight static functions for discovery and checking
- **Flexible workflows**: Hybrid patterns combining both approaches as needed

### Conclusion: A Valuable Enhancement Opportunity

The pre-release status allows us to add static utilities as a clean, well-integrated enhancement
to the already well-designed manipulator-first API.

**Key Takeaways:**

1. **Validated Design**: The manipulator-first approach is optimal for Factorio modding patterns
2. **Targeted Enhancement**: Static functions can efficiently serve specific analysis use cases
3. **Complementary Strength**: Both approaches together provide comprehensive coverage
4. **Clean Integration**: Pre-release status allows seamless addition of static utilities
5. **User Choice**: Developers can choose the optimal tool for each specific scenario

**Action Plan:**

1. **Immediate**: Add static utility functions alongside existing manipulator API
2. **Short-term**: Document clear usage patterns and best practices for both approaches
3. **Release**: Launch v0.2.0 with enhanced API supporting both modification and analysis workflows
4. **Future**: Continue optimizing both approaches based on real-world usage patterns

This enhancement preserves the strengths of the current design while adding capabilities for
scenarios where static utilities provide better efficiency. The result is a more complete and
flexible API that serves the full spectrum of Factorio modding needs.

**The manipulator-first design was correct** - this enhancement simply adds complementary tools
for the minority of use cases where pure analysis benefits from a different approach.
