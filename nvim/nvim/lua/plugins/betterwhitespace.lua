local disabled_filetypes = {
  "snacks_dashboard",
  "snacks_picker_list",
  "lazy",
}

return {
  "ntpeters/vim-better-whitespace",
  lazy = false,
  event = "BufReadPost", -- Or BufNewFile
  enabled = function()
    local disabled = false
    local node = vim.treesitter.get_node()
    disabled = disabled or (vim.tbl_contains(disabled_filetypes, vim.bo.filetype))
    disabled = disabled or (vim.bo.buftype == "prompt")
    disabled = disabled or not not (node and string.find(node:type(), "comment"))
    return not disabled
  end,
  config = function(_, opts)
    -- Optional: Add custom highlighting for specific modes/filetypes
    vim.api.nvim_set_hl(0, "ExtraWhitespace", { bg = "red" })
    vim.api.nvim_set_hl(0, "TrailingWhitespace", { bg = "red" })
    -- Enable highlighting
    vim.g.better_whitespace_enabled = true
    vim.g.strip_whitespace_on_save = true -- Auto-remove on save
  end,
}
