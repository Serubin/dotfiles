return {
  {
    "lazy-config",
    dir = vim.fn.stdpath("config"),
    config = function()
      -- Create autocommand group
      local augroup = vim.api.nvim_create_augroup("GitCommitFormatting", { clear = true })

      -- Add autocommand for gitcommit filetype
      vim.api.nvim_create_autocmd("FileType", {
        group = augroup,
        pattern = "gitcommit",
        callback = function()
          -- Check if first line starts with ## or ###
          local first_line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
          if first_line and first_line:match("^##") then
            -- Add two blank lines at the top
            vim.api.nvim_buf_set_lines(0, 0, 0, false, {"", ""})
          end

          -- Add space before ## or ###
          vim.cmd([[silent! %s/^\(##\+\)/ \1/e]])

          -- Set cursor to top left position (line 1, column 0)
          vim.api.nvim_win_set_cursor(0, {1, 0})
        end,
        desc = "Add space before ## or ### and add blank lines if needed"
      })
    end,
  },
}
