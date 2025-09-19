[![Factorio Mod Portal page](https://img.shields.io/badge/dynamic/json?color=orange&label=Factorio&query=downloads_count&suffix=%20downloads&url=https%3A%2F%2Fmods.factorio.com%2Fapi%2Fmods%2Fkhaoslib&style=for-the-badge)](https://mods.factorio.com/mod/khaoslib) [![](https://img.shields.io/github/issues/QuingKhaos/khaoslib/bug?label=Bug%20Reports&style=for-the-badge)](https://github.com/QuingKhaos/khaoslib/issues?q=is%3Aissue%20state%3Aopen%20label%3Abug) [![](https://img.shields.io/github/issues-pr/QuingKhaos/khaoslib?label=Pull%20Requests&style=for-the-badge)](https://github.com/QuingKhaos/khaoslib/pulls) [![Ko-fi](https://img.shields.io/badge/Ko--fi-support%20me-hotpink?logo=kofi&logoColor=white&style=for-the-badge)](https://ko-fi.com/quingkhaos)

# QuingKhaos' Factorio Library

A set of commonly-used utilities by QuingKhaos for creating Factorio mods.

## Usage

Download the latest release from the [mod portal](https://mods.factorio.com/mod/khaoslib/downloads) or [GitHub releases](https://github.com/QuingKhaos/khaoslib/releases), unzip it and put it in your mods directory. You can access libraries provided by khaoslib with `require("__khaoslib__.module")`.

Add the khaoslib directory to your language server's library. I recommend installing the [Factorio modding toolkit](https://github.com/justarandomgeek/vscode-factoriomod-debug) and setting it up with the [Sumneko Lua language server](https://github.com/sumneko/lua-language-server) to get cross-mod autocomplete and type checking.

## Available Modules

### List Module

Reusable utilities for list manipulation with consistent behavior across Factorio mods. Supports both string-based and function-based comparison logic with automatic deep copying for data safety.

```lua
local khaoslib_list = require("__khaoslib__.list")

-- Add items with duplicate prevention
local my_list = {"iron-plate", "copper-plate"}
khaoslib_list.add(my_list, "steel-plate", "steel-plate")  -- Only adds if not present

-- Allow duplicates when needed
khaoslib_list.add(my_list, "byproduct", nil, {allow_duplicates = true})

-- Remove items with flexible matching
khaoslib_list.remove(my_list, "iron-plate")  -- Remove first match
khaoslib_list.remove(my_list, "byproduct", {all = true})  -- Remove all matches

-- Replace items with automatic deep copying
khaoslib_list.replace(my_list, "advanced-circuit", "iron-plate")  -- Replace first match
khaoslib_list.replace(my_list, "steel-plate", "iron-plate", {all = true})  -- Replace all matches

-- Function-based matching for complex objects
local recipes = {{name = "iron-plate"}, {name = "copper-plate"}}
khaoslib_list.replace(recipes, {name = "steel-plate", amount = 1}, function(r)
  return r.name == "iron-plate"
end)
```

**Key Features:**

- **Consistent API**: All functions follow the same parameter patterns
- **Flexible Matching**: String equality or custom comparison functions
- **Deep Copying**: Automatic deep copying prevents reference sharing issues
- **Nil-Safe**: All functions handle nil lists gracefully

**[📖 Full List Module Documentation](docs/list-module.md)**

### Recipe Module

Comprehensive API for manipulating Factorio recipe prototypes during the data stage with method chaining, deep copying, and robust error handling.

```lua
local khaoslib_recipe = require("__khaoslib__.recipe")

-- Modify existing recipe
khaoslib_recipe:load("iron-plate")
  :add_ingredient({type = "item", name = "coal", amount = 1})
  :set({energy_required = 2.0})
  :commit()

-- Create new recipe from scratch
khaoslib_recipe:load({
  name = "advanced-circuit-with-solder",
  category = "crafting",
  energy_required = 5,
  ingredients = {{type = "item", name = "electronic-circuit", amount = 5}},
  results = {{type = "item", name = "advanced-circuit", amount = 2}}
}):commit()

-- Complex ingredient/result manipulation
local recipe = khaoslib_recipe:load("steel-plate")
recipe:remove_ingredient("iron-plate")
  :add_ingredient({type = "item", name = "processed-iron-ore", amount = 1})
  :replace_result("steel-plate", {type = "item", name = "steel-plate", amount = 2})
  :commit()
```

**Key Features:**

- **Method Chaining**: Fluent API design for readable recipe modifications
- **Flexible Loading**: Load existing recipes or create new ones from prototypes
- **Ingredient Management**: Add, remove, replace with duplicate prevention (Factorio requirement)
- **Result Management**: Full support for multiple results with specialized handling
- **Deep Copying**: Ensures data stage safety and prevents reference issues
- **Comprehensive Validation**: Robust error handling with descriptive messages

**[📖 Full Recipe Module Documentation](docs/recipe-module.md)**

### Sprites Module

Utilities for working with Factorio sprites and graphics.

```lua
local khaoslib_sprites = require("__khaoslib__.sprites")
```

## Stability guarantee

khaoslib follows [Semantic Versioning](https://semver.org/). Thus any 0.x API should not be considered stable. I will do my best to avoid breaking changes in minor releases, but if a breaking change is necessary it will be documented in the changelog.

## Legal notice

khaoslib is licensed under the LGPLv3, unlike my other mods which are all licensed under the GPLv3. Mods that use khaoslib are not required to be open source, nor are they required to be licensed under the LGPLv3. However, if you modify khaoslib itself and distribute the modified version, you must also distribute the source code of your modified version under the LGPLv3.
