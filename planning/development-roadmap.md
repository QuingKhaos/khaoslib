# khaoslib Development Roadmap

## Overview

This roadmap outlines the planned development trajectory for khaoslib following Semantic Versioning 2.0.0.
The library follows a stability guarantee where **0.x APIs should not be considered completely stable**,
allowing for possible breaking changes in minor releases when necessary (with proper documentation
and announcements).

The development philosophy emphasizes **rapid iterations** with very frequent releases rather than
accumulating many changes in large releases. This approach enables:

- Immediate availability of new features for active mod development
- Faster feedback cycles from the Factorio modding community
- Reduced risk of introducing complex bugs
- Support for active parallel mod development requiring new khaoslib features

**Release Philosophy**: Release cycles can be days or even hours apart when needed, with multiple releases
per day possible to support active mod development needs.

## Factorio Modding Environment Constraints

**Single Version Dependency**: Unlike modern package managers, Factorio allows only one active version of
a given mod. All mods using khaoslib will use the version determined by:

- Intersection of minimum version constraints from all dependent mods
- User's mod update frequency
- Highest compatible version available

This means backward compatibility is critical even in 0.x releases, as breaking changes can prevent
mod ecosystem combinations from working together.

**Roadmap Impact**: While this roadmap shows major feature versions, the actual development will include
many more intermediate releases (v0.2.1, v0.2.2, etc.) to support active mod development needs.

## Current State: v0.2.0 (In Development)

**Status**: In development, resolving module inconsistencies
**Branch**: `main`
**Key Features**: Complete rewrite with List, Recipe, and Technology modules

### v0.2.0 Release Tasks

#### Critical Priority - Release Blockers

- [ ] **Module Consistency**: Resolve inconsistencies between List, Recipe, and Technology modules
- [ ] **API Alignment**: Ensure consistent patterns across all modules
- [ ] **Final QA Pass**: Complete linting resolution and CI validation
- [ ] **Documentation Review**: Ensure all module documentation is accurate and complete
- [ ] **Changelog Finalization**: Set release date and complete changelog entries
- [ ] **Version Alignment**: Verify info.json, README.md, and all references are consistent

## Intermediate Releases (v0.2.1 - v0.2.x)

**Expected**: Many incremental releases between major feature versions

As khaoslib is actively used for parallel mod development, there will be numerous patch and minor
releases between the major feature versions listed below. These releases will include:

- Bug fixes discovered during active mod development
- Small feature additions needed for immediate mod development needs
- API consistency improvements identified during real-world usage
- Performance optimizations based on actual usage patterns

**Release Frequency**: Multiple releases per week/day as needed for active development

## v0.3.0: Functional Replacement API

**Theme**: Dynamic replacement functions with callback support
**Priority**: High - Addresses critical pain points in mod compatibility workflows
**Rationale**: Based on extensive analysis of Pyanodons/AAI compatibility patterns, functional replacements
dramatically reduce boilerplate and improve maintainability for dynamic ingredient/prerequisite transformations.
**Design Document**: `planning/functional-replacement-api.md`

### v0.3.0 Features

#### High Priority - Critical developer experience improvement

- [ ] **Enhanced List Module Foundation**

  ```lua
  -- Core functional replacement support in khaoslib_list.replace()
  khaoslib_list.replace(ingredients, function(ingredient)
      ingredient.name = "electronic-circuit"
      ingredient.amount = ingredient.amount * 2  -- Double amount for balance
      return ingredient
  end, "processing-unit")
  ```

- [ ] **Recipe Module Functional Replacements** (Automatic inheritance from list module)

  ```lua
  -- Dynamic ingredient replacement based on original properties
  recipe:replace_ingredient("processing-unit", function(ingredient)
      ingredient.name = "electronic-circuit"
      return ingredient  -- Preserves original amount automatically
  end)

  -- Conditional transformations
  recipe:replace_ingredient("advanced-circuit", function(ingredient)
      if ingredient.amount >= 5 then
          ingredient.name = "processing-unit"
          ingredient.amount = math.ceil(ingredient.amount / 2)
      end
      return ingredient
  end)
  ```

- [ ] **Technology Module Functional Replacements** (Automatic inheritance from list module)

  ```lua
  -- Dynamic prerequisite replacement for overhaul mod compatibility
  technology:replace_prerequisite("advanced-electronics-2", function(prereq)
      return "electronics"  -- Simplify for early game accessibility
  end)

  -- Science pack cost adjustments based on difficulty settings
  technology:replace_science_pack("space-science-pack", function(science_pack)
      if settings.startup["difficulty-mode"].value == "easy" then
          science_pack.amount = math.ceil(science_pack.amount * 0.5)
      end
      return science_pack
  end)
  ```

### v0.3.0 Implementation Strategy

- **Architectural Advantage**: Only requires enhancement to `khaoslib_list.replace()` function
- **Zero Breaking Changes**: Recipe and technology modules automatically inherit functionality through delegation
- **Documentation Updates**: Update `@param` annotations to reflect functional parameter support
- **Performance Optimized**: <5% overhead for function-based replacements vs table-based replacements

### v0.3.0 Key Benefits

- **Dramatically Improved Ergonomics**: Reduce 10+ line operations to 3-5 lines
- **Commit-Based Architecture Synergy**: Access original recipe data even after remove operations
- **Complex Consolidation Support**: Enable CompaktCircuit-style multi-ingredient consolidation patterns
- **Maintainable**: Automatically adapts when base game recipes change
- **Minimal Implementation**: Single point of implementation reduces maintenance burden

## v0.4.0: Static Utility Functions Enhancement

**Theme**: Complementary API for analysis and discovery use cases
**Rationale**: Based on real-world analysis of Factorio modding ecosystem (Pyanodons, Krastorio2), static
utilities provide value for analysis-heavy operations while preserving the manipulator-first design for
modifications.

### v0.4.0 Features

#### High Priority - Proven demand from ecosystem analysis

- [ ] **Recipe Static Utilities**

  ```lua
  -- Efficient analysis without manipulator overhead
  local has_wood = khaoslib_recipe.has_ingredient("iron-plate", "wood")
  local wood_recipes = khaoslib_recipe.find_by_ingredient("wood")
  local tech_recipes = khaoslib_recipe.find_by_unlock("electronics")
  ```

- [ ] **Technology Static Utilities**

  ```lua
  -- Discovery and compatibility checking
  local military_techs = khaoslib_technology.find_by_pattern("^military%-")
  local unlocks_recipe = khaoslib_technology.find_by_unlock_recipe("steel-plate")
  local prereq_chain = khaoslib_technology.get_prerequisite_chain("space-science-pack")
  ```

- [ ] **List Query Builder** (Based on module-improvements.md analysis)

  ```lua
  -- Advanced querying for complex filtering
  local fluid_inputs = khaoslib_list.query(ingredients)
    :where("type", "fluid")
    :where("amount", ">", 100)
    :get_all()
  ```

### v0.4.0 Implementation Strategy

- **Backward Compatibility**: Static functions are additive, no breaking changes to existing manipulator API
- **Performance Focus**: Direct data.raw access for read-only operations
- **Consistent API**: Follow established khaoslib patterns and terminology
- **Comprehensive Testing**: Unit tests for all static utility functions

## v0.5.0: Advanced List Operations

**Theme**: Enhanced data manipulation and aggregation capabilities
**Rationale**: Based on module-improvements.md analysis showing demand for statistical and query operations

### v0.5.0 Features

#### Medium Priority - Quality of life improvements for complex data manipulation

- [ ] **Statistical Functions**

  ```lua
  -- Aggregation operations for recipe analysis
  local total_iron = khaoslib_list.sum(ingredients, "amount")
  local avg_cost = khaoslib_list.average(science_packs, function(pack) return pack[2] end)
  local unique_types = khaoslib_list.unique(ingredients, "type")
  ```

- [ ] **Advanced Sorting and Grouping**

  ```lua
  -- Complex data organization
  local by_type = khaoslib_list.group_by(ingredients, "type")
  local sorted = khaoslib_list.sort_by(results, "amount", "desc")
  ```

- [ ] **Set Operations**

  ```lua
  -- Set algebra for recipe ingredient comparison
  local common = khaoslib_list.intersection(recipe1_ingredients, recipe2_ingredients)
  local unique_to_recipe1 = khaoslib_list.difference(recipe1_ingredients, recipe2_ingredients)
  ```

### v0.5.0 Implementation Strategy

- **Non-Breaking**: All new functions, existing list API unchanged
- **Functional Programming Style**: Consistent with current list module design
- **Performance Optimized**: Efficient algorithms for large prototype datasets

## v0.6.0: Copy-on-Write Optimization

**Theme**: Memory optimization for large-scale modding operations
**Rationale**: Based on copy-on-write-optimization.md analysis, provides significant memory savings for
read-heavy workloads in complex modpacks

### v0.6.0 Features

#### Low-Medium Priority - Performance optimization for advanced use cases

- [ ] **CoW Recipe Manipulators**
  - Share data.raw references until first write operation
  - Automatic deep copy on modification
  - Transparent to existing API users

- [ ] **CoW Technology Manipulators**
  - Same CoW semantics as recipe manipulators
  - Enhanced introspection for debugging CoW state

- [ ] **Performance Monitoring**

  ```lua
  -- Debug utilities for CoW state tracking
  local stats = khaoslib_recipe:load("iron-plate"):get_cow_stats()
  -- {is_cow: true, copy_count: 0, memory_saved: 1024}
  ```

### v0.6.0 Implementation Challenges

- **Complexity**: Significant internal architecture changes required
- **Testing**: Comprehensive testing for CoW state transitions
- **Debugging**: Enhanced error reporting for CoW-related issues
- **Backward Compatibility**: Must be transparent to existing code

## v0.7.0: Multi-Prototype Support

**Theme**: Extend manipulator pattern to other prototype types
**Rationale**: Based on Pyanodons analysis showing ITEM, FLUID, ENTITY patterns alongside RECIPE/TECHNOLOGY

### v0.7.0 Features

#### Medium Priority - Ecosystem demand for consistent prototype manipulation

- [ ] **Item Manipulators**

  ```lua
  local item = khaoslib_item:load("iron-plate")
    :set({stack_size = 200})
    :add_flag("hidden")
    :commit()
  ```

- [ ] **Fluid Manipulators**

  ```lua
  local fluid = khaoslib_fluid:load("crude-oil")
    :set({default_temperature = 25})
    :set_base_color({r = 0.1, g = 0.1, b = 0.1})
    :commit()
  ```

- [ ] **Entity Manipulators** (Selective - high-demand entities only)

  ```lua
  local assembler = khaoslib_entity:load("assembling-machine-1")
    :set_crafting_speed(0.75)
    :add_crafting_category("advanced-crafting")
    :commit()
  ```

### v0.7.0 Implementation Strategy

- **Proven Pattern**: Apply successful recipe/technology manipulator architecture
- **Selective Implementation**: Focus on most commonly manipulated entity types
- **Consistent API**: Maintain khaoslib design patterns and terminology

## v0.8.0: Advanced Integration Features

**Theme**: Cross-prototype relationships and complex operations
**Rationale**: Support for overhaul-level modding with complex interdependencies

### v0.8.0 Features

#### Low Priority - Advanced use cases for overhaul mods

- [ ] **Dependency Graph Analysis**

  ```lua
  -- Analyze prototype interdependencies
  local deps = khaoslib.analyze_dependencies("space-science-pack")
  local cycles = khaoslib.find_circular_dependencies()
  ```

- [ ] **Bulk Operations Framework**

  ```lua
  -- Mass modification operations
  khaoslib.bulk_operation()
    :target_recipes(function(recipe) return recipe.category == "smelting" end)
    :modify(function(recipe) recipe:multiply_energy(1.5) end)
    :commit_all()
  ```

- [ ] **Template System**

  ```lua
  -- Reusable prototype templates
  local smelting_template = khaoslib.template("smelting-recipe")
    :set_category("smelting")
    :set_energy(3.2)
    :build()

  khaoslib_recipe:from_template(smelting_template, "steel-plate-smelting")
    :add_ingredient({type = "item", name = "iron-ore", amount = 1})
    :commit()
  ```

## v0.9.0: Developer Experience Enhancement

**Theme**: Improved debugging, validation, and development workflow
**Rationale**: Better tooling for mod developers using khaoslib

### v0.9.0 Features

#### Low-Medium Priority - Developer quality of life

- [ ] **Enhanced Validation**
  - Comprehensive prototype validation with detailed error messages
  - Integration with Factorio's prototype validation system
  - Custom validation rules for mod-specific requirements

- [ ] **Debug Utilities**
  - Prototype diff visualization
  - Manipulator state inspection
  - Performance profiling for prototype operations

- [ ] **Development Mode Features**
  - Verbose logging for development builds
  - Integration with VS Code debugging tools
  - Automated testing helpers for mod developers

## v0.10.0: Stability and Polish

**Theme**: API stabilization preparing for v1.0.0
**Rationale**: Final refinements before committing to stable API

### v0.10.0 Features

#### High Priority - Pre-1.0 stabilization

- [ ] **API Audit**: Comprehensive review of all public APIs for consistency
- [ ] **Performance Optimization**: Final performance tuning based on real-world usage
- [ ] **Documentation Completion**: Complete reference documentation for all features
- [ ] **Breaking Changes**: Final breaking changes needed for API consistency
- [ ] **Migration Guides**: Comprehensive upgrade guides for 0.x -> 1.0 transition

## v0.11.0+: Additional Feature Development

**Expected**: Continued 0.x development as needed

The roadmap may extend beyond v0.10.0 with additional 0.x versions (v0.11.0, v0.12.0, etc.) based on:

- Community feature requests and needs
- New Factorio modding capabilities or API changes
- Performance optimization opportunities
- Developer experience improvements

**Philosophy**: v1.0.0 will be released when the API is mature and stable, not at an arbitrary version number.

## v1.0.0: Stable API Release

**Theme**: First stable release with API compatibility guarantees
**Rationale**: Mature library ready for production use with stable API contracts

### Stability Guarantees (v1.0+)

- **Semantic Versioning**: Strict adherence to semver 2.0.0
- **Backward Compatibility**: No breaking changes in minor/patch releases
- **Deprecation Policy**: Minimum 6-month deprecation period for API changes
- **LTS Support**: Long-term support for major versions

**Target Release**: When API is mature and stable (TBD based on 0.x evolution)

## Future Considerations (v2.0+)

### Potential Future Themes

- **Plugin Architecture**: Extensible system for community-contributed prototype types
- **Advanced Scripting**: Runtime manipulation capabilities for scenario/campaign modding
- **Enhanced Performance**: Further optimization for complex modpack scenarios

### Technology Trends to Monitor

- **Factorio 2.1**: Potential future release with possible breaking changes to modding APIs
- **Modding Community Evolution**: Adapt roadmap based on community feedback and usage patterns
- **Performance Requirements**: Monitor memory and performance needs as modpacks grow in complexity

**Note**: Factorio development is expected to stabilize after potential 2.1 release, with no plans for
major version updates or Lua version changes.

## Release Strategy

### Release Cycle

- **Rapid Iteration**: Releases as needed, potentially multiple per day during active development
- **Feature-Driven**: New releases when features are needed for active mod development
- **Patch Releases**: Immediate releases for critical bug fixes
- **Pre-releases**: Optional, typically for major features or breaking changes

### 0.x Release Philosophy

Given the single-version constraint in Factorio's mod ecosystem, even 0.x releases should maintain
reasonable backward compatibility when possible. Breaking changes will be clearly documented and
communicated to the community.

### 0.x Release Strategy (Pre-1.0.0)

Since Semantic Versioning 2.0.0 provides no specific guidance for pre-1.0.0 releases, khaoslib follows
this strategy:

**Minor Version Releases (0.X.0)**:

- New features that expand the API surface
- New modules or manipulator types
- Significant performance improvements
- Breaking changes that improve API consistency or fix design flaws
- Major refactoring or architectural changes

**Patch Version Releases (0.x.Y)**:

- Bug fixes that don't change the API
- Performance optimizations that don't affect behavior
- Documentation improvements
- Internal code improvements without API changes
- Dependency updates

**Breaking Changes in 0.x**:

- Always increment minor version (0.X.0)
- Document breaking changes clearly in changelog
- Provide migration guidance when possible
- Consider community impact before making breaking changes

**Examples**:

- `0.2.0` → `0.2.1`: Bug fix in list module
- `0.2.1` → `0.2.2`: Performance optimization
- `0.2.2` → `0.3.0`: New static utility functions (API expansion)
- `0.3.0` → `0.4.0`: Breaking change to improve API consistency

### Quality Gates

Each release must pass:

- [ ] **Automated Testing**: 100% test pass rate
- [ ] **Documentation Review**: Complete and accurate documentation
- [ ] **Community Feedback**: Address feedback from pre-release testing when applicable
- [ ] **API Consistency**: Ensure new features follow established patterns

### Community Involvement

- **Public Roadmap**: This document maintained in GitHub for community visibility
- **Feature Requests**: Community input drives immediate development priorities
- **Rapid Feedback**: Quick response to community needs through fast release cycles
- **Breaking Change Communication**: Clear documentation of breaking changes in 0.x releases

## Success Metrics

### Library Adoption

- **Download Growth**: Steady increase in mod portal downloads
- **Community Usage**: Number of mods using khaoslib as dependency
- **Developer Feedback**: Positive sentiment in community channels

### Code Quality

- **Test Coverage**: >95% code coverage maintained
- **Bug Reports**: Decreasing trend in bug reports over time
- **Performance**: No performance regressions between releases

### Documentation Quality

- **Completeness**: All public APIs documented with examples
- **Community Contributions**: Community-contributed examples and tutorials
- **Community Engagement**: Positive activity in mod portal discussions and Discord mod-dev channels

## Risk Mitigation

### Technical Risks

- **Breaking Changes**: Comprehensive testing and migration guides
- **Performance Regressions**: Monitor performance through community feedback and profiling
- **Factorio API Changes**: Monitor Factorio development and adapt quickly

### Community Risks

- **Adoption Rate**: Focus on developer experience and clear documentation
- **Competing Solutions**: Monitor ecosystem and differentiate through quality
- **Maintenance Burden**: Automated testing and community contributions

### Resource Risks

- **Development Time**: Rapid iteration requires efficient development processes
- **Community Support**: Clear communication and responsive issue handling
- **Technical Debt**: Balance rapid releases with code quality maintenance
- **Ecosystem Compatibility**: Ensure releases don't break existing mod combinations

---

*This roadmap is a living document, updated as needed based on active development needs, community
feedback, and Factorio ecosystem evolution.*
