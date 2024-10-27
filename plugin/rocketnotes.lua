local plugin = require("rocketnotes")

vim.api.nvim_create_user_command("RocketNotesLogin", plugin.login, {})
vim.api.nvim_create_user_command("RocketNotesInstall", plugin.install, {})
vim.api.nvim_create_user_command("RocketNotesSync", plugin.sync, {})
