if ... ~= "__khaoslib__.sprites" then
  return require("__khaoslib__.sprites")
end

local util = require("util")

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

--- @alias khaoslib_sprites.Sprite data.RotatedSprite|data.Sprite|data.SpriteNWaySheet|data.SpriteSheet
--- @alias khaoslib_sprites.Sprites data.RotatedSprite[]|data.Sprite[]|data.SpriteNWaySheet[]|data.SpriteSheet[]
--- @alias khaoslib_sprites.SpriteStructures data.Sprite4Way|data.Sprite16Way|data.SpriteVariations
--- @alias khaoslib_sprites.SpriteAll khaoslib_sprites.Sprite|khaoslib_sprites.Sprites|khaoslib_sprites.SpriteStructures

--- Traverses a sprite or animation or a table of them and applies the given function to each sprite/animation found.
--- @generic T : khaoslib_sprites.AnimationAll|khaoslib_sprites.SpriteAll
--- @param sprites T The sprite or animation or a table of them.
--- @param fn fun(sprite: khaoslib_sprites.Animation|khaoslib_sprites.Sprite): nil A function that takes a sprite or animation copy and applies modifications to it.
--- @return T copy A copy of the given animation or sprite or a table of them with the modifications applied.
--- @nodiscard
function khaoslib_sprites.traverse(sprites, fn)
  if type(sprites) ~= "table" then error("sprites parameter: Expected table, got " .. type(sprites), 3) end
  --- @cast sprites khaoslib_sprites.AnimationAll|khaoslib_sprites.SpriteAll

  --- @type khaoslib_sprites.AnimationAll|khaoslib_sprites.SpriteAll
  local copy = {}

  if sprites.sheets then
    copy.sheets = khaoslib_sprites.traverse(sprites.sheets, fn)
  elseif sprites.sheet then
    copy.sheet = khaoslib_sprites.traverse(sprites.sheet, fn)
  elseif sprites.north then
    local directions = {
      "north", "north_north_east", "north_east", "east_north_east",
      "east", "east_south_east", "south_east", "south_south_east",
      "south", "south_south_west", "south_west", "west_south_west",
      "west", "west_north_west", "north_west", "north_north_west"
    }

    for _, direction in ipairs(directions) do
      if sprites[direction] then copy[direction] = khaoslib_sprites.traverse(sprites[direction], fn) end
    end
  elseif sprites.layers then
    copy.layers = khaoslib_sprites.traverse(sprites.layers, fn)
  elseif sprites.filename then
    copy = util.table.deepcopy(sprites)
    fn(copy --[[@as khaoslib_sprites.Animation|khaoslib_sprites.Sprite]])
  else
    for _, sprite in ipairs(sprites) do
      table.insert(copy, khaoslib_sprites.traverse(sprite, fn))
    end
  end

  return copy
end

--- Replaces the given animations and sprites filenames.
--- @generic T : khaoslib_sprites.AnimationAll|khaoslib_sprites.SpriteAll
--- @param sprites T The animation or sprite or a table of them.
--- @param replacements {[string]: string} A table where the key is the original filename and the value is the new filename.
--- @return T copy A copy of the given animation or sprite or a table of them with the replaced filenames.
--- @nodiscard
function khaoslib_sprites.replace(sprites, replacements)
  if type(replacements) ~= "table" then error("replacements parameter: Expected table, got " .. type(replacements), 2) end

  for k, v in pairs(replacements) do
    if type(k) ~= "string" then error("replacements key: Expected string, got " .. type(k), 2) end
    if type(v) ~= "string" then error("replacements value: Expected string, got " .. type(v), 2) end
  end

  return khaoslib_sprites.traverse(sprites, function(sprite)
    if replacements[sprite.filename] then
      sprite.filename = replacements[sprite.filename]
    end
  end)
end

--- Tints animations and sprites with possible layers.
--- @generic T : khaoslib_sprites.AnimationAll|khaoslib_sprites.SpriteAll
--- @param sprites T The animation or sprite or a table of them.
--- @param tint data.Color A color table, e.g. {r=1, g=0.5, b=0, a=0.5}
--- @return T copy A copy of the given animation or sprite or a table of them with the tint applied.
--- @nodiscard
function khaoslib_sprites.tint(sprites, tint)
  if type(tint) ~= "table" then error("tint parameter: Expected table, got " .. type(tint), 2) end

  return khaoslib_sprites.traverse(sprites, function(sprite)
    sprite.tint = util.copy(tint)
  end)
end

return khaoslib_sprites
