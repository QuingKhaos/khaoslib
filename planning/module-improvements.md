# Module Improvements and Enhancement Ideas

## Overview

This document outlines potential improvements and enhancements for the three core khaoslib modules: `list`, `recipe`,
and `technology`. These ideas range from minor quality-of-life improvements to major feature additions that could
significantly expand the utility and usability of the library.

## List Module Improvements

### 1. Enhanced Query and Filtering Capabilities

**Current State**: Basic `has()` function with string/function comparison
**Proposed Enhancement**: Advanced query system with chaining and multiple criteria

```lua
-- Current approach
khaoslib_list.has(my_list, function(item)
  return item.type == "fluid" and item.amount > 100
end)

-- Proposed query builder approach
khaoslib_list.query(my_list)
  :where("type", "fluid")
  :where("amount", ">", 100)
  :exists()

-- Or even more advanced
khaoslib_list.query(my_list)
  :where(function(item) return item.type == "fluid" end)
  :and_where("amount", ">", 100)
  :or_where("name", "contains", "water")
  :get_all()
```

**Benefits**:

- More readable code for complex conditions
- Reusable query objects
- Better performance for multiple operations on same dataset
- SQL-like familiarity for developers

### 2. Statistical and Aggregation Functions

**Current Gap**: No built-in aggregation capabilities
**Proposed Functions**:

```lua
-- Statistical operations
khaoslib_list.sum(ingredient_list, "amount")
khaoslib_list.average(ingredient_list, "amount")
khaoslib_list.min(ingredient_list, "amount")
khaoslib_list.max(ingredient_list, "amount")
khaoslib_list.count(ingredient_list, function(item) return item.type == "fluid" end)

-- Grouping operations
local grouped = khaoslib_list.group_by(ingredient_list, "type")
-- Returns: {item = {...}, fluid = {...}}

-- Advanced aggregations
local totals = khaoslib_list.aggregate(ingredient_list, {
  total_items = function(items) return khaoslib_list.sum(items, "amount") end,
  fluid_count = function(items) return khaoslib_list.count(items, function(i) return i.type == "fluid" end) end
})
```

### 3. Functional Programming Enhancements

**Current Gap**: Limited functional programming support
**Proposed Functions**:

```lua
-- Map operations with built-in deep copying
local doubled_amounts = khaoslib_list.map(ingredient_list, function(item)
  local copy = util.table.deepcopy(item)
  copy.amount = copy.amount * 2
  return copy
end)

-- Filter operations
local fluids = khaoslib_list.filter(ingredient_list, function(item)
  return item.type == "fluid"
end)

-- Reduce operations
local total_cost = khaoslib_list.reduce(ingredient_list, function(acc, item)
  return acc + (item.amount or 1)
end, 0)

-- Partition operations
local items, fluids = khaoslib_list.partition(ingredient_list, function(item)
  return item.type == "item"
end)

-- Chaining support
local result = khaoslib_list.chain(ingredient_list)
  :filter(function(item) return item.amount > 1 end)
  :map(function(item)
    local copy = util.table.deepcopy(item)
    copy.amount = copy.amount * 2
    return copy
  end)
  :sort_by("amount")
  :value()
```

### 4. Sorting and Ordering

**Current Gap**: No sorting capabilities
**Proposed Functions**:

```lua
-- Simple sorting
khaoslib_list.sort(ingredient_list, "amount") -- ascending by default
khaoslib_list.sort(ingredient_list, "amount", "desc")

-- Complex sorting with functions
khaoslib_list.sort(ingredient_list, function(a, b)
  if a.type ~= b.type then
    return a.type < b.type
  else
    return (a.amount or 1) < (b.amount or 1)
  end
end)

-- Multi-level sorting
khaoslib_list.sort_by(ingredient_list, {"type", "amount"})
khaoslib_list.sort_by(ingredient_list, {
  {field = "type", order = "asc"},
  {field = "amount", order = "desc"}
})
```

### 5. Set Operations

**Current Gap**: No set-like operations despite list nature
**Proposed Functions**:

```lua
-- Set operations with custom comparison
local union = khaoslib_list.union(list1, list2, "name")
local intersection = khaoslib_list.intersection(list1, list2, "name")
local difference = khaoslib_list.difference(list1, list2, "name")
local symmetric_difference = khaoslib_list.symmetric_difference(list1, list2, "name")

-- Subset checking
local is_subset = khaoslib_list.is_subset(small_list, big_list, "name")
local is_superset = khaoslib_list.is_superset(big_list, small_list, "name")
```

## Recipe Module Improvements

### 1. Recipe Discovery and Search

**Current Gap**: No way to find recipes based on criteria
**Proposed Enhancement**: Recipe discovery system

```lua
-- Find recipes by ingredient
local recipes_using_iron = khaoslib_recipe.find_by_ingredient("iron-plate")
local recipes_using_fluids = khaoslib_recipe.find_by_ingredient(function(ingredient)
  return ingredient.type == "fluid"
end)

-- Find recipes by result
local iron_producers = khaoslib_recipe.find_by_result("iron-plate")

-- Find recipes by category
local smelting_recipes = khaoslib_recipe.find_by_category("smelting")

-- Complex recipe queries
local complex_recipes = khaoslib_recipe.find(function(recipe)
  return #recipe.ingredients > 3 and
         recipe.energy_required > 5 and
         khaoslib_list.has(recipe.ingredients, function(i) return i.type == "fluid" end)
end)

-- Recipe dependency analysis
local recipe_chain = khaoslib_recipe.get_dependency_chain("advanced-circuit")
-- Returns all recipes needed to craft advanced-circuit recursively
```

### 2. Recipe Templates and Patterns

**Current Gap**: Each recipe created from scratch
**Proposed Enhancement**: Recipe templates and pattern system

```lua
-- Template system
local smelting_template = khaoslib_recipe.create_template("smelting", {
  category = "smelting",
  energy_required = 3.2,
  ingredients = {{type = "item", name = "PLACEHOLDER_INPUT", amount = 1}},
  results = {{type = "item", name = "PLACEHOLDER_OUTPUT", amount = 1}}
})

-- Use template
khaoslib_recipe.from_template(smelting_template, {
  name = "titanium-plate",
  replacements = {
    PLACEHOLDER_INPUT = "titanium-ore",
    PLACEHOLDER_OUTPUT = "titanium-plate"
  }
}):commit()

-- Pattern matching and generation
local recipe_pattern = khaoslib_recipe.extract_pattern("iron-plate")
-- Apply pattern to create similar recipes
khaoslib_recipe.apply_pattern(recipe_pattern, {
  name = "gold-plate",
  input = "gold-ore",
  output = "gold-plate"
}):commit()
```

### 3. Recipe Validation and Analysis

**Current Gap**: No validation of recipe correctness
**Proposed Enhancement**: Comprehensive validation system

```lua
-- Recipe validation
local validation_result = khaoslib_recipe.validate("my-recipe")
-- Returns: {valid = false, errors = {"Missing ingredient type", "Invalid energy_required"}}

-- Ingredient/result analysis
local analysis = khaoslib_recipe.analyze("electronic-circuit")
-- Returns detailed analysis: ingredient costs, result values, efficiency metrics

-- Recipe balancing suggestions
local suggestions = khaoslib_recipe.suggest_balance("overpowered-recipe")
-- Returns suggestions for balancing based on similar recipes

-- Factorio compatibility checking
local compatibility = khaoslib_recipe.check_compatibility("my-recipe")
-- Checks against Factorio's recipe requirements and limitations
```

### 4. Batch Operations and Recipe Sets

**Current Gap**: Only single recipe manipulation
**Proposed Enhancement**: Batch operations for recipe groups

```lua
-- Recipe groups
local iron_recipes = khaoslib_recipe.group("iron-recipes", {
  "iron-plate", "iron-gear-wheel", "iron-stick"
})

-- Batch operations
iron_recipes:multiply_energy_required(1.5)
           :add_ingredient_to_all({type = "item", name = "catalyst", amount = 1})
           :commit_all()

-- Conditional batch operations
khaoslib_recipe.batch_modify(
  khaoslib_recipe.find_by_category("smelting"),
  function(recipe_manipulator)
    if recipe_manipulator:has_ingredient("coal") then
      recipe_manipulator:replace_ingredient("coal", {type = "item", name = "coke", amount = 1})
    end
  end
)

-- Recipe set operations
local recipe_set_a = khaoslib_recipe.create_set({"recipe-1", "recipe-2"})
local recipe_set_b = khaoslib_recipe.create_set({"recipe-2", "recipe-3"})
local common_recipes = recipe_set_a:intersection(recipe_set_b)
```

### 5. Recipe Metrics and Economics

**Current Gap**: No economic or efficiency analysis
**Proposed Enhancement**: Recipe economics system

```lua
-- Cost analysis (requires item value system)
local cost_analysis = khaoslib_recipe.analyze_cost("advanced-circuit")
-- Returns: input_cost, output_value, profit_margin, time_efficiency

-- Recipe efficiency comparison
local efficiency = khaoslib_recipe.compare_efficiency("iron-plate", "steel-plate")
-- Returns relative efficiency metrics

-- Resource flow analysis
local flow = khaoslib_recipe.analyze_resource_flow("electronic-circuit")
-- Returns what items are consumed vs produced in the recipe network
```

## Technology Module Improvements

### 1. Technology Tree Analysis

**Current Gap**: No technology tree analysis capabilities
**Proposed Enhancement**: Comprehensive tree analysis tools

```lua
-- Technology dependency analysis
local tech_tree = khaoslib_technology.analyze_tree()
local dependencies = khaoslib_technology.get_dependency_chain("advanced-electronics")
local dependents = khaoslib_technology.get_dependent_technologies("electronics")

-- Circular dependency detection
local circular_deps = khaoslib_technology.find_circular_dependencies()

-- Technology path finding
local shortest_path = khaoslib_technology.find_shortest_path("automation", "robotics")
local all_paths = khaoslib_technology.find_all_paths("automation", "robotics")

-- Tree validation
local validation = khaoslib_technology.validate_tree()
-- Returns orphaned technologies, unreachable technologies, etc.
```

### 2. Technology Balancing and Progression

**Current Gap**: No balancing analysis or progression validation
**Proposed Enhancement**: Technology progression analysis

```lua
-- Progression analysis
local progression = khaoslib_technology.analyze_progression()
-- Returns technology tiers, research costs by tier, unlock patterns

-- Balance checking
local balance = khaoslib_technology.check_balance("advanced-electronics")
-- Compares research cost to value of unlocked recipes/effects

-- Auto-balancing suggestions
local suggestions = khaoslib_technology.suggest_balance("overpowered-tech")
-- Suggests prerequisite changes, cost adjustments, effect modifications

-- Technology tier assignment
khaoslib_technology.assign_tier("my-tech", 3) -- Assign to tier 3
local tier_info = khaoslib_technology.get_tier_info(3) -- Get all tier 3 technologies
```

### 3. Technology Templates and Patterns

**Current Gap**: Each technology created from scratch
**Proposed Enhancement**: Technology template system

```lua
-- Technology templates
local military_template = khaoslib_technology.create_template("military", {
  icon = "__base__/graphics/technology/military.png",
  unit = {
    count = 100,
    ingredients = {
      {"automation-science-pack", 1},
      {"logistic-science-pack", 1},
      {"military-science-pack", 1}
    },
    time = 30
  }
})

-- Apply template
khaoslib_technology.from_template(military_template, {
  name = "advanced-weapons",
  prerequisites = {"military-2"},
  effects = {
    {type = "unlock-recipe", recipe = "plasma-rifle"}
  }
}):commit()

-- Pattern recognition
local pattern = khaoslib_technology.extract_pattern("electronics")
-- Apply pattern to create similar technology progression
```

### 4. Science Pack Management and Analysis

**Current Gap**: Basic science pack manipulation only
**Proposed Enhancement**: Advanced science pack analysis

```lua
-- Science pack analysis across all technologies
local science_analysis = khaoslib_technology.analyze_science_usage()
-- Returns: total packs needed per type, bottlenecks, unused combinations

-- Science pack balancing
khaoslib_technology.balance_science_packs({
  target_ratios = {
    ["automation-science-pack"] = 1,
    ["logistic-science-pack"] = 1,
    ["military-science-pack"] = 0.8,
    ["chemical-science-pack"] = 0.6
  }
})

-- Research cost optimization
local optimized_costs = khaoslib_technology.optimize_research_costs("my-tech-tree")
-- Suggests optimal research costs based on technology value and progression

-- Science pack dependency tracking
local deps = khaoslib_technology.get_science_dependencies("space-science-pack")
-- Returns all technologies that require space science packs
```

### 5. Technology Effect Management

**Current Gap**: Basic effect manipulation only
**Proposed Enhancement**: Advanced effect analysis and management

```lua
-- Effect analysis
local effect_analysis = khaoslib_technology.analyze_effects()
-- Returns statistics on effect types, recipe unlocks, modifier distributions

-- Effect validation
local effect_validation = khaoslib_technology.validate_effects("my-tech")
-- Checks if unlocked recipes exist, if modifiers are valid, etc.

-- Effect impact analysis
local impact = khaoslib_technology.analyze_effect_impact("logistics")
-- Analyzes the gameplay impact of technology effects

-- Duplicate effect detection
local duplicates = khaoslib_technology.find_duplicate_effects()
-- Finds technologies that unlock the same recipes or provide same modifiers
```

## Cross-Module Improvements

### 1. Unified Query System

**Current Gap**: Each module has its own query patterns
**Proposed Enhancement**: Unified query interface across all modules

```lua
-- Unified query builder
local query = khaoslib.query()

-- Query recipes
local recipes = query:recipes()
  :where_ingredient("iron-plate")
  :where_category("crafting")
  :where_energy(">", 5)
  :get()

-- Query technologies
local techs = query:technologies()
  :where_prerequisite("electronics")
  :where_effect_type("unlock-recipe")
  :where_cost("<", 1000)
  :get()

-- Cross-module queries
local recipe_tech_pairs = query:recipe_technology_pairs()
  :where_recipe_category("smelting")
  :where_tech_tier(2)
  :get()
```

### 2. Dependency Analysis System

**Current Gap**: No cross-module dependency tracking
**Proposed Enhancement**: Comprehensive dependency analysis

```lua
-- Full dependency analysis
local dependencies = khaoslib.analyze_dependencies()
-- Returns complete dependency graph: items -> recipes -> technologies

-- Impact analysis
local impact = khaoslib.analyze_impact("remove", "iron-plate")
-- Shows what recipes and technologies would be affected

-- Validation system
local validation = khaoslib.validate_all()
-- Validates consistency across recipes, technologies, and items
```

### 3. Backup and Rollback System

**Current Gap**: No undo functionality
**Proposed Enhancement**: Transaction-like system with rollback

```lua
-- Transaction system
khaoslib.begin_transaction()

khaoslib_recipe.load("iron-plate"):multiply_ingredient_amounts(2):commit()
khaoslib_technology.load("automation"):add_prerequisite("advanced-automation"):commit()

-- Something goes wrong...
khaoslib.rollback_transaction()

-- Or commit all changes
khaoslib.commit_transaction()

-- Checkpoint system
local checkpoint = khaoslib.create_checkpoint()
-- ... make changes ...
khaoslib.restore_checkpoint(checkpoint)
```

### 4. Performance Optimization Framework

**Current Gap**: No performance monitoring or optimization
**Proposed Enhancement**: Performance analysis and optimization tools

```lua
-- Performance profiling
khaoslib.start_profiling()
-- ... perform operations ...
local profile = khaoslib.end_profiling()
-- Returns timing information, memory usage, operation counts

-- Batch optimization
local batch = khaoslib.create_batch()
batch:add_recipe_operation("iron-plate", "multiply_ingredients", 2)
batch:add_technology_operation("automation", "add_prerequisite", "basic-tech")
batch:commit_all() -- Optimized batch execution

-- Caching system
khaoslib.enable_caching() -- Cache expensive operations like dependency analysis
khaoslib.clear_cache() -- Clear when data changes significantly
```

### 5. Integration and Compatibility Framework

**Current Gap**: Limited integration with other mods/systems
**Proposed Enhancement**: Comprehensive integration framework

```lua
-- Mod compatibility system
khaoslib.register_mod_integration("bobs-mods", {
  recipe_adjustments = function()
    -- Automatic adjustments for Bob's mods
  end,
  technology_adjustments = function()
    -- Technology tree adjustments
  end
})

-- Event system
khaoslib.on_recipe_modified(function(recipe_name, old_recipe, new_recipe)
  -- Handle recipe modifications
end)

khaoslib.on_technology_modified(function(tech_name, old_tech, new_tech)
  -- Handle technology modifications
end)

-- Configuration system
khaoslib.configure({
  auto_validate = true,
  performance_mode = "fast", -- vs "memory_efficient"
  compatibility_mode = {"bobs", "angels", "krastorio"},
  debug_level = "info"
})
```

## Implementation Priorities

### High Priority (Core Functionality)

1. **Recipe Discovery System** - Essential for advanced recipe manipulation
2. **Technology Tree Analysis** - Critical for technology balancing
3. **Batch Operations** - Major performance and usability improvement
4. **Enhanced Query System** - Foundation for advanced features

### Medium Priority (Quality of Life)

1. **Validation Systems** - Important for mod stability
2. **Statistical Functions** - Useful for balancing and analysis
3. **Template Systems** - Reduces repetitive code
4. **Sorting and Filtering** - Common operations

### Low Priority (Advanced Features)

1. **Economic Analysis** - Niche but powerful for overhaul mods
2. **Transaction System** - Complex to implement, limited use cases
3. **Performance Framework** - Important for large-scale mods
4. **Integration Framework** - Depends on community adoption

## Technical Considerations

### Backward Compatibility

All improvements should maintain backward compatibility with existing APIs. New features should be additive rather than
replacing existing functionality.

### Performance Impact

- Query builders should compile to efficient operations
- Caching systems must be optional and memory-conscious
- Batch operations should provide significant performance gains
- Statistical functions should be lazy-evaluated where possible

### Testing Requirements

Each improvement should include:

- Comprehensive unit tests
- Performance benchmarks
- Integration tests with existing functionality
- Documentation with examples

### API Design Principles

- Maintain fluent interface design
- Provide both simple and advanced APIs for each feature
- Use consistent naming conventions across modules
- Include comprehensive error handling and validation

## Conclusion

These improvements would transform khaoslib from a solid foundation into a comprehensive, powerful toolkit for Factorio
mod development. The enhancements focus on three main areas:

1. **Developer Experience** - Better APIs, validation, templates, and documentation
2. **Functionality** - Advanced queries, analysis tools, and cross-module operations
3. **Performance** - Batch operations, caching, and optimization frameworks

Implementation should be gradual, starting with high-priority core functionality improvements and building toward the
more advanced features. Each improvement should be thoroughly tested and documented to maintain the library's reputation
for reliability and ease of use.
