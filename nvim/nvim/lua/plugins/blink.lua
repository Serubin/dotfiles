local disabled_filetypes = {
  "gitcommit",
  "jjdescription",
  "markdown",
}

return {
  "saghen/blink.cmp",
  opts = {
    keymap = {
      -- presets: https://cmp.saghen.dev/configuration/keymap#presets
      preset = "super-tab",
    },
    enabled = function()
      local disabled = false
      local node = vim.treesitter.get_node()
      disabled = disabled or (vim.tbl_contains(disabled_filetypes, vim.bo.filetype))
      disabled = disabled or (vim.bo.buftype == "prompt")
      disabled = disabled or not not (node and string.find(node:type(), "comment"))
      return not disabled
    end,
  },
}
