# List Module

The `list` module provides reusable utilities for list manipulation with consistent behavior across Factorio mods. It
supports both string-based and function-based comparison logic, with all functions that add or modify items using deep
copying to prevent unintended reference sharing.## Usage

```lua
local khaoslib_list = require("__khaoslib__.list")
```

## Comparison System

The module supports two comparison modes:

- **String comparison**: Direct equality check against item values
- **Function comparison**: Custom logic for complex matching (e.g., matching by property)

## Functions

### `has(list, compare)`

Checks if a list contains an item matching a comparison function or string.

**Parameters:**

- `list` (table|nil): The list to search in (can be nil, returns false)
- `compare` (function|string): A comparison function that receives an item and returns boolean, or a string for direct
  equality comparison

**Returns:**

- `boolean`: True if the list contains a matching item, false otherwise

**Examples:**

```lua
-- String comparison
local has_item = khaoslib_list.has({"a", "b", "c"}, "b") -- true

-- Function comparison
local recipes = {{name="iron-plate"}, {name="copper-plate"}}
local has_iron = khaoslib_list.has(recipes, function(item)
  return item.name == "iron-plate"
end) -- true
```

### `add(list, item, compare, options)`

Adds an item to a list with optional duplicate prevention.

By default, this function prevents duplicates by checking if an equivalent item already exists in the list. When
`allow_duplicates` is true, items are added directly without any duplicate checking. All added items are deep copied to
prevent unintended reference sharing.

**Parameters:**

- `list` (table|nil): The list to add to (will be created if nil)
- `item` (any): The item to add (will be deep copied)
- `compare` (function|string|nil): A comparison function that receives an item and returns boolean, or a string for
  direct equality comparison. Required when allow_duplicates is false, ignored when allow_duplicates is true.
- `options` (table?): Options table with the following fields:
  - `allow_duplicates` (boolean, default false): If true, skips duplicate checking and adds the item directly

**Returns:**

- `table`: The modified list (same reference as input, or new table if input was nil)

**Examples:**

```lua
local my_list = {"apple", "banana"}

-- Add with duplicate prevention (default behavior)
khaoslib_list.add(my_list, "cherry", "cherry") -- Adds "cherry" if not already present

-- Add allowing duplicates
khaoslib_list.add(my_list, "apple", nil, {allow_duplicates = true}) -- Always adds "apple"

-- Function comparison for complex objects
local recipes = {{name = "iron-plate"}}
khaoslib_list.add(recipes, {name = "copper-plate"}, function(r)
  return r.name == "copper-plate"
end)
```

### `remove(list, compare, options)`

Removes matching items from a list.

By default, removes only the first item that matches the comparison criteria. When `all` is true, removes all matching
items in a single call.

**Parameters:**

- `list` (table|nil): The list to remove from (returns empty table if nil)
- `compare` (function|string): A comparison function that receives an item and returns boolean, or a string for direct
  equality comparison
- `options` (table?): Options table with the following fields:
  - `all` (boolean, default false): If true, removes all matching items instead of just the first

**Returns:**

- `table`: The modified list (same reference as input, or empty table if input was nil)

**Examples:**

```lua
local my_list = {"apple", "banana", "apple", "cherry"}

-- Remove first matching item (default behavior)
khaoslib_list.remove(my_list, "apple") -- Removes first "apple", list becomes {"banana", "apple", "cherry"}

-- Remove all matching items
khaoslib_list.remove(my_list, "apple", {all = true}) -- Removes all "apple", list becomes {"banana", "cherry"}

-- Remove by function comparison
local recipes = {{name = "iron-plate"}, {name = "copper-plate"}}
khaoslib_list.remove(recipes, function(r)
  return r.name == "iron-plate"
end) -- Removes iron-plate recipe
```

### `replace(list, new_item, compare, options)`

Replaces matching items in a list with a new item.

By default, replaces only the first item that matches the comparison criteria. When `all` is true, replaces all matching
items in a single call. The new item is deep copied to prevent unintended reference sharing.

**Parameters:**

- `list` (table|nil): The list to modify (returns empty table if nil)
- `new_item` (any): The new item to replace with (will be deep copied)
- `compare` (function|string): A comparison function that receives an item and returns boolean, or a string for direct
  equality comparison
- `options` (table?): Options table with the following fields:
  - `all` (boolean, default false): If true, replaces all matching items instead of just the first

**Returns:**

- `table`: The modified list (same reference as input, or empty table if input was nil)

**Examples:**

```lua
local my_list = {"apple", "banana", "apple", "cherry"}

-- Replace first matching item (default behavior)
khaoslib_list.replace(my_list, "orange", "apple") -- Replaces first "apple", list becomes {"orange", "banana", "apple", "cherry"}

-- Replace all matching items
khaoslib_list.replace(my_list, "orange", "apple", {all = true}) -- Replaces all "apple", list becomes {"orange", "banana", "orange", "cherry"}

-- Replace by function comparison
local recipes = {{name = "iron-plate", amount = 1}, {name = "copper-plate", amount = 1}}
khaoslib_list.replace(recipes, {name = "iron-plate", amount = 2}, function(r)
  return r.name == "iron-plate"
end)
```

## Common Patterns

### Working with Recipe Results

A common use case is manipulating recipe results:

```lua
local recipe_results = {
  {type = "item", name = "iron-plate", amount = 1},
  {type = "item", name = "copper-plate", amount = 1}
}

-- Add a new result, allowing duplicates for multiple outputs
khaoslib_list.add(recipe_results, {type = "item", name = "steel-plate", amount = 1}, nil, {allow_duplicates = true})

-- Replace iron-plate result with higher amount
khaoslib_list.replace(recipe_results, {type = "item", name = "iron-plate", amount = 2}, function(result)
  return result.name == "iron-plate"
end)

-- Remove all copper-plate results
khaoslib_list.remove(recipe_results, function(result)
  return result.name == "copper-plate"
end, {all = true})
```

### Working with Technology Prerequisites

Managing technology dependencies:

```lua
local tech_prerequisites = {"logistics", "automation"}

-- Add a prerequisite if not already present
khaoslib_list.add(tech_prerequisites, "electronics", "electronics")

-- Remove a prerequisite
khaoslib_list.remove(tech_prerequisites, "logistics")

-- Replace a prerequisite
khaoslib_list.replace(tech_prerequisites, "automation-2", "automation")
```

## Best Practices

1. **Use function comparisons for complex objects**: When working with tables that have properties, use function
   comparisons to match by specific fields.

2. **Leverage the options table**: Use `{allow_duplicates = true}` when you want to allow multiple instances of the
   same item, and `{all = true}` when you need to operate on all matching items.

3. **Deep copying is automatic**: All items added or replaced are automatically deep copied, so you don't need to worry
   about reference sharing issues.

4. **Nil-safe operations**: All functions handle nil lists gracefully, either returning appropriate default values or
   empty tables.

5. **Error handling**: The module provides clear error messages for invalid parameters, helping with debugging during development.

## Error Handling

The module provides comprehensive error checking:

- Missing `compare` parameter when required
- Invalid `compare` parameter type (must be string or function)
- All errors include descriptive messages to help with debugging

## Performance Considerations

- **Single vs. All operations**: When you need to remove or replace multiple items, use the `{all = true}` option
  instead of calling the function multiple times.
- **Backwards iteration**: Remove operations use backwards iteration when `all = true` to avoid index shifting issues.
- **Deep copying overhead**: Be aware that all add/replace operations create deep copies of items, which has a
  performance cost for large or complex objects.
