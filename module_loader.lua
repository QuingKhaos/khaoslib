-- Shared module loading utilities for khaoslib
-- Provides consistent module loading logic across all khaoslib modules

local module_loader = {}

--- Determines if we're in a testing environment
--- @return boolean is_testing True if in testing environment, false if in Factorio
function module_loader.is_testing_environment()
  return type(data) == "nil" or _G.util ~= nil
end

--- Loads a khaoslib dependency module with proper environment detection
--- @param module_name string The module name (e.g., "list", "technology")
--- @return table The loaded module
function module_loader.load_khaoslib_module(module_name)
  if module_loader.is_testing_environment() then
    -- In testing environment, first try current directory, then parent directory
    local paths = {module_name .. ".lua", "../" .. module_name .. ".lua"}
    for _, module_path in ipairs(paths) do
      local chunk, err = loadfile(module_path)
      if chunk then
        return chunk(module_name)
      end
    end
    error("Failed to load khaoslib module " .. module_name .. ": module not found in current or parent directory")
  else
    return require("__khaoslib__." .. module_name)
  end
end

--- Loads the util module with proper environment detection
--- @return table The util module or mock
function module_loader.load_util()
  if module_loader.is_testing_environment() then
    return _G.util or {}
  else
    return require("util")
  end
end

--- Creates a mock technology module for testing environments
--- @return table Mock technology module
function module_loader.create_mock_technology()
  return {
    exists = function(name)
      return data and data.raw.technology[name] ~= nil
    end,
    load = function(self, name)
      return {
        add_unlock_recipe = function() return self end,
        remove_unlock_recipe = function() return self end,
        commit = function() return self end
      }
    end
  }
end

return module_loader
