local inlay_hints_settings = {
    includeInlayEnumMemberValueHints = true,
    includeInlayFunctionLikeReturnTypeHints = true,
    includeInlayFunctionParameterTypeHints = true,
    includeInlayParameterNameHints = "all", -- was "literal"
    includeInlayParameterNameHintsWhenArgumentMatchesName = true, -- was false
    includeInlayPropertyDeclarationTypeHints = true,
    includeInlayVariableTypeHints = true, -- was false
    includeInlayVariableTypeHintsWhenTypeMatchesName = true, -- was false
  }

  return {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        tsserver = {
          settings = {
            typescript = {
              inlayHints = inlay_hints_settings,
            },
            javascript = {
              inlayHints = inlay_hints_settings,
            },
          },
        },
      },
    },
  }