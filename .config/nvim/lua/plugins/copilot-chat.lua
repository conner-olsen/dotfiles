return {
  "CopilotC-Nvim/CopilotChat.nvim",
  branch = "canary",
  dependencies = {
    { "zbirenbaum/copilot.lua" },
    { "nvim-lua/plenary.nvim" },
  },
  opts = {
    model = "gpt-4",
    prompts = {
      CommitStaged = {
        prompt = [[
Write commit message for the change with commitizen convention.
Commit Messages must have a short description that is less than 50 characters followed by a newline and a more detailed description.
- Write concisely using an informal tone
- List significant changes
- Do not use specific names or files from the code
- Do not use phrases like "this commit", "this change", etc.
For the description, use this format:
- change/feature/enhancement 1
- change/feature/enhancement 2
- ... (you can add as few or as many bullets as needed. If it is a simple commit, like updating gitignore, one bullet is fine.)
]],
      },
    },
  },
}
