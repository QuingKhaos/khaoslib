# Examples Repository Concept

## Overview

The examples repository concept was designed to provide a separate, dedicated space for comprehensive, real-world usage
examples of khaoslib functionality. This would complement the API documentation with practical demonstrations and
complete working scenarios.

## Motivation

### Current Documentation Limitations

While the current documentation in `docs/` provides comprehensive API references, it primarily focuses on:

- Function signatures and parameters
- Brief usage snippets
- Technical specifications
- Individual method demonstrations

### What Examples Repository Would Provide

An examples repository would bridge the gap between API documentation and real-world usage by offering:

1. **Complete Working Examples**: Full mod implementations showing khaoslib in action
2. **Use Case Scenarios**: Specific problem-solving demonstrations
3. **Best Practices**: Proven patterns and approaches for common tasks
4. **Integration Examples**: How khaoslib works with other mods and Factorio systems
5. **Performance Benchmarks**: Real-world performance comparisons and optimizations

## Proposed Structure

```text
khaoslib-examples/
├── README.md
├── basic-examples/
│   ├── simple-recipe-modification/
│   ├── technology-unlocks/
│   └── list-management/
├── advanced-examples/
│   ├── complex-recipe-chains/
│   ├── dynamic-technology-trees/
│   └── conditional-modifications/
├── integration-examples/
│   ├── with-other-libraries/
│   ├── mod-compatibility/
│   └── cross-mod-integration/
├── performance-examples/
│   ├── benchmarks/
│   ├── optimization-techniques/
│   └── large-scale-modifications/
└── real-world-scenarios/
    ├── overhaul-mods/
    ├── quality-of-life-improvements/
    └── content-expansion/
```

## Example Categories

### 1. Basic Examples

**Target Audience**: New users learning khaoslib fundamentals

- **Simple Recipe Modification**: Adding/removing ingredients, changing results
- **Technology Unlocks**: Basic recipe-technology relationships
- **List Management**: Common list manipulation patterns

```lua
-- Example: basic-examples/simple-recipe-modification/data.lua
local khaoslib_recipe = require("__khaoslib__.recipe")

-- Make iron gear wheels require steel instead of iron
khaoslib_recipe.get("iron-gear-wheel")
  :remove_ingredient("iron-plate")
  :add_ingredient("steel-plate", 2)
  :commit()
```

### 2. Advanced Examples

**Target Audience**: Experienced modders tackling complex scenarios

- **Complex Recipe Chains**: Multi-step recipe modifications with dependencies
- **Dynamic Technology Trees**: Conditional technology unlocks based on other mods
- **Conditional Modifications**: Runtime recipe changes based on game state

```lua
-- Example: advanced-examples/complex-recipe-chains/data.lua
local khaoslib_recipe = require("__khaoslib__.recipe")
local khaoslib_tech = require("__khaoslib__.technology")

-- Create a complex production chain for advanced circuits
local recipes_to_modify = {
  "electronic-circuit",
  "advanced-circuit",
  "processing-unit"
}

for _, recipe_name in ipairs(recipes_to_modify) do
  khaoslib_recipe.get(recipe_name)
    :multiply_ingredient_amounts(1.5)
    :add_ingredient("rare-metals", math.ceil(recipe_name == "processing-unit" and 3 or 1))
    :unlock_with_technology("advanced-electronics-" .. (recipe_name:gsub("-", "_")))
    :commit()
end
```

### 3. Integration Examples

**Target Audience**: Mod developers working in complex mod environments

- **With Other Libraries**: Using khaoslib alongside other popular modding libraries
- **Mod Compatibility**: Ensuring modifications work with popular overhaul mods
- **Cross-Mod Integration**: Dynamic modifications based on detected mods

```lua
-- Example: integration-examples/with-other-libraries/data.lua
local khaoslib_recipe = require("__khaoslib__.recipe")

-- Integration with popular mods
if mods["bobplates"] then
  -- Modify recipes to use Bob's materials
  khaoslib_recipe.get("electronic-circuit")
    :remove_ingredient("iron-plate")
    :add_ingredient("tinned-copper-cable", 2)
    :commit()
end

if mods["angelssmelting"] then
  -- Adjust for Angel's smelting arrays
  local smelting_recipes = khaoslib_recipe.find(function(recipe)
    return recipe.category == "smelting"
  end)

  for _, recipe in ipairs(smelting_recipes) do
    recipe:multiply_ingredient_amounts(2)
         :multiply_result_amounts(3)
         :commit()
  end
end
```

### 4. Performance Examples

**Target Audience**: Developers optimizing large-scale modifications

- **Benchmarks**: Performance comparisons between different approaches
- **Optimization Techniques**: Best practices for handling large datasets
- **Large-Scale Modifications**: Efficiently modifying hundreds of recipes/technologies

```lua
-- Example: performance-examples/large-scale-modifications/data.lua
local khaoslib_recipe = require("__khaoslib__.recipe")

-- Efficient batch processing approach
local function batch_modify_recipes(recipe_names, modification_func)
  local batch = {}

  for _, name in ipairs(recipe_names) do
    local recipe = khaoslib_recipe.get(name)
    modification_func(recipe)
    table.insert(batch, recipe)
  end

  -- Commit all at once for better performance
  khaoslib_recipe.commit_batch(batch)
end

-- Process 200+ recipes efficiently
local all_recipes = khaoslib_recipe.get_all_names()
batch_modify_recipes(all_recipes, function(recipe)
  recipe:multiply_energy_required(0.8) -- 20% faster crafting
end)
```

### 5. Real-World Scenarios

**Target Audience**: All users looking for proven solutions to common modding challenges

- **Overhaul Mods**: Complete game balance overhauls
- **Quality of Life**: Improving game experience without major changes
- **Content Expansion**: Adding new content that integrates seamlessly

```lua
-- Example: real-world-scenarios/quality-of-life-improvements/data.lua
local khaoslib_recipe = require("__khaoslib__.recipe")
local khaoslib_tech = require("__khaoslib__.technology")

-- Quality of life: Make early game less grindy
local early_game_improvements = {
  ["iron-gear-wheel"] = {energy = 0.3, amount_multiplier = 2},
  ["copper-cable"] = {energy = 0.3, amount_multiplier = 3},
  ["electronic-circuit"] = {energy = 0.4, amount_multiplier = 1.5}
}

for recipe_name, improvements in pairs(early_game_improvements) do
  khaoslib_recipe.get(recipe_name)
    :set_energy_required(improvements.energy)
    :multiply_result_amounts(improvements.amount_multiplier)
    :commit()
end

-- Earlier access to quality of life technologies
khaoslib_tech.get("automation")
  :set_research_unit_count(50) -- Reduced from 10
  :commit()
```

## Benefits of Separate Repository

### 1. **Focused Learning Path**

- Progressive complexity from basic to advanced
- Self-contained examples that can be copied and modified
- Clear separation between "how to use" and "what it does"

### 2. **Community Contributions**

- Users can contribute their own working examples
- Real-world solutions to common problems
- Peer review of best practices

### 3. **Maintenance Isolation**

- Examples can be updated independently of core library
- Broken examples don't affect library stability
- Version-specific examples for different Factorio/khaoslib versions

### 4. **Comprehensive Testing Ground**

- Examples serve as integration tests
- Real-world usage patterns validate API design
- Community feedback on usability

## Implementation Considerations

### Repository Management

- **Versioning**: Tag examples with compatible khaoslib versions
- **Testing**: Automated testing to ensure examples work with current khaoslib
- **Documentation**: Each example should have its own README with:
  - Purpose and use case
  - Prerequisites and dependencies
  - Step-by-step explanation
  - Expected results and screenshots

### Quality Standards

- **Code Quality**: Examples should follow best practices
- **Documentation**: Clear explanations and comments
- **Completeness**: Working examples, not just code snippets
- **Maintenance**: Regular updates for compatibility

### Community Engagement

- **Contribution Guidelines**: Clear process for submitting examples
- **Review Process**: Community and maintainer review
- **Recognition**: Credit contributors appropriately
- **Feedback Loop**: Channel user feedback back to main library

## Current Alternative: Inline Examples

Until an examples repository is created, the current approach uses:

1. **API Documentation Examples**: Brief snippets in `docs/` files
2. **README Examples**: Key usage patterns in the main README
3. **Code Comments**: Internal documentation within the library itself

This provides basic guidance but lacks the comprehensive, real-world scenarios that a dedicated examples repository
would offer.

## Future Implementation

When ready to implement this concept:

1. **Create Repository**: Set up `khaoslib-examples` repository
2. **Initial Examples**: Port and expand current documentation examples
3. **Community Guidelines**: Establish contribution and review processes
4. **Cross-Reference**: Link from main library documentation to relevant examples
5. **Maintenance Plan**: Establish process for keeping examples up-to-date

## Conclusion

The examples repository concept addresses the gap between API documentation and real-world usage. While not immediately
necessary for khaoslib's functionality, it would significantly improve the developer experience by providing
comprehensive, practical guidance for common and complex use cases.

The concept prioritizes practical learning, community contribution, and real-world problem-solving over theoretical
documentation, making khaoslib more accessible to developers of all skill levels.
