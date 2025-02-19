-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local wk = require("which-key")

wk.add({
  { "<leader>m", group = "Custom" },
  { "<leader>mm", "<cmd>Telescope keymaps<cr>", desc = "Search Keymaps" },
})

vim.keymap.set("i", "<C-l>", "<c-g>u<Esc>[s1z=`]a<c-g>u", { desc = "Correct previous spelling error", expr = false })

local inkscape = require("telescope_inkscape_figures")

wk.add({
  { "<leader>i", group = "Inkscape" },
  { "<leader>is", inkscape.start_inkscape_manager, desc = "Start Inkscape Manager" },
  { "<leader>ik", inkscape.stop_inkscape_manager, desc = "Kill Inkscape Manager" },
  { "<leader>if", require("telescope").extensions.inkscape_figures.inkscape_figures, desc = "Find Figures" },
  {
    "<leader>ii",
    "<Esc><cmd>exec 'r!inkscape-figures-manager new -f -d figures -l \"'.getline('.').'\"'<CR>kkkkkkdd:%s/marginfigure/figure/g<CR>:%s/{figures\\//{/g<CR>jf{a",
    desc = "Insert Figure",
  },
})
