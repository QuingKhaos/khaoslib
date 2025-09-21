# khaoslib v0.2.0 Release Roadmap

## Overview

This document outlines the comprehensive roadmap for khaoslib v0.2.0, the
foundational release that establishes the core manipulator-first API design
with the introduction of new List, Recipe, and Technology modules. This release
represents the initial implementation of these modules with a focus on
consistency, usability, and robust error handling.

**Release Status**: In Development (Resolving Module Inconsistencies)
**Branch**: `main`

## Release Goals

### Primary Objectives

1. **Module Consistency**: Establish consistent API patterns across all modules
2. **Manipulator-First Design**: Implement fluent, chainable APIs for prototype
   manipulation
3. **Deep Copy Safety**: Ensure data stage safety through comprehensive deep
   copying
4. **Comprehensive Testing**: Achieve >95% test coverage with robust unit tests
5. **Professional Documentation**: Complete, accurate documentation for all
   features

### Success Criteria

- [ ] All modules follow identical API patterns and terminology
- [ ] 100% test pass rate across all supported Lua versions (5.2, 5.4)
- [ ] Zero linting errors across all files
- [ ] Complete documentation with working examples
- [ ] Successful CI/CD pipeline execution

## Core Features

### List Module

**Purpose**: Reusable utilities for list manipulation with consistent behavior
across Factorio mods

**Key Features**:

- String-based and function-based comparison logic
- Automatic deep copying for data safety
- Duplicate prevention and bulk operations
- Nil-safe operations with graceful error handling

### Recipe Module

**Purpose**: Comprehensive API for manipulating Factorio recipe prototypes
during the data stage

**Key Features**:

- Method chaining with fluent API design
- Flexible loading (existing recipes or new prototypes)
- Ingredient and result management with duplicate prevention
- Technology integration (recipe-technology unlock relationships)
- Comprehensive validation and error handling

### Technology Module

**Purpose**: Comprehensive API for manipulating Factorio technology prototypes
during the data stage

**Key Features**:

- Method chaining with fluent API design
- Prerequisite management with duplicate prevention
- Effect management for all effect types
- Science pack cost manipulation
- Discovery utilities and existence checking

## Critical Issues to Resolve

### Module Inconsistency Issues

Based on the current codebase analysis, the following inconsistencies need to
be addressed:

#### 1. API Pattern Alignment

**Issue**: Different modules may use different naming conventions or parameter
patterns

**Resolution Tasks**:

- [ ] Audit all module APIs for consistency
- [ ] Standardize parameter naming (e.g., `options` table patterns)
- [ ] Ensure consistent return value patterns
- [ ] Align error message formats

#### 2. Error Handling Standardization

**Issue**: Inconsistent error handling approaches across modules

**Resolution Tasks**:

- [ ] Establish common error handling patterns
- [ ] Standardize error message formats and terminology
- [ ] Ensure consistent parameter validation
- [ ] Implement consistent nil-safety checks

#### 3. Deep Copy Implementation

**Issue**: Potential inconsistencies in deep copying implementation

**Resolution Tasks**:

- [ ] Audit deep copy usage across all modules
- [ ] Ensure consistent deep copy implementation
- [ ] Verify data stage safety guarantees
- [ ] Test edge cases with complex nested structures

#### 4. Options Table Patterns

**Issue**: Inconsistent options table usage and structure

**Resolution Tasks**:

- [ ] Standardize options table parameter names
- [ ] Ensure consistent default behavior
- [ ] Align optional parameter handling
- [ ] Document options table patterns clearly

## Development Phases

### Phase 1: API Consistency (Critical Priority)

#### Module API Audit

- [ ] **List Module**: Review function signatures, parameter naming, options
  tables, error messages
- [ ] **Recipe Module**: Review method signatures, manipulator patterns,
  technology integration, parameter validation
- [ ] **Technology Module**: Review method signatures, prerequisite/effect
  management, science pack APIs, discovery utilities

#### Terminology Standardization

- [ ] Create terminology dictionary for consistent naming
- [ ] Update all modules to use standardized terms
- [ ] Ensure consistent documentation language
- [ ] Update error messages to use standard terminology

### Phase 2: Implementation Fixes (High Priority)

#### Deep Copy Safety

- [ ] Implement shared deep copy utilities
- [ ] Audit all deep copy usage points
- [ ] Test deep copy with complex prototype structures
- [ ] Verify no reference sharing between manipulators

#### Error Handling Enhancement

- [ ] Implement standardized error handling framework
- [ ] Update all modules to use consistent error patterns
- [ ] Improve error message clarity and actionability
- [ ] Add comprehensive parameter validation

#### Options Table Standardization

- [ ] Define standard options table patterns
- [ ] Update all functions to use consistent options handling
- [ ] Implement default value handling consistently
- [ ] Document options table usage patterns

### Phase 3: Testing and Validation (High Priority)

#### Unit Test Enhancement

- [ ] **List Module**: Expand coverage to >95%, edge cases, options testing,
  error scenarios
- [ ] **Recipe Module**: Test manipulator operations, technology integration,
  complex scenarios, error conditions
- [ ] **Technology Module**: Test prerequisite/effect operations, science pack
  manipulation, discovery utilities, complex scenarios

#### Integration Testing

- [ ] Cross-module integration tests
- [ ] Recipe-technology integration scenarios
- [ ] Complex manipulation workflow tests
- [ ] Performance testing with large datasets

### Phase 4: Documentation and Polish (Medium Priority)

#### Documentation Updates

- [ ] Update README.md with accurate feature descriptions
- [ ] Create comprehensive API documentation
- [ ] Update inline code documentation
- [ ] Create usage examples and tutorials

#### Code Quality

- [ ] Resolve all linting issues
- [ ] Optimize performance where possible
- [ ] Clean up code structure and organization
- [ ] Add comprehensive inline comments

## Quality Assurance

### Testing Strategy

- **Unit Tests**: >95% code coverage target
- **Integration Tests**: Cross-module functionality
- **CI Pipeline**: Lua 5.2 and 5.4 compatibility testing
- **Linting**: Zero luacheck and markdownlint errors
- **Manual Testing**: Real-world scenarios, edge cases, performance testing

### Release Validation Checklist

#### Code Standards

- [ ] All automated tests pass (100% success rate)
- [ ] Zero linting errors across all files
- [ ] Code coverage >95% achieved
- [ ] Performance benchmarks meet expectations

#### Documentation Quality

- [ ] All public APIs documented with examples
- [ ] README.md accurately reflects current features
- [ ] Changelog updated with complete feature list
- [ ] Code comments clear and comprehensive

#### API Consistency

- [ ] All modules follow identical patterns
- [ ] Terminology used consistently throughout
- [ ] Error handling standardized across modules
- [ ] Options table usage consistent

## Release Process

### Pre-Release Tasks

- [ ] **Final API Review**: Comprehensive review of all public APIs
- [ ] **Version Alignment**: Ensure info.json, README.md, and references are
  consistent
- [ ] **Changelog Finalization**: Complete changelog with proper categorization
- [ ] **Documentation Review**: Final review of all documentation

### Release Execution

- [ ] **Tag Creation**: Create and push release tag
- [ ] **GitHub Release**: Automated release with changelog and package
- [ ] **Mod Portal**: Prepare package for Factorio mod portal submission
- [ ] **Communication**: Announce release to community channels

### Post-Release Tasks

- [ ] **Community Monitoring**: Monitor for bug reports and feedback
- [ ] **Documentation Updates**: Address any documentation issues
- [ ] **Bug Fix Planning**: Plan immediate bug fixes if needed
- [ ] **Rapid Iteration Planning**: Prepare for quick follow-up releases

## Risk Assessment

### Technical Risks

**High Risk**:

- **Module Inconsistencies**: Could delay release significantly
  - *Mitigation*: Comprehensive API audit and standardization process
- **Testing Coverage**: Inadequate testing could lead to post-release bugs
  - *Mitigation*: Aggressive testing strategy with >95% coverage target

**Medium Risk**:

- **Performance Issues**: Deep copying could impact performance
  - *Mitigation*: Performance testing and optimization where needed
- **Documentation Quality**: Poor documentation could hurt adoption
  - *Mitigation*: Comprehensive documentation review process

**Low Risk**:

- **CI/CD Issues**: Pipeline failures could delay release
  - *Mitigation*: Thorough CI/CD testing and backup plans

### Community Risks

- **Learning Curve**: New API might be complex for users
  - *Mitigation*: Comprehensive examples and tutorials
- **Feature Discovery**: Users might not be aware of new capabilities
  - *Mitigation*: Clear documentation highlighting new modules and their benefits

## Success Metrics

### Release Success Indicators

- **Zero Critical Bugs**: No critical issues in first week after release
- **Community Adoption**: Positive feedback from early adopters
- **Test Coverage**: Maintained >95% code coverage
- **Documentation Quality**: Comprehensive and accurate documentation

### Post-Release Metrics

- **Download Growth**: Increasing mod portal downloads
- **Community Engagement**: Active discussions and feedback
- **Bug Report Rate**: Low and decreasing bug report frequency
- **Developer Satisfaction**: Positive sentiment from library users

## Future Planning

### v0.2.1+ Rapid Iterations

- Prepare for daily/weekly patch releases as needed
- Incorporate user feedback quickly
- Address issues discovered in real-world usage
- Implement minor enhancements based on usage patterns

### v0.3.0 Foundation

- Begin planning static utility functions
- Consider API improvements based on v0.2.0 experience
- Identify performance optimization opportunities
- Plan community-requested features

---

*This roadmap is a living document, updated as development progresses and*
*issues are discovered.*
