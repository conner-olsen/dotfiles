local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local M = {}

function list_figures()
  local i, t, popen = 0, {}, io.popen
  local pfile = popen([[inkscape-figures-manager list]])
  for filename in pfile:lines() do
    i = i + 1
    t[i] = filename
  end
  pfile:close()
  return t
end

function find_svg_figures()
  return finders.new_table({
    results = list_figures(),
  })
end

function M.inkscape_figures()
  pickers
    .new(require("telescope.themes").get_dropdown({}), {
      prompt_title = "Figures",
      finder = find_svg_figures(),
      sorter = conf.file_sorter(),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          vim.fn.system({ "inkscape-figures-manager", "edit", selection[1] })
        end)
        return true
      end,
    })
    :find()
end

-- Store the job id globally to access it when stopping
M.inkscape_manager_job = nil

-- Function to start inkscape-figures-manager
function M.start_inkscape_manager()
  if M.inkscape_manager_job then
    vim.notify("Inkscape manager is already running!", vim.log.levels.WARN)
    return
  end

  M.inkscape_manager_job = vim.fn.jobstart("inkscape-figures-manager start", {
    on_exit = function(_, exit_code)
      -- Only show error for unexpected exits, not when we're intentionally stopping
      if exit_code ~= 0 and exit_code ~= 143 then
        vim.notify("Inkscape manager exited with code: " .. exit_code, vim.log.levels.ERROR)
      end
      M.inkscape_manager_job = nil
    end,
    on_stderr = function(_, data)
      -- Only show non-empty error messages that aren't from normal termination
      if data and data[1] and data[1] ~= "" then
        vim.notify("Inkscape manager error: " .. vim.inspect(data), vim.log.levels.ERROR)
      end
    end,
  })

  if M.inkscape_manager_job <= 0 then
    vim.notify("Failed to start inkscape manager", vim.log.levels.ERROR)
    M.inkscape_manager_job = nil
    return
  end

  vim.notify("Inkscape manager started", vim.log.levels.INFO)
end

-- Function to stop inkscape-figures-manager
function M.stop_inkscape_manager()
  if not M.inkscape_manager_job then
    vim.notify("Inkscape manager is not running!", vim.log.levels.WARN)
    return
  end

  -- Try to terminate the job gracefully
  vim.fn.jobstop(M.inkscape_manager_job)

  -- Clean up our job reference
  M.inkscape_manager_job = nil
  vim.notify("Inkscape manager stopped", vim.log.levels.INFO)
end

return M
