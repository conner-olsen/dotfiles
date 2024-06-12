return {
  "shortcuts/no-neck-pain.nvim",
  config = function()
    require("no-neck-pain").setup({
      width = 150,
      autocmds = {
        enableOnVimEnter = true,
        enableOnTabEnter = true,
      },
      mappings = {
        enable = true,
      },
    })
  end,
}
