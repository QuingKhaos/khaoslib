if ... ~= "__khaoslib__.sprites" then
  return require("__khaoslib__.sprites")
end

--- Utilities for sprites manipulation.
--- ```lua
--- local khaoslib_sprites = require("__khaoslib__.sprites")
--- ```
--- @class khaoslib_sprites
local khaoslib_sprites = {}

--- @alias khaoslib_sprites.Animation data.Animation|data.AnimationSheet|data.RotatedAnimation
--- @alias khaoslib_sprites.Animations data.Animation[]|data.AnimationSheet[]|data.RotatedAnimation[]
--- @alias khaoslib_sprites.AnimationStructures data.Animation4Way|data.AnimationVariations|data.RotatedAnimation8Way|data.RotatedAnimationVariations
--- @alias khaoslib_sprites.AnimationAll khaoslib_sprites.Animation|khaoslib_sprites.Animations|khaoslib_sprites.AnimationStructures
---
--- @alias khaoslib_sprites.Sprite data.RotatedSprite|data.Sprite|data.SpriteNWaySheet|data.SpriteSheet
--- @alias khaoslib_sprites.Sprites data.RotatedSprite[]|data.Sprite[]|data.SpriteNWaySheet[]|data.SpriteSheet[]
--- @alias khaoslib_sprites.SpriteStructures data.Sprite4Way|data.Sprite16Way|data.SpriteVariations
--- @alias khaoslib_sprites.SpriteAll khaoslib_sprites.Sprite|khaoslib_sprites.Sprites|khaoslib_sprites.SpriteStructures

--- Tints animations and sprites with possible layers.
--- @generic T : khaoslib_sprites.AnimationAll|khaoslib_sprites.SpriteAll
--- @param sprites T
--- @param tint data.Color
--- @return T
function khaoslib_sprites.tint(sprites, tint)
  if type(sprites) ~= "table" then error("Expected table, got " .. type(sprites), 2) end
  if type(tint) ~= "table" then error("Expected table, got " .. type(tint), 2) end

  -- local variable purely for intellisense support, because it doesn't infere the types correctly from the generic
  local _sprites = sprites
  ---@cast _sprites khaoslib_sprites.AnimationAll|khaoslib_sprites.SpriteAll

  -- make a shallow copy of the table to not modify the original one
  local copy = {}
  ---@cast copy khaoslib_sprites.AnimationAll|khaoslib_sprites.SpriteAll

  if _sprites.sheets then
    copy.sheets = khaoslib_sprites.tint(_sprites.sheets, tint)
  elseif _sprites.sheet then
    copy.sheet = khaoslib_sprites.tint(_sprites.sheet, tint)
  elseif _sprites.north then
    local directions = {
      "north", "north_north_east", "north_east", "east_north_east",
      "east", "east_south_east", "south_east", "south_south_east",
      "south", "south_south_west", "south_west", "west_south_west",
      "west", "west_north_west", "north_west", "north_north_west"
    }

    for _, direction in ipairs(directions) do
      if _sprites[direction] then copy[direction] = khaoslib_sprites.tint(_sprites[direction], tint) end
    end
  elseif _sprites.layers then
    copy.layers = khaoslib_sprites.tint(_sprites.layers, tint)
  elseif _sprites.filename then
    copy.tint = table.deepcopy(tint)
  else
    for _, sprite in pairs(_sprites) do
      table.insert(copy, khaoslib_sprites.tint(sprite, tint))
    end
  end

  return copy
end

return khaoslib_sprites
