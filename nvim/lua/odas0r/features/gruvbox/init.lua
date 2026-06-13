local M = {}

M.Gruvbox = require("gruvbox")

M.colors = function()
  local Gruvbox = M.Gruvbox

  local p = Gruvbox.palette
  local config = Gruvbox.config

  for color, hex in pairs(config.palette_overrides) do
    p[color] = hex
  end

  local bg = vim.o.background
  local contrast = config.contrast

  local color_groups = {
    dark = {
      bg0 = p.dark0,
      bg1 = p.dark1,
      bg2 = p.dark2,
      bg3 = p.dark3,
      bg4 = p.dark4,
      fg0 = p.light0,
      fg1 = p.light1,
      fg2 = p.light2,
      fg3 = p.light3,
      fg4 = p.light4,
      red = p.bright_red,
      green = p.bright_green,
      yellow = p.bright_yellow,
      blue = p.bright_blue,
      purple = p.bright_purple,
      aqua = p.bright_aqua,
      orange = p.bright_orange,
      neutral_red = p.neutral_red,
      neutral_green = p.neutral_green,
      neutral_yellow = p.neutral_yellow,
      neutral_blue = p.neutral_blue,
      neutral_purple = p.neutral_purple,
      neutral_aqua = p.neutral_aqua,
      dark_red = p.dark_red,
      dark_green = p.dark_green,
      dark_aqua = p.dark_aqua,
      gray = p.gray,
    },
    light = {
      bg0 = p.light0,
      bg1 = p.light1,
      bg2 = p.light2,
      bg3 = p.light3,
      bg4 = p.light4,
      fg0 = p.dark0,
      fg1 = p.dark1,
      fg2 = p.dark2,
      fg3 = p.dark3,
      fg4 = p.dark4,
      red = p.faded_red,
      green = p.faded_green,
      yellow = p.faded_yellow,
      blue = p.faded_blue,
      purple = p.faded_purple,
      aqua = p.faded_aqua,
      orange = p.faded_orange,
      neutral_red = p.neutral_red,
      neutral_green = p.neutral_green,
      neutral_yellow = p.neutral_yellow,
      neutral_blue = p.neutral_blue,
      neutral_purple = p.neutral_purple,
      neutral_aqua = p.neutral_aqua,
      dark_red = p.light_red,
      dark_green = p.light_green,
      dark_aqua = p.light_aqua,
      gray = p.gray,
    },
  }

  if contrast ~= nil and contrast ~= "" then
    color_groups[bg].bg0 = p[bg .. "0_" .. contrast]
    color_groups[bg].dark_red = p[bg .. "_red_" .. contrast]
    color_groups[bg].dark_green = p[bg .. "_green_" .. contrast]
    color_groups[bg].dark_aqua = p[bg .. "_aqua_" .. contrast]
  end

  return color_groups[bg]
end

M.config = function()
  local Gruvbox = M.Gruvbox
  return Gruvbox.config
end

M.palette = function()
  local Gruvbox = M.Gruvbox
  return Gruvbox.palette
end

return M
