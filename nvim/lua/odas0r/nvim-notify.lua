local notify = require("notify")

notify.setup({
  background_colour = "#ffffff",
  fps = 30,
  icons = {
    DEBUG = "Debugging",
    ERROR = "Error",
    INFO = "🛈  Info",
    TRACE = "✎  Trace",
    WARN = "⚠ Warning",
  },
  level = 2,
  minimum_width = 50,
  render = "default",
  stages = "fade_in_slide_out",
  timeout = 3000,
  top_down = true,
})

vim.notify = notify
