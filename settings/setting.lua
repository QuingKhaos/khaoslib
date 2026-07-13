local util = require("util")

-- #region Basic manipulation methods
-- Core methods for creating and working with setting manipulation objects.

--- @class khaoslib_setting.Setting
--- @field public type "bool-setting"|"int-setting"|"double-setting"|"string-setting"|"color-setting"
--- @field public name string
--- @field public localised_name? LocalisedString
--- @field public localised_description? LocalisedString
--- @field public order string?
--- @field public hidden boolean?
--- @field public setting_type "startup"|"runtime-global"|"runtime-per-user"

--- @class khaoslib_setting.BoolSetting : khaoslib_setting.Setting
--- @field public type "bool-setting"
--- @field public default_value boolean
--- @field public forced_value boolean?

--- @class khaoslib_setting.IntSetting : khaoslib_setting.Setting
--- @field public type "int-setting"
--- @field public default_value integer
--- @field public minimum_value integer?
--- @field public maximum_value integer?
--- @field public allowed_values integer[]?

--- @class khaoslib_setting.DoubleSetting : khaoslib_setting.Setting
--- @field public type "double-setting"
--- @field public default_value double
--- @field public minimum_value double?
--- @field public maximum_value double?
--- @field public allowed_values double[]?

--- @class khaoslib_setting.StringSetting : khaoslib_setting.Setting
--- @field public type "string-setting"
--- @field public default_value string
--- @field public allow_blank boolean?
--- @field public auto_trim boolean?
--- @field public allowed_values string[]?

--- @class khaoslib_setting.ColorSetting : khaoslib_setting.Setting
--- @field public type "color-setting"
--- @field public default_value Color
--- @field public forced_value Color?

--- @alias khaoslib_setting.Settings khaoslib_setting.BoolSetting|khaoslib_setting.IntSetting|khaoslib_setting.DoubleSetting|khaoslib_setting.StringSetting|khaoslib_setting.ColorSetting

--- @class khaoslib.SettingManipulator
--- @field private setting khaoslib_setting.Settings The setting currently being manipulated.
--- @operator add(khaoslib.SettingManipulator): khaoslib.SettingManipulator
local khaoslib_setting = {}

local setting_types = {"bool-setting", "int-setting", "double-setting", "string-setting", "color-setting"}

--- Loads a given setting for manipulation or creates a new one if a table is passed.
--- @param setting string|khaoslib_setting.Settings The name of an existing setting or a new setting table.
--- @return khaoslib.SettingManipulator manipulator A setting manipulation object for the given setting.
--- @throws If the setting name doesn't exist or if a table is passed with a name that already exists or without mandatory field.
function khaoslib_setting:load(setting)
  local setting_type = type(setting)
  if setting_type ~= "string" and setting_type ~= "table" then error("setting parameter: Expected string or table, got " .. type(setting), 2) end

  if setting_type == "string" then
    if not khaoslib_setting.exists(setting) then error("No such setting: " .. setting, 2) end
  else -- setting_type == table
    if not setting.type or type(setting.type) ~= "string" then error("setting table must have a type field of type string", 2) end
    if not setting.name or type(setting.name) ~= "string" then error("setting table must have a name field of type string", 2) end
    if not setting.setting_type or type(setting.setting_type) ~= "string" then error("setting table must have a setting_type field of type string", 2) end
    if data.raw[setting.type] and data.raw[setting.type][setting.name] then error("A setting with the name " .. setting.name .. " already exists", 2) end
  end

  local _setting = setting --luacheck: ignore 311
  if type(setting) == "string" then
    for _, _type in ipairs(setting_types) do
      if data.raw[_type] and data.raw[_type][setting] then
        _setting = util.table.deepcopy(data.raw[_type][setting])
        break
      end
    end
  else
    _setting = util.table.deepcopy(setting)
  end

  --- @cast _setting khaoslib_setting.Settings
  --- @type khaoslib.SettingManipulator
  local obj = {setting = _setting}
  setmetatable(obj, self)
  self.__index = self

  return obj
end

--- @diagnostic disable: invisible

--- Internal helper function to resole the setting from a string, setting prototype data or a setting manipulation object.
--- @param setting string|khaoslib_setting.Settings|khaoslib.SettingManipulator The setting to resolve.
--- @return khaoslib_setting.Settings resolved_setting The resolved setting prototype.
--- @throws If the setting cannot be resolved.
local function resolve(setting)
  if type(setting) == "string" then
    local result = nil
    for _, _type in ipairs(setting_types) do
      if data.raw[_type] and data.raw[_type][setting] then
        result = data.raw[_type][setting]
        break
      end
    end

    if not result then
      error("No such setting: " .. setting, 3)
    end

    return result
  elseif type(setting) == "table" then
    if getmetatable(setting) == khaoslib_setting and setting.setting then
      return setting.setting
    elseif setting.type and setting.name then
      return setting --[[@as khaoslib_setting.Settings]]
    else
      error("Invalid setting table: expected manipulator or prototype with type and name", 3)
    end
  else
    error("Invalid setting parameter: expected setting name, prototype table, or setting manipulator", 3)
  end
end

--- @diagnostic enable: invisible

--- Gets the raw prototype data of the given setting.
--- @param setting string|khaoslib_setting.Settings|khaoslib.SettingManipulator The setting.
--- @return khaoslib_setting.Settings setting A deep copy of the setting currently being manipulated.
--- @nodiscard
function khaoslib_setting.get(setting)
  return util.table.deepcopy(resolve(setting))
end

--- @class khaoslib_setting.SettingPrototype : khaoslib_setting.BoolSetting, khaoslib_setting.IntSetting, khaoslib_setting.DoubleSetting, khaoslib_setting.StringSetting, khaoslib_setting.ColorSetting
--- @field type? string
--- @field name? string
--- @field setting_type? string

--- Merges the given fields into the setting currently being manipulated.
--- @param fields khaoslib_setting.SettingPrototype A table of fields to merge into the setting.
--- @return khaoslib.SettingManipulator self The same setting manipulation object for method chaining.
--- @throws If fields is not a table or if it contains a name field.
function khaoslib_setting:set(fields)
  if type(fields) ~= "table" then error("fields parameter: Expected table, got " .. type(fields), 2) end
  if fields.type then error("Cannot change the type of a setting.", 2) end
  if fields.name then error("Cannot change the name of a setting using set(). Use copy() to create a new setting with a different name.", 2) end
  if fields.setting_type then error("Cannot change the setting_type of a setting.", 2) end

  self.setting = util.merge({self.setting, util.table.deepcopy(fields)})

  return self
end


--- Unsets the given field in the setting currently being manipulated.
--- @param field string The field to unset in the setting.
--- @return khaoslib.SettingManipulator self The same setting manipulation object for method chaining.
--- @throws If field is not a string, or if it is the type or name or setting_type field.
function khaoslib_setting:unset(field)
  if type(field) ~= "string" then error("field parameter: Expected string, got " .. type(field), 2) end
  if field == "type" then error("Cannot unset the type of a setting.", 2) end
  if field == "name" then error("Cannot unset the name of a setting.", 2) end
  if field == "setting_type" then error("Cannot unset the setting_type of a setting.", 2) end

  self.setting[field] = nil

  return self
end

--- Creates a deep copy of the given setting.
--- @param setting string|khaoslib_setting.Settings|khaoslib.SettingManipulator The setting.
--- @param new_name string The name of the new setting. Must not already exist.
--- @return khaoslib.SettingManipulator setting A new setting manipulation object with a deep copy of the setting.
--- @throws If a setting with the new name already exists.
--- @nodiscard
function khaoslib_setting.copy(setting, new_name)
  local copy = util.table.deepcopy(resolve(setting))
  copy.name = new_name

  return khaoslib_setting:load(copy)
end

--- Commits the changes made to the setting currently being manipulated back to the settings stage.
--- If the setting already exists, it is overwritten.
--- @return khaoslib.SettingManipulator self The same setting manipulation object for method chaining.
function khaoslib_setting:commit()
  -- Commit the setting
  self:remove()

  --- @diagnostic disable-next-line: assign-type-mismatch
  data:extend({self:get()})

  return self
end

--- Deletes the setting currently being manipulated from the settings stage instantly. Use with caution, as this works without a commit.
--- @return khaoslib.SettingManipulator self The same setting manipulation object for method chaining.
function khaoslib_setting:remove()
  data.raw[self.setting.type][self.setting.name] = nil

  return self
end

--- Merges another setting manipulation object into this one, except mandatory immutable fields.
--- @param other khaoslib.SettingManipulator The other setting manipulation object to merge into this one
--- @return khaoslib.SettingManipulator self The same setting manipulation object for method chaining.
--- @throws If other is not a setting manipulation object.
function khaoslib_setting:__add(other)
  if type(other) ~= "table" or getmetatable(other) ~= khaoslib_setting then error("Can only concatenate with another khaoslib.SettingManipulator object", 2) end
  if self.setting.type ~= other.setting.type then error("Cannot merge settings of different types: " .. self.setting.type .. " and " .. other.setting.type, 2) end
  if self.setting.setting_type ~= other.setting.setting_type then error("Cannot merge settings of different setting types: " .. self.setting.setting_type .. " and " .. other.setting.setting_type, 2) end

  --- @cast other khaoslib.SettingManipulator
  local other_copy = util.table.deepcopy(other.setting)
  other_copy.type = nil
  other_copy.name = nil
  other_copy.setting_type = nil

  return self:set(other_copy --[[@as khaoslib_setting.SettingPrototype]])
end

--- Compares two setting manipulation objects for equality based on the mandatory fields.
--- @param other khaoslib.SettingManipulator The other setting manipulation object to compare with.
--- @return boolean is_equal True if the two setting manipulation objects represent the same setting, false otherwise.
function khaoslib_setting:__eq(other)
  if type(other) ~= "table" or getmetatable(other) ~= khaoslib_setting then return false end

  return self.setting.type == other.setting.type and self.setting.name == other.setting.name and self.setting.setting_type == other.setting.setting_type
end

--- Returns a string representation of the setting manipulation object.
--- @return string representation A string representation of the setting manipulation object.
function khaoslib_setting:__tostring()
  return "[khaoslib_setting: " .. self.setting.type .. "/" .. self.setting.name .. "/" .. self.setting.setting_type .. "]"
end

-- #endregion

-- #region Setting manipulation methods
-- Specialized methods for manipulating settings.

--- Sets the default value of the setting currently being manipulated.
--- @param value boolean|integer|double|string|Color The default value to set for the setting. The type of the value must match the type of the setting.
--- @return khaoslib.SettingManipulator self The same setting manipulation object for method chaining.
--- @throws If the value type does not match the setting type.
function khaoslib_setting:default(value)
  if self.setting.type == "bool-setting" then
    if type(value) ~= "boolean" then error("Expected boolean for default value of bool-setting, got " .. type(value), 2) end
  elseif self.setting.type == "int-setting" then
    if type(value) ~= "number" or value % 1 ~= 0 then error("Expected integer for default value of int-setting, got " .. type(value), 2) end
  elseif self.setting.type == "double-setting" then
    if type(value) ~= "number" then error("Expected number for default value of double-setting, got " .. type(value), 2) end
  elseif self.setting.type == "string-setting" then
    if type(value) ~= "string" then error("Expected string for default value of string-setting, got " .. type(value), 2) end
  elseif self.setting.type == "color-setting" then
    if type(value) ~= "table" or not (value.r and value.g and value.b and value.a) then error("Expected Color table for default value of color-setting, got " .. type(value), 2) end
  else
    error("Unknown setting type: " .. tostring(self.setting.type), 2)
  end

  self.setting.default_value = value

  return self
end

--- Forces the value of the setting currently being manipulated.
--- @param value boolean|integer|double|string|Color The value to force for the setting. The type of the value must match the type of the setting.
--- @return khaoslib.SettingManipulator self The same setting manipulation object for method chaining.
--- @throws If the value type does not match the setting type.
function khaoslib_setting:force(value)
  if self.setting.type == "bool-setting" then
    if type(value) ~= "boolean" then error("Expected boolean for forced value of bool-setting, got " .. type(value), 2) end
  elseif self.setting.type == "int-setting" then
    if type(value) ~= "number" or value % 1 ~= 0 then error("Expected integer for forced value of int-setting, got " .. type(value), 2) end
  elseif self.setting.type == "double-setting" then
    if type(value) ~= "number" then error("Expected number for forced value of double-setting, got " .. type(value), 2) end
  elseif self.setting.type == "string-setting" then
    if type(value) ~= "string" then error("Expected string for forced value of string-setting, got " .. type(value), 2) end
  elseif self.setting.type == "color-setting" then
    if type(value) ~= "table" or not (value.r and value.g and value.b and value.a) then error("Expected Color table for forced value of color-setting, got " .. type(value), 2) end
  else
    error("Unknown setting type: " .. tostring(self.setting.type), 2)
  end

  self.setting.hidden = true

  --- @diagnostic disable: assign-type-mismatch
  if self.setting.type == "bool-setting" or self.setting.type == "color-setting" then
    self.setting.forced_value = value
  else
    self.setting.allowed_values = {value}
    self.setting.default_value = value
  end
  --- @diagnostic enable: assign-type-mismatch

  return self
end

--- Forces the setting currently being manipulated to its default value.
--- @return khaoslib.SettingManipulator self The same setting manipulation object for method chaining.
--- @throws If the setting does not have a default value.
function khaoslib_setting:force_default()
  if self.setting.default_value == nil then
    error("Cannot force default value: setting does not have a default value", 2)
  end

  self:force(self.setting.default_value)

  return self
end

-- #endregion

--#region Utility functions
-- Module-level utility functions for setting discovery and analysis.

--- Checks if a setting exists in the settings stage.
--- @param name string The setting name to check.
--- @return boolean exists True if the setting exists, false otherwise.
--- @nodiscard
function khaoslib_setting.exists(name)
  if type(name) ~= "string" then error("name parameter: Expected string, got " .. type(name), 2) end

  for _, _type in ipairs(setting_types) do
    if data.raw[_type] and data.raw[_type][name] then
      return true
    end
  end

  return false
end

--- Finds all settings that match a custom compare function.
--- @param compare_fn fun(setting: khaoslib_setting.Settings): boolean A function that returns true for settings to include.
--- @return string[] settings A list of setting names that match the compare function.
--- @throws If compare_fn is not a function.
--- @nodiscard
function khaoslib_setting.find(compare_fn)
  if type(compare_fn) ~= "function" then error("compare_fn parameter: Expected function, got " .. type(compare_fn), 2) end

  local result = {}
  for _, _type in ipairs(setting_types) do
    for _, setting in pairs(data.raw[_type]) do
      if compare_fn(setting) then
        table.insert(result, setting.name)
      end
    end
  end

  return result
end

--#endregion

return khaoslib_setting
