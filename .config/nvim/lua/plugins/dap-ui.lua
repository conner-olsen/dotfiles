return {
  "rcarriga/nvim-dap-ui",
  opts = function(_, opts)
    opts.element_mappings = {
      stacks = {
        open = "<CR>",
        expand = "o",
      }
    }
    return opts
  end,
}

