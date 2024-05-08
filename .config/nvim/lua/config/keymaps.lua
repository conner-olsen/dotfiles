-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local wk = require("which-key")

wk.register({
  c = {
    p = {
      name = "+copilot",
      t = { "<cmd>lua require('CopilotChat').toggle()<cr>", "Toggle chat window" },
      r = { "<cmd>CopilotChatReset<cr>", "Reset chat window" },
      C = { "<cmd>CopilotChatCommitStaged<cr>", "Write commit message for staged changes" },
      f = { "<Cmd>CopilotChatFixDiagnostic<CR>", "Assist with the diagnostic issue" },
    },
  },
}, { prefix = "<leader>" })

wk.register({
  c = {
    p = {
      name = "+copilot",
      e = { "<Cmd>CopilotChatExplain<CR>", "Explain the active selection" },
      r = { "<Cmd>CopilotChatReview<CR>", "Review the selected code" },
      f = { "<Cmd>CopilotChatFix<CR>", "Fix a problem in the code" },
      o = { "<Cmd>CopilotChatOptimize<CR>", "Optimize the selected code" },
      d = { "<Cmd>CopilotChatDocs<CR>", "Add documentation comment for the selection" },
      t = { "<Cmd>CopilotChatTests<CR>", "Generate tests for the code" },
    },
  },
}, { prefix = "<leader>", mode = "v" })
