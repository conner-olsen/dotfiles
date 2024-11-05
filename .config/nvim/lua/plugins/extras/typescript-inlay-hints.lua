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
      svelte = {
        settings = {
          svelte = {
            plugin = {
              typescript = {
                inlayHints = inlay_hints_settings,
              },
              javascript = {
                inlayHints = inlay_hints_settings,
              },
              html = {
                inlayHints = inlay_hints_settings,
              },
              css = {
                inlayHints = inlay_hints_settings,
              },
              svelte = {
                inlayHints = inlay_hints_settings,
              },
            },
            typescript = {
              inlayHints = inlay_hints_settings,
            },
            javascript = {
              inlayHints = inlay_hints_settings,
            },
            html = {
              inlayHints = inlay_hints_settings,
            },
            css = {
              inlayHints = inlay_hints_settings,
            },
            svelte = {
              inlayHints = inlay_hints_settings,
            },
          },
          inlay_hints = {
            enabled = true,
          },
        },
      },
    },
    inlay_hints = {
      enabled = true,
    },
  },
}
