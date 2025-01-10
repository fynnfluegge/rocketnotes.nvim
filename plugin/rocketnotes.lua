local plugin = require("rocketnotes")

vim.api.nvim_create_user_command("RocketNotesAuth", plugin.login, {})
vim.api.nvim_create_user_command("RocketNotesSync", plugin.sync, {})
