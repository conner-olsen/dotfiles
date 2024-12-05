-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local wk = require("which-key")

wk.add({
  { "<leader>m", group = "Custom" },
  { "<leader>mm", "<cmd>Telescope keymaps<cr>", desc = "Search Keymaps" },
})

vim.keymap.set("i", "<C-l>", "<c-g>u<Esc>[s1z=`]a<c-g>u", { desc = "Correct previous spelling error", expr = false })
