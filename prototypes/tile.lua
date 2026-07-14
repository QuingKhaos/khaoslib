local khaoslib_list = require("common.list")

--#region Basic manipulation methods
-- A set of basic methods for creating and working with tile manipulation objects.

--- Tile manipulation utilities for Factorio data stage.
---
--- This module provides a fluent API for creating, modifying, and managing tile prototypes
--- during the data stage. It supports method chaining and uses the list utility module for
--- consistent prerequisite and effect manipulation.
--- @class khaoslib.TileManipulator
--- @field private tile data.TilePrototype The tile currently being manipulated.
--- @operator add(khaoslib.TileManipulator): khaoslib.TileManipulator
local khaoslib_tile = {}

--- Loads a given tile for manipulation or creates a new one if a table is passed.
--- @param tile data.TileID|data.TilePrototype The name of an existing tile or a new tile prototype table.
--- @return khaoslib.TileManipulator manipulator A tile manipulation object for the given tile.
--- @throws If the tile name doesn't exist or if a table is passed with a name that already exists or without a valid name field.
function khaoslib_tile:load(tile)
  local tile_type = type(tile)
  if tile_type ~= "string" and tile_type ~= "table" then error("tile parameter: Expected string or table , got " .. tile_type, 2) end

  if tile_type == "string" then
    if not khaoslib_tile.exists(tile) then error("No such tile: " .. tile, 2) end
  else -- tile_type == "table"
    if tile.type and type(tile.type) ~= "string" then error("tile table type field should be a string if set", 2) end
    if tile.type and tile.type ~= "tile" then error("tile table type field should be 'tile' if set", 2) end
    if not tile.name or type(tile.name) ~= "string" then error("tile table must have a name field of type string", 2) end
    if khaoslib_tile.exists(tile.name) then error("A tile with the name " .. tile.name .. " already exists", 2) end
  end

  local _tile = tile --luacheck: ignore 311
  if tile_type == "string" then
    _tile = util.table.deepcopy(data.raw["tile"][tile])
  else
    _tile = util.table.deepcopy(tile)
    _tile.type = "tile"
  end

  --- @diagnostic disable-next-line: missing-fields
  --- @cast _tile data.TilePrototype
  --- @type khaoslib.TileManipulator
  local obj = {tile = _tile}
  setmetatable(obj, self)
  self.__index = self

  return obj
end


--- Internal helper function to resolve the tile from a string, tile prototype data or a tile manipulation object.
--- @param tile data.TileID|data.TilePrototype|khaoslib.TileManipulator The tile to resolve.
--- @return data.TilePrototype resolved_tile The resolved tile prototype.
--- @throws If the tile cannot be resolved.
local resolve = function(tile)
  if type(tile) == "string" then
    local result = data.raw["tile"][tile]
    if not result then
      error("No such tile: " .. tile, 3)
    end

    return result
  elseif type(tile) == "table" then
    --- @diagnostic disable: access-invisible
    if getmetatable(tile) == khaoslib_tile and tile.tile then
      return tile.tile
    elseif tile.type == "tile" and tile.name then
      return tile --[[@as data.TilePrototype]]
    else
      error("Invalid tile table: expected manipulator or prototype with type='tile' and name", 3)
    end
    --- @diagnostic enable: access-invisible
  else
    error("Invalid tile parameter: expected tile name, prototype table, or tile manipulator", 3)
  end
end


--- Gets the raw data table of the tile.
--- @param tile data.TileID|data.TilePrototype|khaoslib.TileManipulator The tile.
--- @return data.TilePrototype tile A deep copy of the tile data.
--- @nodiscard
function khaoslib_tile.get(tile)
  return util.table.deepcopy(resolve(tile)) --[[@as data.TilePrototype]]
end

--- @class khaoslib_tile.TilePrototype : data.TilePrototype
--- @field type? string
--- @field name? string
--- @field collision_mask? data.CollisionMaskConnector
--- @field layer? uint8
--- @field variants? data.TileTransitionsVariants
--- @field map_color? data.Color

--- Merges the given fields into the tile.
--- @param fields khaoslib_tile.TilePrototype A table of fields to merge into the tile. See `data.TilePrototype` for valid fields.
--- @return khaoslib.TileManipulator self The same tile manipulation object for method chaining.
--- @throws If fields is not a table or if it contains a name field.
function khaoslib_tile:set(fields)
  if type(fields) ~= "table" then error("fields parameter: Expected table, got " .. type(fields), 2) end
  if fields.type then error("Cannot change the type of a tile.", 2) end
  if fields.name then error("Cannot change the name of a tile using set(). Use copy() to create a new tile with a different name.", 2) end

  self.tile = util.merge({self.tile, util.table.deepcopy(fields)})

  return self
end

--- Unsets the given field in the tile currently being manipulated.
--- @param field string The field to unset in the tile. See `data.TilePrototype` for valid fields.
--- @return khaoslib.TileManipulator self The same tile manipulation object for method chaining.
--- @throws If field is not a string, or if it is the type or name field.
function khaoslib_tile:unset(field)
  if type(field) ~= "string" then error("field parameter: Expected string, got " .. type(field), 2) end
  if field == "type" then error("Cannot unset the type of a tile.", 2) end
  if field == "name" then error("Cannot unset the name of a tile.", 2) end

  self.tile[field] = nil

  return self
end

--- Creates a deep copy of the tile.
--- @param tile data.TileID|data.TilePrototype|khaoslib.TileManipulator The tile.
--- @param new_name data.TileID The name of the new tile. Must not already exist.
--- @return khaoslib.TileManipulator tile A new tile manipulation object with a deep copy of the tile.
--- @throws If a tile with the new name already exists.
--- @nodiscard
function khaoslib_tile.copy(tile, new_name)
  local copy = util.table.deepcopy(resolve(tile))
  copy.name = new_name

  return khaoslib_tile:load(copy)
end

--- Commits the changes to the data stage.
--- If the tile already exists, it is overwritten.
--- @return khaoslib.TileManipulator self The same tile manipulation object for method chaining.
function khaoslib_tile:commit()
  self:remove()
  data:extend({self:get()})

  return self
end

--- Deletes the tile from the data stage instantly. Use with caution, as this works without a commit.
--- @param tile data.TileID|data.TilePrototype The tile.
--- @overload fun(self: khaoslib.TileManipulator): khaoslib.TileManipulator
function khaoslib_tile.remove(tile)
  data.raw["tile"][resolve(tile).name] = nil

  if type(tile) == "table" and getmetatable(tile) == khaoslib_tile then
    return tile --[[@as khaoslib.TileManipulator]]
  end
end

--- Merges another tile manipulation object into this one, excluding the name field.
--- @param other khaoslib.TileManipulator The other tile manipulation object to merge into this one
--- @return khaoslib.TileManipulator self The same tile manipulation object for method chaining.
--- @throws If other is not a tile manipulation object.
function khaoslib_tile:__add(other)
  if type(other) ~= "table" or getmetatable(other) ~= khaoslib_tile then
    error("Can only concatenate with another khaoslib.TileManipulator object", 2)
  end

  local other_copy = other:get()
  other_copy.type = nil
  other_copy.name = nil

  return self:set(other_copy --[[@as khaoslib_tile.TilePrototype]])
end

--- Compares two tile manipulation objects for equality based on the tile name.
--- @param other khaoslib.TileManipulator The other tile manipulation object to compare with.
--- @return boolean is_equal True if the two tile manipulation objects represent the same tile, false otherwise.
function khaoslib_tile:__eq(other)
  if type(other) ~= "table" or getmetatable(other) ~= khaoslib_tile then return false end

  return self.tile.name == other.tile.name
end

--- Returns a string representation of the tile manipulation object.
--- @return string representation A string representation of the tile manipulation object.
function khaoslib_tile:__tostring()
  return "[khaoslib_tile: " .. self.tile.name .. "]"
end

--#endregion

--#region Tile manipulation methods
-- A set of utility functions for manipulating tiles.

--- If the tile has a single icon, it is converted to the icons list format. If the tile already has an icons list, no changes are made.
--- @param tile data.TilePrototype The tile reference to populate icons for.
local populate_icons = function(tile)
  if tile.icon and (not tile.icons or #tile.icons == 0) then
    tile.icons = {{icon = tile.icon, icon_size = tile.icon_size or nil}}
    tile.icon = nil
    tile.icon_size = nil
  end
end

--- If just a single tile exists in the icons list, and it has no special properties, depopulate the icons list and set the icon and icon_size fields instead.
--- @param tile data.TilePrototype The tile reference to depopulate icons from.
local depopulate_icons = function(tile)
  if tile.icons and #tile.icons == 1 then
    local icon = tile.icons[1]
    if icon.tint == nil and icon.shift == nil and icon.scale == nil and icon.draw_background == nil and icon.floating == nil then
      tile.icon = icon.icon
      tile.icon_size = icon.icon_size or nil
      tile.icons = nil
    end
  end
end

--- Returns a deepcopy of all icons for the given tile. If the tile has a single icon, it is returned as a single-element list.
--- @param tile data.TileID|data.TilePrototype|khaoslib.TileManipulator The tile.
--- @return data.IconData[] icons A list of icons for the tile.
--- @nodiscard
function khaoslib_tile.get_icons(tile)
  local resolved_tile = resolve(tile)
  if resolved_tile.icons then
    return util.table.deepcopy(resolved_tile.icons --[[@as data.IconData[] ]])
  elseif resolved_tile.icon then
    return util.table.deepcopy({{icon = resolved_tile.icon, icon_size = resolved_tile.icon_size or nil}})
  else
    return {}
  end
end

--- Returns a deep-copied list of all icons for the given tile that match the given criteria.
--- @param tile data.TileID|data.TilePrototype|khaoslib.TileManipulator The tile.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @return data.IconData[] icons A list of matching icons.
--- @throws If compare is not a string or function.
--- @nodiscard
function khaoslib_tile.find_icons(tile, compare)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  local resolved_tile = resolve(tile)
  populate_icons(resolved_tile)

  local result = khaoslib_list.find(resolved_tile.icons, compare_fn)
  depopulate_icons(resolved_tile)

  return result
end

--- Sets the list of icons for the tile currently being manipulated, replacing any existing icons.
--- @param icons data.IconData[] A list of icons to set.
--- @return khaoslib.TileManipulator self The same tile manipulation object for method chaining.
--- @throws If icons is not a table.
function khaoslib_tile:set_icons(icons)
  if type(icons) ~= "table" then error("icons parameter: Expected table, got " .. type(icons), 2) end

  self.tile.icon = nil
  self.tile.icon_size = nil
  self.tile.icons = util.table.deepcopy(icons)
  depopulate_icons(self.tile)

  return self
end

--- Returns the number of icons for the given tile.
--- @param tile data.TileID|data.TilePrototype|khaoslib.TileManipulator The tile.
--- @return integer count The number of icons.
--- @nodiscard
function khaoslib_tile.count_icons(tile)
  local resolved_tile = resolve(tile)
  return resolved_tile.icon ~= nil and 1 or #(resolved_tile.icons or {})
end

--- Checks if the tile has an icon matching the given criteria.
--- Supports both string matching (by icon filename) and custom comparison functions.
--- @param tile data.TileID|data.TilePrototype|khaoslib.TileManipulator The tile.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @return boolean has_icon True if the tile has the icon, false otherwise.
--- @throws If compare is not a string or function.
--- @nodiscard
function khaoslib_tile.has_icon(tile, compare)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  local resolved_tile = resolve(tile)
  populate_icons(resolved_tile)

  local result = khaoslib_list.has(resolved_tile.icons, compare_fn)
  depopulate_icons(resolved_tile)

  return result
end

--- Gets the first icon (deep-copy) that matches the given criteria.
--- Supports both string matching (by icon filename) and custom comparison functions.
--- @param tile data.TileID|data.TilePrototype|khaoslib.TileManipulator The tile.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @return data.IconData? icon The first matching icon, or nil if no match is found.
--- @throws If compare is not a string or function.
--- @nodiscard
function khaoslib_tile.get_icon(tile, compare)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  local resolved_tile = resolve(tile)
  populate_icons(resolved_tile)

  local result = khaoslib_list.get(resolved_tile.icons, compare_fn)
  depopulate_icons(resolved_tile)

  return result
end

--- Adds an icon to the tile, allows duplicates.
--- @param icon data.IconData The icon data to add.
--- @param options ListAddIndexOptions? Options table with fields:
---   - `index` (integer, optional): If provided, inserts the icon at the specified index instead of appending to the end of the list.
--- @return khaoslib.TileManipulator self The same tile manipulation object for method chaining.
--- @throws If icon is not a table or doesn't have required fields.
function khaoslib_tile:add_icon(icon, options)
  if type(icon) ~= "table" then error("icon parameter: Expected table, got " .. type(icon), 2) end
  if not icon.icon or type(icon.icon) ~= "string" then error("icon parameter: Must have an icon field of type string", 2) end

  options = options or {}
  --- @cast options ListAddOptions
  options.allow_duplicates = true

  populate_icons(self.tile)
  self.tile.icons = khaoslib_list.add(self.tile.icons, icon, nil, options)
  depopulate_icons(self.tile)

  return self
end

--- Removes matching icons from the tile.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @param options ListRemoveOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, removes all matching icons instead of just the first.
--- @return khaoslib.TileManipulator self The same tile manipulation object for method chaining.
--- @throws If compare is not a string or function.
function khaoslib_tile:remove_icon(compare, options)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  populate_icons(self.tile)
  self.tile.icons = khaoslib_list.remove(self.tile.icons, compare_fn, options)
  depopulate_icons(self.tile)

  return self
end

--- Replaces matching icons with a new icon.
--- If no matching icons are found, no changes are made.
--- @param compare (fun(icon: data.IconData): boolean)|string A comparison function or icon filename to match.
--- @param replacement (fun(icon: data.IconData): data.IconData)|data.IconData The new icon data to replace with.
--- @param options ListReplaceOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, replaces all matching icons instead of just the first.
--- @return khaoslib.TileManipulator self The same tile manipulation object for method chaining.
--- @throws If compare is not a string or function, or replacement is not a table or function.
function khaoslib_tile:replace_icon(compare, replacement, options)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  if type(replacement) ~= "table" and type(replacement) ~= "function" then error("replacement parameter: Expected table or function, got " .. type(replacement), 2) end
  if type(replacement) == "table" then
    if not replacement.icon or type(replacement.icon) ~= "string" then error("replacement parameter: Must have an icon field of type string", 2) end
  end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.icon == compare end
  end

  populate_icons(self.tile)
  self.tile.icons = khaoslib_list.replace(self.tile.icons, replacement, compare_fn, options)
  depopulate_icons(self.tile)

  return self
end

--- Removes all icons from the tile.
--- @return khaoslib.TileManipulator self The same tile manipulation object for method chaining.
function khaoslib_tile:clear_icons()
  self.tile.icon = nil
  self.tile.icon_size = nil
  self.tile.icons = nil

  return self
end

--- Checks if the tile has minable properties.
--- @param tile data.TileID|data.TilePrototype|khaoslib.TileManipulator The tile.
--- @return boolean has_minable True if the tile has minable properties, false otherwise.
--- @nodiscard
function khaoslib_tile.has_minable(tile)
  local resolved = resolve(tile)
  return resolved.minable ~= nil
end

--- Returns a deep copy of the minable properties of the tile, or an empty table if none are set.
--- @param tile data.TileID|data.TilePrototype|khaoslib.TileManipulator The tile.
--- @return data.MinableProperties minable The minable properties of the tile, or an empty table if none are set.
--- @overload fun(tile: data.TilePrototype|khaoslib.TileManipulator): data.MinableProperties
--- @nodiscard
function khaoslib_tile.get_minable(tile)
  return util.table.deepcopy(resolve(tile).minable or {} --[[@as data.MinableProperties]])
end

--- Sets the minable property of the tile, overwritting all properties.
--- @param minable data.MinableProperties The minable properties to set.
--- @return khaoslib.TileManipulator self The same tile manipulation object for method chaining.
--- @throws If minable is not a table, or if minable.result is not a string, or if minable.results is not a table.
function khaoslib_tile:set_minable(minable)
  if type(minable) ~= "table" then error("minable parameter: Expected table, got " .. type(minable), 2) end
  if minable.result and type(minable.result) ~= "string" then error("minable.result field: Expected string, got " .. type(minable.result), 2) end
  if minable.results and type(minable.results) ~= "table" then error("minable.results field: Expected table, got " .. type(minable.results), 2) end

  self.tile.minable = util.table.deepcopy(minable)

  return self
end

--- Returns a deep copy of the minable results of the tile, or an empty table if none are set.
--- @param tile data.TileID|data.TilePrototype|khaoslib.TileManipulator The tile.
--- @return data.ProductPrototype[] minable_results A deep copy of the minable results table, or an empty table if none are set.
--- @overload fun(tile: data.TilePrototype|khaoslib.TileManipulator): data.ProductPrototype[]
--- @nodiscard
function khaoslib_tile.get_minable_results(tile)
  local minable = resolve(tile).minable
  if not minable then return {} end

  if minable.results then
    return util.table.deepcopy(minable.results --[[@as data.ProductPrototype[] ]])
  elseif minable.result then
    return {{type = "item", name = minable.result, amount = minable.count or 1}}
  else
    return {}
  end
end

--- Returns a deep-copied list of all minable results for the given tile that match the given criteria.
--- Supports both string matching (by product name) and custom comparison functions.
--- @param tile data.TileID|data.TilePrototype|khaoslib.TileManipulator The tile.
--- @param compare (fun(product: data.ProductPrototype): boolean)|string A comparison function or product name to match.
--- @return data.ProductPrototype[]? minable_results The matching minable results, or nil if no match is found.
--- @overload fun(tile: data.TilePrototype|khaoslib.TileManipulator, compare: (fun(product: data.ProductPrototype): boolean)|string): data.ProductPrototype?
--- @throws If compare is not a string or function.
--- @nodiscard
function khaoslib_tile.find_minable_results(tile, compare)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.name == compare end
  end

  local minable_results = khaoslib_tile.get_minable_results(tile)
  return khaoslib_list.find(minable_results, compare_fn)
end

--- Sets the minable results of the tile, overwriting any existing results.
--- @param results data.ProductPrototype[] A list of minable results to set.
--- @return khaoslib.TileManipulator self The same tile manipulation object for method chaining.
--- @throws If results is not a table.
function khaoslib_tile:set_minable_results(results)
  if type(results) ~= "table" then error("results parameter: Expected table, got " .. type(results), 2) end

  local minable = self.tile.minable or {} --[[@as data.MinableProperties]]
  minable.results = util.table.deepcopy(results)
  minable.result = nil
  minable.count = nil
  self.tile.minable = minable

  return self
end

--- Counts the number of minable results for the given tile.
--- @param tile data.TileID|data.TilePrototype|khaoslib.TileManipulator The tile.
--- @return integer count The number of minable results.
--- @overload fun(tile: data.TilePrototype|khaoslib.TileManipulator): integer
--- @nodiscard
function khaoslib_tile.count_mineable_results(tile)
  local minable_results = khaoslib_tile.get_minable_results(tile)
  return #minable_results
end

--- Checks if the tile has a minable result matching the given criteria.
--- Supports both string matching (by product name) and custom comparison functions.
--- @param tile data.TileID|data.TilePrototype|khaoslib.TileManipulator The tile.
--- @param compare (fun(product: data.ProductPrototype): boolean)|string A comparison function or product name to match.
--- @return boolean has_minable_result True if the tile has a matching minable result, false otherwise.
--- @overload fun(tile: data.TilePrototype|khaoslib.TileManipulator, compare: (fun(product: data.ProductPrototype): boolean)|string): boolean
--- @throws If compare is not a string or function.
--- @nodiscard
function khaoslib_tile.has_minable_result(tile, compare)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.name == compare end
  end

  local minable_results = khaoslib_tile.get_minable_results(tile)
  return khaoslib_list.has(minable_results, compare_fn)
end

--- Gets the first minable result (deep-copy) that matches the given criteria.
--- Supports both string matching (by product name) and custom comparison functions.
--- @param tile data.TileID|data.TilePrototype|khaoslib.TileManipulator The tile.
--- @param compare (fun(product: data.ProductPrototype): boolean)|string A comparison function or product name to match.
--- @return data.ProductPrototype? minable_result The first matching minable result, or nil if no match is found.
--- @overload fun(tile: data.TilePrototype|khaoslib.TileManipulator, compare: (fun(product: data.ProductPrototype): boolean)|string): data.ProductPrototype?
--- @throws If compare is not a string or function.
--- @nodiscard
function khaoslib_tile.get_minable_result(tile, compare)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.name == compare end
  end

  local minable_results = khaoslib_tile.get_minable_results(tile)
  return khaoslib_list.get(minable_results, compare_fn)
end

--- Adds a minable result to the tile, allowing duplicates.
--- @param result data.ProductPrototype The minable result to add.
--- @param options ListAddOptions? Options table with fields:
---   - `index` (integer, optional): If provided, inserts the result at the specified index instead of appending to the end of the list.
--- @return khaoslib.TileManipulator self The same tile manipulation object for method chaining.
--- @throws If result is not a table or doesn't have required fields.
function khaoslib_tile:add_minable_result(result, options)
  if type(result) ~= "table" then error("result parameter: Expected table, got " .. type(result), 2) end
  if not result.name or type(result.name) ~= "string" then error("result parameter: Must have a name field of type string", 2) end

  options = options or {}
  --- @cast options ListAddOptions
  options.allow_duplicates = true

  local minable = self.tile.minable or {} --[[@as data.MinableProperties]]
  minable.results = khaoslib_list.add(self:get_minable_results(), result, nil, options)
  minable.result = nil
  minable.count = nil
  self.tile.minable = minable

  return self
end

--- Removes matching minable results from the tile.
--- @param compare (fun(product: data.ProductPrototype): boolean)|string A comparison function or product name to match.
--- @param options ListRemoveOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, removes all matching results instead of just the first.
--- @return khaoslib.TileManipulator self The same tile manipulation object for method chaining.
--- @throws If compare is not a string or function.
function khaoslib_tile:remove_minable_result(compare, options)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.name == compare end
  end

  local minable = self.tile.minable or {} --[[@as data.MinableProperties]]
  minable.results = khaoslib_list.remove(self:get_minable_results(), compare_fn, options)
  minable.result = nil
  minable.count = nil
  self.tile.minable = minable

  return self
end

--- Replaces matching minable results with a new result.
--- If no matching results are found, no changes are made.
--- @param compare (fun(product: data.ProductPrototype): boolean)|string A comparison function or product name to match.
--- @param replacement (fun(product: data.ProductPrototype): data.ProductPrototype)|data.ProductPrototype The new minable result to replace with.
--- @param options ListReplaceOptions? Options table with fields:
---   - `all` (boolean, default: false): if true, replaces all matching results instead of just the first.
--- @return khaoslib.TileManipulator self The same tile manipulation object for method chaining.
--- @throws If compare is not a string or function, or replacement is not a table or function.
function khaoslib_tile:replace_minable_result(compare, replacement, options)
  if type(compare) ~= "string" and type(compare) ~= "function" then error("compare parameter: Expected string or function, got " .. type(compare), 2) end

  if type(replacement) ~= "table" and type(replacement) ~= "function" then error("replacement parameter: Expected table or function, got " .. type(replacement), 2) end
  if type(replacement) == "table" then
    if not replacement.name or type(replacement.name) ~= "string" then error("replacement parameter: Must have a name field of type string", 2) end
  end

  local compare_fn = compare
  if type(compare) == "string" then
    compare_fn = function(existing) return existing.name == compare end
  end

  local minable = self.tile.minable or {} --[[@as data.MinableProperties]]
  minable.results = khaoslib_list.replace(self:get_minable_results(), replacement, compare_fn, options)
  minable.result = nil
  minable.count = nil
  self.tile.minable = minable

  return self
end

--- Clears all minable results from the tile.
--- @return khaoslib.TileManipulator self The same tile manipulation object for method chaining.
function khaoslib_tile:clear_minable_results()
  local minable = self.tile.minable or {} --[[@as data.MinableProperties]]
  minable.results = nil
  minable.result = nil
  minable.count = nil
  self.tile.minable = minable

  return self
end

--#endregion

--#region Utility functions
-- Module-level utility functions for tile discovery and analysis.

--- Checks if a tile exists in the data stage.
--- @param name data.TileID The tile name to check.
--- @return boolean exists True if the tile exists, false otherwise.
--- @nodiscard
function khaoslib_tile.exists(name)
  if type(name) ~= "string" then error("name parameter: Expected string, got " .. type(name), 2) end

  return data.raw["tile"][name] ~= nil
end

--- Finds all tiles that match a custom compare function.
--- @param compare_fn fun(tile: data.TilePrototype): boolean A function that returns true for tiles to include.
--- @return data.TileID[] tiles A list of tile names that match the compare function.
--- @throws If compare_fn is not a function.
--- @nodiscard
function khaoslib_tile.find(compare_fn)
  if type(compare_fn) ~= "function" then error("compare_fn parameter: Expected function, got " .. type(compare_fn), 2) end

  local result = {}
  for _, tile in pairs(data.raw["tile"] or {}) do
    if compare_fn(tile) then
      table.insert(result, tile.name)
    end
  end

  return result
end

--#endregion

return khaoslib_tile
