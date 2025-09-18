if ... ~= "__khaoslib__.sprites" then
  return require("__khaoslib__.sprites")
end

--- Utilities for sprites manipulation.
--- ```lua
--- local khaoslib_sprites = require("__khaoslib__.sprites")
--- ```
--- @class khaoslib_sprites
local khaoslib_sprites = {}

--- Tints a sprite with possible layers.
--- @generic T : data.Animation|data.AnimationSheet|data.RotatedAnimation|data.RotatedSprite|data.Sprite|data.SpriteNWaySheet|data.SpriteSheet
--- @param sprite T
--- @param tint data.Color
--- @return T
function khaoslib_sprites.tint(sprite, tint)
  local copy = table.deepcopy(sprite)
  ---@cast copy data.Animation|data.AnimationSheet|data.RotatedAnimation|data.RotatedSprite|data.Sprite|data.SpriteNWaySheet|data.SpriteSheet

  if copy.layers then
    copy.layers = khaoslib_sprites.tint_all(copy.layers, tint)
  else
    copy.tint = table.deepcopy(tint)
  end

  return copy
end

--- Tints all sprites with possible layers.
--- @generic T : data.Animation[]|data.AnimationSheet[]|data.RotatedAnimation[]|data.RotatedSprite[]|data.Sprite[]|data.SpriteNWaySheet[]|data.SpriteSheet[]|data.Sprite4Way|data.Sprite16Way
--- @param sprites T
--- @param tint data.Color
--- @return T
function khaoslib_sprites.tint_all(sprites, tint)
  local copy = table.deepcopy(sprites)
  ---@cast copy data.Animation[]|data.AnimationSheet[]|data.RotatedAnimation[]|data.RotatedSprite[]|data.Sprite[]|data.SpriteNWaySheet[]|data.SpriteSheet[]|data.Sprite4Way|data.Sprite16Way

  if copy.sheets then
    copy.sheets = khaoslib_sprites.tint_all(copy.sheets, tint)
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
  elseif copy.filename then
    copy = khaoslib_sprites.tint(sprites, tint)
  else
    local new = {}
    ---@cast new data.Animation[]|data.AnimationSheet[]|data.RotatedAnimation[]|data.RotatedSprite[]|data.Sprite[]|data.SpriteNWaySheet[]|data.SpriteSheet[]

    for _, sprite in pairs(copy) do
      table.insert(new, khaoslib_sprites.tint(sprite, tint))
    end
    copy = new
  end

  return copy
end

return khaoslib_sprites
