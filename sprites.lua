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
  local copy = table.deepcopy(sprites)
  ---@cast copy khaoslib_sprites.AnimationAll|khaoslib_sprites.SpriteAll

  if copy.sheets then
    copy.sheets = khaoslib_sprites.tint(copy.sheets, tint)
  elseif copy.sheet then
    copy.sheet = khaoslib_sprites.tint(copy.sheet, tint)
  elseif copy.north then
    local directions = {
      "north", "north_north_east", "north_east", "east_north_east",
      "east", "east_south_east", "south_east", "south_south_east",
      "south", "south_south_west", "south_west", "west_south_west",
      "west", "west_north_west", "north_west", "north_north_west"
    }

    for _, direction in ipairs(directions) do
      if copy[direction] then copy[direction] = khaoslib_sprites.tint(copy[direction], tint) end
    end
  elseif copy.layers then
    copy.layers = khaoslib_sprites.tint(copy.layers, tint)
  elseif copy.filename then
    copy.tint = table.deepcopy(tint)
  else
    local new = {}
    ---@cast new khaoslib_sprites.Animations|khaoslib_sprites.Sprites

    for _, sprite in pairs(copy) do
      table.insert(new, khaoslib_sprites.tint(sprite, tint))
    end
    copy = new
  end

  return copy
end

return khaoslib_sprites
