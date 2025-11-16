return {
  'ntpeters/vim-better-whitespace',
  lazy = false,
  event = "BufReadPost", -- Or BufNewFile
  opts = {
    -- Options to customize behavior if needed
  },
  config = function(_, opts)
    -- Optional: Add custom highlighting for specific modes/filetypes
    vim.api.nvim_set_hl(0, "ExtraWhitespace", { bg = "red" })
    vim.api.nvim_set_hl(0, "TrailingWhitespace", { bg = "red" })
    -- Enable highlighting
    vim.g.better_whitespace_enabled = true
    vim.g.strip_whitespace_on_save = true -- Auto-remove on save
  end
}