# The `where` Option Concept

## Overview

The `where` option is a proposed future enhancement for khaoslib's recipe manipulation functions that would provide
SQL-like filtering capabilities for more expressive and intuitive result manipulation.

## Current State vs. Proposed Enhancement

### Current API

```lua
-- Remove by name
recipe:remove_result("item-name")

-- Remove with custom comparison function
recipe:remove_result(function(result)
  return result.name == "item-name" and result.amount > 5
end)

-- Remove with options
recipe:remove_result("item-name", {first_only = true})
```

### Proposed `where` Option

```lua
-- More expressive filtering with where clause
recipe:remove_result("any", {
  where = function(result)
    return result.amount > 10 and result.probability and result.probability < 0.5
  end
})

-- Combine with existing options
recipe:remove_result("any", {
  where = function(result) return result.amount > 5 end,
  first_only = true
})

-- Complex Factorio-specific filtering
recipe:remove_result("any", {
  where = function(result)
    return result.probability and result.probability < 0.1 and result.temperature and result.temperature > 100
  end
})
```

## Design Rationale

### 1. Enhanced Expressiveness

The `where` option provides a more declarative way to filter results:

- **Intuitive**: Reads naturally as "remove result where condition"
- **Expressive**: Handles complex multi-condition filtering elegantly
- **Familiar**: Follows SQL-like patterns most developers understand

### 2. Separation of Concerns

```lua
recipe:remove_result("item-name", {
  where = function(result) return result.amount > 5 end,  -- What to filter
  first_only = true                                      -- How to apply
})
```

This separates:

- **What to match**: The base comparison (item name, function, etc.)
- **Additional filtering**: The `where` clause for complex conditions
- **Operation scope**: Options like `first_only`, `max_count`, etc.

### 3. Future Extensibility

The `where` option works alongside other potential future options:

```lua
recipe:remove_result("item-name", {
  where = function(result) return result.amount > 5 end,
  first_only = true,
  max_count = 3,        -- Future: limit number of operations
  at_indices = {1, 3},  -- Future: operate on specific positions
  dry_run = true        -- Future: preview changes without applying
})
```

## Use Cases in Factorio Context

### 1. Probability-Based Filtering

```lua
-- Remove all low-probability byproducts
recipe:remove_result("any", {
  where = function(result)
    return result.probability and result.probability < 0.1
  end
})
```

### 2. Temperature-Dependent Results

```lua
-- Remove results that require high temperatures
recipe:remove_result("any", {
  where = function(result)
    return result.temperature and result.temperature > 500
  end
})
```

### 3. Catalyst Management

```lua
-- Remove catalyst results (items that return to input)
recipe:remove_result("any", {
  where = function(result)
    return result.catalyst_amount and result.catalyst_amount > 0
  end
})
```

### 4. Complex Multi-Condition Filtering

```lua
-- Remove expensive, low-yield results
recipe:remove_result("any", {
  where = function(result)
    return result.amount < 2 and
           result.probability and result.probability < 0.3 and
           (result.temperature or 0) > 200
  end
})
```

## Implementation Considerations

### Advantages

1. **Readable Code**: Self-documenting filtering logic
2. **Powerful**: Handles arbitrarily complex conditions
3. **Consistent**: Follows established options table pattern
4. **Extensible**: Plays well with future enhancements

### Potential Drawbacks

1. **Redundancy**: Overlaps with existing comparison function parameter
2. **Complexity**: Adds another way to do the same thing
3. **Learning Curve**: Users need to understand both approaches

### Current Alternative

The existing comparison function parameter already provides the same functionality:

```lua
-- Current way (works now)
recipe:remove_result(function(result)
  return result.amount > 10 and result.probability and result.probability < 0.5
end)

-- Proposed way (hypothetical)
recipe:remove_result("any", {
  where = function(result)
    return result.amount > 10 and result.probability and result.probability < 0.5
  end
})
```

## Decision Framework

### When to Implement

- **User Demand**: Multiple requests for more expressive filtering
- **Complex Use Cases**: Real scenarios that benefit from the separation
- **API Maturity**: After core functionality is stable and well-tested

### When to Skip

- **YAGNI**: If current comparison functions meet all real use cases
- **API Bloat**: If it just adds complexity without clear benefit
- **Maintenance Burden**: If it significantly increases testing/documentation overhead

## Recommendation

### Status: Hold for Future Consideration

The `where` option demonstrates the flexibility of the options table design but should only be implemented if:

1. Real use cases emerge that clearly benefit from this approach
2. User feedback indicates the current API is insufficient
3. The benefits outweigh the added complexity

For now, the existing comparison function parameter provides all necessary functionality while keeping the API focused
and manageable.

## Related Concepts

### Future Option Ideas

- `max_count`: Limit number of operations performed
- `at_indices`: Operate on specific array positions
- `dry_run`: Preview changes without applying them
- `callback`: Execute function on each matched item

### Database-Inspired Patterns

```lua
-- SELECT-like operations
local matching = recipe:get_matching_results("any", {
  where = function(r) return r.amount > 5 end
})

-- UPDATE-like operations
recipe:replace_result("any", new_result, {
  where = function(r) return r.probability < 0.1 end
})

-- DELETE-like operations
recipe:remove_result("any", {
  where = function(r) return r.temperature > 1000 end
})
```

This pattern could potentially extend to ingredients and other khaoslib modules for consistency across the entire API.
