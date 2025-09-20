-- Test utilities for khaoslib modules
-- Provides shared testing environment setup and module loading

local test_utils = {}

--- Sets up the testing environment with mock Factorio globals and utilities
function test_utils.setup_test_environment()
  -- Add parent directory to Lua path for module loading
  package.path = package.path .. ";../?.lua;./?.lua"

  -- Mock Factorio environment if not already set up
  if not data then
    data = {
      raw = {
        recipe = {},
        technology = {}
      },
      extend = function(prototypes)
        for _, prototype in ipairs(prototypes) do
          if prototype.type == "recipe" then
            data.raw.recipe[prototype.name] = prototype
          elseif prototype.type == "technology" then
            data.raw.technology[prototype.name] = prototype
          end
        end
      end
    }
  end

  -- Mock util module if not already set up
  if not _G.util then
    _G.util = {
      table = {
        deepcopy = function(original)
          if type(original) ~= "table" then
            return original
          end

          local copy = {}
          for key, value in pairs(original) do
            copy[key] = _G.util.table.deepcopy(value)
          end
          return copy
        end
      },
      merge = function(tables)
        local result = {}
        for _, t in ipairs(tables) do
          for k, v in pairs(t) do
            result[k] = v
          end
        end
        return result
      end
    }
  end
end

--- Loads a khaoslib module in the testing environment
--- @param module_name string The name of the module to load (e.g., "list", "recipe", "technology")
--- @return table The loaded module
function test_utils.load_module(module_name)
  test_utils.setup_test_environment()
  -- Try multiple possible paths to handle both running from tests/ and from workspace root
  local possible_paths = {
    "../" .. module_name .. ".lua",  -- When running from tests/ directory
    module_name .. ".lua"            -- When running from workspace root
  }

  for _, module_path in ipairs(possible_paths) do
    local chunk, err = loadfile(module_path)
    if chunk then
      return chunk(module_name)
    end
  end

  error("Failed to load module " .. module_name .. ": module not found in any expected location")
end

--- Creates test data for recipes
function test_utils.create_test_recipe(name, ingredients, results)
  ingredients = ingredients or {{type = "item", name = "iron-plate", amount = 1}}
  results = results or {{type = "item", name = name or "test-item", amount = 1}}

  return {
    type = "recipe",
    name = name or "test-recipe",
    ingredients = ingredients,
    results = results,
    energy_required = 1.0
  }
end

--- Creates test data for technologies
function test_utils.create_test_technology(name, prerequisites, effects)
  prerequisites = prerequisites or {}
  effects = effects or {}

  return {
    type = "technology",
    name = name or "test-tech",
    prerequisites = prerequisites,
    effects = effects,
    unit = {
      count = 100,
      ingredients = {{"automation-science-pack", 1}},
      time = 30
    }
  }
end

--- Adds test data to the mock data.raw
function test_utils.add_test_data(prototypes)
  for _, prototype in ipairs(prototypes) do
    data.extend({prototype})
  end
end

return test_utils
