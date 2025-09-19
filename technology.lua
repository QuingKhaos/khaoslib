if ... ~= "__khaoslib__.technology" then
  return require("__khaoslib__.technology")
end

local util = require("util")

--#region Basic manipulation methods
-- A set of basic methods for creating and working with technology manipulation objects.

--- Utilities for technology manipulation in Factorio data stage.
--- ```lua
--- local khaoslib_technology = require("__khaoslib__.technology")
---
--- -- Load an existing technology for manipulation and replace icon
--- khaoslib_technology:load("electronics"):set({icon = "__mymod__/graphics/technology/electronics.png"}):commit()
---
--- -- Create a new technology from scratch
--- khaoslib_technology:load {
---   name = "advanced-electronics",
---   icon = "__mymod__/graphics/technology/advanced-electronics.png",
---   -- other fields here
--- }:commit()
--- ```
--- @class khaoslib.TechnologyManipulator
--- @field private technology data.TechnologyPrototype The technology currently being manipulated.
--- @operator add(khaoslib.TechnologyManipulator): khaoslib.TechnologyManipulator
local khaoslib_technology = {}

--- Loads a given technology for manipulation or creates a new one if a table is passed.
--- @param technology data.TechnologyID|data.TechnologyPrototype The name of an existing technology or a new technology prototype table.
--- @return khaoslib.TechnologyManipulator manipulator A technology manipulation object for the given technology.
--- @throws If the technology name doesn't exist or if a table is passed with a name that already exists or without a valid name field.
function khaoslib_technology:load(technology)
  if type(technology) ~= "string" and type(technology) ~= "table" then error("technology parameter: Expected string or table , got " .. type(technology), 2) end
  if type(technology) == "string" and not data.raw.technology[technology] then error("No such technology: " .. technology, 2) end
  if type(technology) == "table" and technology.type and type(technology.type) ~= "string" then error("technology table type field should be a string if set", 2) end
  if type(technology) == "table" and technology.type and technology.type ~= "technology" then error("technology table type field should be 'technology' if set", 2) end
  if type(technology) == "table" and (not technology.name or type(technology.name) ~= "string") then error("technology table must have a name field of type string", 2) end
  if type(technology) == "table" and data.raw.technology[technology.name] then error("A technology with the name " .. technology.name .. " already exists", 2) end

  local _technology = technology
  if type(technology) == "string" then
    _technology = util.table.deepcopy(data.raw.technology[technology])
  else
    _technology = util.table.deepcopy(technology)
    _technology.type = "technology"
  end

  --- @cast _technology data.TechnologyPrototype
  --- @type khaoslib.TechnologyManipulator
  local obj = {technology = _technology}
  setmetatable(obj, self)
  self.__index = self

  return obj
end

--- Gets the raw data table of the technology currently being manipulated.
--- @return data.TechnologyPrototype technology A deep copy of the technology currently being manipulated.
--- @nodiscard
function khaoslib_technology:get()
  return util.table.deepcopy(self.technology) --[[@as data.TechnologyPrototype]]
end

--- Merges the given fields into the technology currently being manipulated.
--- @param fields table A table of fields to merge into the technology. See `data.TechnologyPrototype` for valid fields.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If fields is not a table or if it contains a name field.
function khaoslib_technology:set(fields)
  if type(fields) ~= "table" then error("fields parameter: Expected table, got " .. type(fields), 2) end
  if fields.type then error("Cannot change the type of a technology.", 2) end
  if fields.name then error("Cannot change the name of a technology using set(). Use copy() to create a new technology with a different name.", 2) end

  self.technology = util.merge({self.technology, fields})

  return self
end

--- Creates a deep copy of the technology currently being manipulated.
--- @param new_name data.TechnologyID The name of the new technology. Must not already exist.
--- @return khaoslib.TechnologyManipulator technology A new technology manipulation object with a deep copy of the technology.
--- @throws If a technology with the new name already exists.
--- @nodiscard
function khaoslib_technology:copy(new_name)
  local copy = self:get()
  copy.name = new_name

  return khaoslib_technology:load(copy)
end

--- Commits the changes made to the technology currently being manipulated back to the data stage.
--- If the technology already exists, it is overwritten.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
function khaoslib_technology:commit()
  data:extend({self:remove():get()})

  return self
end

--- Deletes the technology currently being manipulated from the data stage.
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
function khaoslib_technology:remove()
  data.raw.technology[self.technology.name] = nil

  return self
end

--- Merges another technology manipulation object into this one, excluding the name field.
--- @param other khaoslib.TechnologyManipulator The other technology manipulation object to merge into this one
--- @return khaoslib.TechnologyManipulator self The same technology manipulation object for method chaining.
--- @throws If other is not a technology manipulation object.
function khaoslib_technology:__add(other)
  if type(other) ~= "table" or getmetatable(other) ~= khaoslib_technology then error("Can only concatenate with another khaoslib.TechnologyManipulator object", 2) end

  local other_copy = other:get()
  other_copy.type = nil
  other_copy.name = nil

  return self:set(other_copy)
end

--- Compares two technology manipulation objects for equality based on the technology name.
--- @param other khaoslib.TechnologyManipulator The other technology manipulation object to compare with.
--- @return boolean is_equal True if the two technology manipulation objects represent the same technology, false otherwise.
function khaoslib_technology:__eq(other)
  if type(other) ~= "table" or getmetatable(other) ~= khaoslib_technology then return false end

  return self.technology.name == other.technology.name
end

--- Returns a string representation of the technology manipulation object.
--- @return string representation A string representation of the technology manipulation object.
function khaoslib_technology:__tostring()
  return "[khaoslib_technology: " .. self.technology.name .. "]"
end

--#endregion

return khaoslib_technology
