# Copy-on-Write Optimization for Recipe and Technology Manipulators

## Executive Summary

Copy-on-Write (CoW) is a memory optimization technique where multiple references share the same
underlying data until one reference needs to modify it. For khaoslib manipulators, this would
mean working directly with `data.raw` entries until a write operation occurs, at which point
the data would be deep-copied into the manipulator's internal state.

**Key Benefits:**

- Significant memory savings for read-heavy workloads
- Improved performance for inspection and query operations
- Reduced garbage collection pressure
- Better cache locality for read operations

**Key Challenges:**

- Increased implementation complexity
- Risk of accidental mutations to shared data
- Complex error handling scenarios
- Debugging difficulties

## Factorio Prototype Stage Context

### The Factorio Data Lifecycle

Factorio's [prototype stage](https://lua-api.factorio.com/latest/auxiliary/data-lifecycle.html#prototype-stage)
is a critical phase that occurs during game startup, before any gameplay begins. This stage has
unique characteristics that significantly impact the value proposition of copy-on-write optimization:

**Sequential Execution Model:**

1. **data.Lua** - Initial prototype definitions
2. **data-updates.Lua** - Mid-stage modifications
3. **data-final-fixes.Lua** - Final adjustments

Each mod's files run in a deterministic load order with **exclusive access** to the global
`data.raw` table. No parallel execution occurs during prototype stage.

**Single-Shot Execution:**

- All recipe/technology manipulations happen **once** at game startup
- No runtime modification of prototypes during gameplay
- Memory usage during prototype stage is temporary (freed after startup)
- Performance during prototype stage doesn't affect gameplay performance

### Implications for Copy-on-Write Optimization

This context fundamentally changes the cost-benefit analysis:

**Reduced Benefits:**

- **One-time execution**: Memory savings only matter during the brief startup period
- **No gameplay impact**: Prototype stage performance doesn't affect player experience
- **Temporary memory usage**: Memory is freed after startup regardless of optimization
- **Sequential processing**: No concurrent access patterns to optimize

**Remaining Benefits:**

- **Complex mod ecosystem**: Large modpacks with hundreds of recipes still benefit
- **Development workflow**: Faster iteration during mod development and testing
- **Memory-constrained environments**: Helpful for servers or low-memory systems
- **Startup time**: Noticeable improvement for modpacks with extensive recipe manipulation

**New Considerations:**

- **Load order dependencies**: CoW must handle mods modifying `data.raw` in sequence
- **Debugging during development**: Enhanced introspection becomes more valuable
- **Deterministic behavior**: CoW state transitions must be predictable across mod loads

### Realistic Usage Patterns in Prototype Stage

#### Typical Mod Development Scenarios

```lua
-- Scenario 1: Recipe analysis for compatibility mod
-- Runs once during data-final-fixes.lua
local wood_recipes = {}
for recipe_name, _ in pairs(data.raw.recipe) do
  local recipe = khaoslib_recipe:load(recipe_name)
  if recipe:has_ingredient("wood") then
    table.insert(wood_recipes, recipe_name)
  end
end
-- CoW benefit: High (read-only analysis of 200+ recipes)

-- Scenario 2: Recipe rebalancing mod
-- Runs once during data-updates.lua
for recipe_name, _ in pairs(data.raw.recipe) do
  local recipe = khaoslib_recipe:load(recipe_name)
  if recipe:has_ingredient("iron-ore") then
    recipe:replace_ingredient("iron-ore", {type = "item", name = "processed-iron", amount = 1})
    recipe:commit()
  end
end
-- CoW benefit: Moderate (mixed read/write with selective modification)

-- Scenario 3: New content mod
-- Runs once during data.lua
for i = 1, 50 do
  khaoslib_recipe:load{
    name = "my-recipe-" .. i,
    -- ... recipe definition
  }:add_ingredient(base_ingredient)
   :commit()
end
-- CoW benefit: None (all new recipes, immediate writes)
```

### API Design Implications for Prototype Stage

Understanding the prototype stage context raises fundamental questions about the khaoslib API design:

#### Current API Philosophy vs. Prototype Stage Reality

**Current Approach:**

```lua
-- Always use manipulators for consistency
local recipe = khaoslib_recipe:load("iron-plate")
if recipe:has_ingredient("iron-ore") then
  -- ... do something
end
```

**Alternative Approach for Prototype Stage:**

```lua
-- Direct data.raw access for reads, manipulators only for writes
if khaoslib_recipe.has_ingredient(data.raw.recipe["iron-plate"], "iron-ore") then
  -- Only load manipulator when modification is needed
  local recipe = khaoslib_recipe:load("iron-plate")
  recipe:replace_ingredient("iron-ore", new_ingredient)
  recipe:commit()
end
```

#### Recommended API Patterns for Prototype Stage

Given the prototype stage context, we should consider different usage patterns:

##### Pattern 1: Static Utility Functions for Read Operations

```lua
-- Add static utility functions that work directly with data.raw
local khaoslib_recipe = require("__khaoslib__.recipe")

-- Lightweight read operations (no manipulator allocation)
if khaoslib_recipe.has_ingredient(data.raw.recipe["iron-plate"], "iron-ore") then
  local ingredients = khaoslib_recipe.get_ingredients(data.raw.recipe["iron-plate"])
  local iron_amount = khaoslib_recipe.get_ingredient_amount(data.raw.recipe["iron-plate"], "iron-ore")
end

-- Only use manipulators for modifications
local recipe = khaoslib_recipe:load("iron-plate")
recipe:replace_ingredient("iron-ore", new_ingredient):commit()
```

##### Pattern 2: Explicit CoW Control

```lua
-- Explicit control over when deep copying occurs
local recipe = khaoslib_recipe:load("iron-plate", {copy_on_write = true})

-- Read operations work directly with data.raw (no memory overhead)
if recipe:has_ingredient("iron-ore") then
  -- Still using CoW mode, no copy yet
end

-- First write operation triggers deep copy
recipe:replace_ingredient("iron-ore", new_ingredient)  -- CoW triggered here
recipe:commit()
```

##### Pattern 3: Bulk Operation Optimization

```lua
-- Optimized for prototype stage bulk operations
local recipes_to_modify = khaoslib_recipe.find_by_ingredient("iron-ore")  -- Static utility

-- Batch modification with single manipulator allocation per recipe
for _, recipe_name in ipairs(recipes_to_modify) do
  khaoslib_recipe:load(recipe_name)
    :replace_ingredient("iron-ore", new_ingredient)
    :commit()
end
```

#### Documentation and Examples Should Emphasize

**For Read-Heavy Operations (Analysis, Discovery):**

```lua
-- RECOMMENDED: Direct data.raw access with utility functions
local wood_recipes = {}
for recipe_name, recipe_data in pairs(data.raw.recipe) do
  if khaoslib_recipe.has_ingredient(recipe_data, "wood") then
    table.insert(wood_recipes, recipe_name)
  end
end
-- Memory usage: Minimal (no manipulator objects)
-- Performance: Optimal (direct table access)
```

**For Mixed Read/Write Operations:**

```lua
-- RECOMMENDED: CoW pattern or static utilities + selective loading
for recipe_name, recipe_data in pairs(data.raw.recipe) do
  if khaoslib_recipe.has_ingredient(recipe_data, "iron-ore") then
    -- Only create manipulator when modification is needed
    khaoslib_recipe:load(recipe_name)
      :replace_ingredient("iron-ore", new_ingredient)
      :commit()
  end
end
-- Memory usage: Minimal (manipulators only for modified recipes)
-- Performance: Good (avoids unnecessary deep copies)
```

**For Write-Heavy Operations:**

```lua
-- CURRENT APPROACH IS FINE: Immediate manipulator creation
for i = 1, 50 do
  khaoslib_recipe:load{
    name = "my-recipe-" .. i,
    -- ... recipe definition
  }:add_ingredient(base_ingredient)
   :commit()
end
-- Memory usage: Standard (manipulators for all new recipes)
-- Performance: Good (no unnecessary optimization overhead)
```

#### Impact on Module Documentation

This analysis suggests our module documentation should:

1. **Emphasize static utility functions** for read-only operations
2. **Recommend manipulators primarily for modifications**
3. **Provide clear guidance** on when to use each approach
4. **Show memory-efficient patterns** for prototype stage usage
5. **Update all examples** to reflect prototype stage best practices

The current approach of "always use manipulators" may be sub-optimal for the prototype stage context
where most operations are read-heavy analysis followed by selective modifications.

### Revised Value Proposition

Given the prototype stage context, CoW optimization provides:

**High Value Scenarios:**

- **Large modpack compatibility analysis** (analyzing 500+ recipes)
- **Recipe discovery and categorization systems**
- **Technology tree analysis and visualization mods**
- **Development tools and debugging utilities**

**Low Value Scenarios:**

- **Simple content mods** (adding few new recipes/technologies)
- **Small-scale recipe modifications** (< 50 recipes)
- **Write-heavy operations** (extensive recipe generation)

**Break-even Analysis:**

- **Memory threshold**: ~100+ recipe loads for noticeable benefit
- **Time threshold**: ~2-3 seconds saved in modpack startup (user-perceptible)
- **Development benefit**: Consistent value for mod developers iterating frequently

## Current Implementation Analysis

### Current Behavior

```lua
-- Current: Always deep copies on load
local recipe = khaoslib_recipe:load("iron-plate")
-- Memory: Full copy of recipe data immediately allocated
-- Operations: All work on isolated copy

local ingredients = recipe:get_ingredients()  -- Another deep copy
local has_iron = recipe:has_ingredient("iron-ore")  -- Works on copy
```

### Performance Characteristics

1. **Memory Usage**: O(n) immediate allocation where n = prototype size
2. **Load Time**: O(n) deep copy operation
3. **Read Operations**: O(1) access to owned data
4. **Write Operations**: O(1) modification of owned data

## Proposed Copy-on-Write Implementation

### Core Concept

```lua
-- CoW: References data.raw until first write
local recipe = khaoslib_recipe:load("iron-plate")
-- Memory: Only metadata allocated (manipulator object + reference)
-- Operations: Read directly from data.raw, write triggers copy

-- Read operations work directly with data.raw
local ingredients = recipe:get_ingredients()  -- Direct access + deep copy return
local has_iron = recipe:has_ingredient("iron-ore")  -- Direct access, no copy

-- First write operation triggers CoW
recipe:add_ingredient({type = "item", name = "coal", amount = 1})
-- Memory: Now full copy allocated and manipulator switches to copied data
```

### Implementation Architecture

#### 1. State Management

```lua
---@class khaoslib.RecipeManipulator
---@field private recipe data.RecipePrototype? Internal copy (nil until CoW triggered)
---@field private recipe_name string Original recipe name for data.raw access
---@field private is_copy_on_write boolean True if still referencing data.raw
---@field private is_new_recipe boolean True if recipe doesn't exist in data.raw
```

#### 2. Read Operation Implementation

```lua
function khaoslib_recipe:get_ingredients()
  local source_recipe = self:_get_source_recipe()
  return util.table.deepcopy(source_recipe.ingredients or {})
end

function khaoslib_recipe:has_ingredient(compare)
  local source_recipe = self:_get_source_recipe()
  -- Work directly with data.raw reference
  return khaoslib_list.has(source_recipe.ingredients, compare_fn)
end

function khaoslib_recipe:_get_source_recipe()
  if self.is_new_recipe or not self.is_copy_on_write then
    return self.recipe  -- Use internal copy
  else
    return data.raw.recipe[self.recipe_name]  -- Direct data.raw access
  end
end
```

#### 3. Write Operation Implementation

```lua
function khaoslib_recipe:add_ingredient(ingredient)
  self:_ensure_cow_copy()  -- Trigger CoW if needed

  -- Now work with owned copy
  local compare_fn = function(existing)
    return existing.type == ingredient.type and existing.name == ingredient.name
  end

  self.recipe.ingredients = khaoslib_list.add(self.recipe.ingredients, ingredient, compare_fn)
  return self
end

function khaoslib_recipe:_ensure_cow_copy()
  if self.is_copy_on_write and not self.is_new_recipe then
    -- Trigger copy-on-write
    self.recipe = util.table.deepcopy(data.raw.recipe[self.recipe_name])
    self.is_copy_on_write = false
  end
end
```

## Performance Analysis

### Memory Usage Comparison

| Operation | Current Implementation | CoW Implementation |
|-----------|----------------------|-------------------|
| Load + 5 reads | 1 full copy | 0 full copies |
| Load + 1 write | 1 full copy | 1 full copy |
| Load + 5 reads + 1 write | 1 full copy | 1 full copy |
| 100 loads (read-only) | 100 full copies | 0 full copies |

### Time Complexity Analysis

| Operation | Current | CoW (Pre-Copy) | CoW (Post-Copy) |
|-----------|---------|----------------|-----------------|
| Load | O(n) | O(1) | O(1) |
| Read | O(1) | O(1) | O(1) |
| First Write | O(1) | O(n) | O(1) |
| Subsequent Writes | O(1) | N/A | O(1) |

Where n = size of prototype data.

### Benchmark Scenarios

#### Scenario 1: Bulk Read Operations (High Benefit)

```lua
-- Analyze all recipes for specific ingredients
local recipes_with_iron = {}
for recipe_name, _ in pairs(data.raw.recipe) do
  local recipe = khaoslib_recipe:load(recipe_name)
  if recipe:has_ingredient("iron-ore") then
    table.insert(recipes_with_iron, recipe_name)
  end
end

-- Current: O(n*m) where n=recipe count, m=avg recipe size
-- CoW: O(n) - no copies, direct data.raw access
-- Memory savings: ~95% for typical mod with 200+ recipes
```

#### Scenario 2: Mixed Read/Write (Moderate Benefit)

```lua
-- Modify recipes that use specific ingredients
for recipe_name, _ in pairs(data.raw.recipe) do
  local recipe = khaoslib_recipe:load(recipe_name)
  if recipe:has_ingredient("iron-ore") then  -- Read operation
    recipe:replace_ingredient("iron-ore", new_ingredient)  -- Write operation
    recipe:commit()
  end
end

-- Current: O(n*m) upfront copies
-- CoW: O(k*m) where k=recipes that need modification
-- Memory savings: Proportional to (n-k)/n
```

#### Scenario 3: Write-Heavy Operations (No Benefit)

```lua
-- Create many new recipes
for i = 1, 100 do
  khaoslib_recipe:load{
    name = "recipe-" .. i,
    -- ... other fields
  }:add_ingredient(base_ingredient)
   :add_result(base_result)
   :commit()
end

-- Current: O(n*m)
-- CoW: O(n*m) - new recipes trigger immediate copying
-- Memory savings: None (may be slightly worse due to overhead)
```

## Implementation Challenges and Solutions

### Challenge 1: Accidental Mutation Prevention

**Problem**: Direct access to `data.raw` could lead to accidental mutations.

**Solution**: Return deep copies for all mutable data access.

```lua
function khaoslib_recipe:get_ingredients()
  local source_recipe = self:_get_source_recipe()
  -- Always return deep copy to prevent accidental mutation
  return util.table.deepcopy(source_recipe.ingredients or {})
end

function khaoslib_recipe:get()
  local source_recipe = self:_get_source_recipe()
  -- Always return deep copy of full recipe
  return util.table.deepcopy(source_recipe)
end
```

### Challenge 2: Concurrent Modification Detection

**Problem**: `data.raw` could be modified by other code between reads.

**Solution**: Version tracking and validation.

```lua
---@class khaoslib.RecipeManipulator
---@field private data_raw_version number? Snapshot of modification counter

function khaoslib_recipe:_ensure_data_consistency()
  if self.is_copy_on_write then
    local current_version = _G._khaoslib_data_version or 0
    if self.data_raw_version and self.data_raw_version ~= current_version then
      error("data.raw was modified since manipulator creation. Reload the manipulator.", 2)
    end
  end
end

-- Global modification tracking
local original_extend = data.extend
function data.extend(self, prototypes)
  _G._khaoslib_data_version = (_G._khaoslib_data_version or 0) + 1
  return original_extend(self, prototypes)
end
```

### Challenge 3: Error State Management

**Problem**: Complex error scenarios with mixed states.

**Solution**: Comprehensive error handling and state validation.

```lua
function khaoslib_recipe:_get_source_recipe()
  if self.is_new_recipe then
    if not self.recipe then
      error("Internal error: new recipe without data", 2)
    end
    return self.recipe
  end

  if self.is_copy_on_write then
    local raw_recipe = data.raw.recipe[self.recipe_name]
    if not raw_recipe then
      error("Recipe '" .. self.recipe_name .. "' was deleted from data.raw", 2)
    end
    self:_ensure_data_consistency()
    return raw_recipe
  else
    if not self.recipe then
      error("Internal error: no recipe data in post-CoW state", 2)
    end
    return self.recipe
  end
end
```

### Challenge 4: Debugging and Introspection

**Problem**: Harder to debug issues when data location varies.

**Solution**: Enhanced debugging utilities and clear state indicators.

```lua
function khaoslib_recipe:debug_info()
  return {
    recipe_name = self.recipe_name,
    is_copy_on_write = self.is_copy_on_write,
    is_new_recipe = self.is_new_recipe,
    has_internal_copy = self.recipe ~= nil,
    data_raw_exists = data.raw.recipe[self.recipe_name] ~= nil,
    memory_usage = self.is_copy_on_write and "minimal" or "full-copy"
  }
end

function khaoslib_recipe:__tostring()
  local cow_status = self.is_copy_on_write and " (CoW)" or " (copied)"
  return "[khaoslib_recipe: " .. self.recipe_name .. cow_status .. "]"
end
```

## Advanced Optimization Strategies

### 1. Lazy Field Copying

Instead of copying entire prototypes, copy only accessed fields:

```lua
---@class khaoslib.RecipeManipulator
---@field private copied_fields table<string, any> Only copied specific fields

function khaoslib_recipe:get_ingredients()
  if self.is_copy_on_write then
    if not self.copied_fields.ingredients then
      local source = data.raw.recipe[self.recipe_name]
      self.copied_fields.ingredients = util.table.deepcopy(source.ingredients or {})
    end
    return util.table.deepcopy(self.copied_fields.ingredients)
  else
    return util.table.deepcopy(self.recipe.ingredients or {})
  end
end
```

### 2. Reference Counting

Track how many manipulators reference the same recipe:

```lua
-- Global reference counter
_G._khaoslib_recipe_refs = _G._khaoslib_recipe_refs or {}

function khaoslib_recipe:load(recipe_name)
  local refs = _G._khaoslib_recipe_refs
  refs[recipe_name] = (refs[recipe_name] or 0) + 1

  -- Decide CoW strategy based on reference count
  local use_cow = refs[recipe_name] > 1

  -- ... implementation
end
```

### 3. Selective CoW by Operation Type

Some operations might warrant immediate copying:

```lua
local IMMEDIATE_COPY_OPERATIONS = {
  "set_ingredients",  -- Bulk operations
  "set_results",
  "clear_ingredients",
  "clear_results"
}

function khaoslib_recipe:_should_immediate_copy(method_name)
  return khaoslib_list.has(IMMEDIATE_COPY_OPERATIONS, method_name)
end
```

## Error Scenarios and Handling

### 1. Data.raw Modification After Load

```lua
local recipe = khaoslib_recipe:load("iron-plate")
-- Another mod modifies data.raw.recipe["iron-plate"]
local ingredients = recipe:get_ingredients()  -- Should this reflect changes?

-- Solution: Detect and error
-- Alternative: Warn and continue with snapshot
```

### 2. Recipe Deletion After Load

```lua
local recipe = khaoslib_recipe:load("iron-plate")
data.raw.recipe["iron-plate"] = nil  -- Deleted by another mod
recipe:has_ingredient("iron-ore")  -- What should happen?

-- Solution: Clear error message
-- Alternative: Return cached data if available
```

### 3. Memory Pressure During CoW

```lua
-- What if deep copy fails due to memory constraints?
function khaoslib_recipe:_ensure_cow_copy()
  if self.is_copy_on_write and not self.is_new_recipe then
    local success, result = pcall(util.table.deepcopy, data.raw.recipe[self.recipe_name])
    if not success then
      error("Failed to create copy-on-write copy due to memory constraints: " .. result, 2)
    end
    self.recipe = result
    self.is_copy_on_write = false
  end
end
```

## Migration Strategy

### Phase 1: Internal Infrastructure

1. Add CoW state fields to manipulator classes
2. Implement `_get_source_recipe()` and `_ensure_cow_copy()` helpers
3. Add comprehensive unit tests for state transitions

### Phase 2: Read Operation Migration

1. Update all read operations to use `_get_source_recipe()`
2. Ensure all returns are deep copies
3. Add performance benchmarks

### Phase 3: Write Operation Migration

1. Update all write operations to call `_ensure_cow_copy()`
2. Add error handling for CoW failures
3. Test edge cases and error scenarios

### Phase 4: Optimization and Tuning

1. Implement advanced strategies (lazy copying, reference counting)
2. Add debugging and introspection tools
3. Performance tuning based on real-world usage

## Backward Compatibility

The CoW implementation should be completely transparent to existing code:

```lua
-- All existing code continues to work unchanged
local recipe = khaoslib_recipe:load("iron-plate")
recipe:add_ingredient({type = "item", name = "coal", amount = 1})
recipe:commit()

-- Behavior is identical, only internal optimization changes
```

## Testing Strategy

### Unit Tests

```lua
-- State transition tests
local recipe = khaoslib_recipe:load("iron-plate")
assert(recipe.is_copy_on_write == true)

recipe:add_ingredient({type = "item", name = "coal", amount = 1})
assert(recipe.is_copy_on_write == false)

-- Data consistency tests
local recipe1 = khaoslib_recipe:load("iron-plate")
local recipe2 = khaoslib_recipe:load("iron-plate")
-- Both should reference same data.raw initially

recipe1:add_ingredient({type = "item", name = "coal", amount = 1})
-- recipe1 should have coal, recipe2 should not
```

### Performance Tests

```lua
-- Memory usage benchmarks
local memory_before = collectgarbage("count")
local recipes = {}
for i = 1, 1000 do
  recipes[i] = khaoslib_recipe:load("iron-plate")
end
local memory_after = collectgarbage("count")
-- Should show significant memory savings with CoW

-- Time benchmarks
local start_time = os.clock()
for i = 1, 1000 do
  local recipe = khaoslib_recipe:load("iron-plate")
  recipe:has_ingredient("iron-ore")
end
local end_time = os.clock()
-- Should show improved load times with CoW
```

### Integration Tests

```lua
-- Real-world scenario testing
-- Recipe analysis across entire mod ecosystem
local function analyze_all_recipes()
  local analysis = {}
  for recipe_name, _ in pairs(data.raw.recipe) do
    local recipe = khaoslib_recipe:load(recipe_name)
    analysis[recipe_name] = {
      ingredient_count = recipe:count_ingredients(),
      result_count = recipe:count_results(),
      uses_fluids = recipe:has_ingredient(function(ing) return ing.type == "fluid" end)
    }
  end
  return analysis
end
```

## Conclusion

Understanding Factorio's prototype stage fundamentally changes the value proposition of
copy-on-write optimization for khaoslib manipulators. While the benefits are real, they are
more narrowly focused than initially apparent.

**Revised Assessment:**

The **prototype stage context** reveals that CoW optimization provides genuine value primarily for:

1. **Complex modpack ecosystems** with extensive recipe analysis
2. **Development workflow improvements** during iterative mod creation
3. **Memory-constrained environments** where startup memory pressure matters
4. **Specialized analysis tools** that process hundreds of prototypes

However, the **one-time execution model** means that:

- Benefits are limited to the brief startup period (not gameplay performance)
- Simple content mods see minimal improvement
- Implementation complexity may outweigh benefits for basic use cases

**Recommended Implementation Strategy:**

1. **Conditional CoW**: Implement CoW as an opt-in feature for specific scenarios
2. **Heuristic activation**: Auto-enable CoW based on usage patterns (e.g., >100 loads)
3. **Development mode**: Enhanced CoW features for mod development workflows
4. **Fallback compatibility**: Maintain current behavior as default for reliability

**Updated Success Metrics:**

- **Startup time reduction**: 2-5 seconds for large modpacks (user-noticeable)
- **Memory usage reduction**: 50-80% during prototype stage (enables larger modpacks)
- **Development productivity**: Faster iteration cycles for mod developers
- **Zero runtime impact**: No gameplay performance changes (positive or negative)

**Final Recommendation:**

Implement CoW optimization as a **targeted enhancement** rather than a wholesale replacement.
Focus on scenarios where the prototype stage memory and time benefits provide clear value:
modpack compatibility analysis, development tooling, and complex recipe processing systems.

The implementation should prioritize **correctness and opt-in usability** over maximum
performance, with clear documentation about when CoW provides benefits in the prototype
stage context.
