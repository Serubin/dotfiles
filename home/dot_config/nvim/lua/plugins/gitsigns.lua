-- Workaround for a gitsigns.nvim bug (Neovim 0.11.2+, native vim.system):
-- the cwd-HEAD branch watcher (setup_cwd_head -> setup_cwd_watcher) starts an
-- fs_event on <gitdir>/HEAD, re-arms on every event, and calls Repo.get_info
-- (git rev-parse) un-serialized, bypassing the attach-path semaphore. On any
-- FSEvents-monitored path (everything under $HOME) the re-arm self-triggers,
-- spawning unreaped `git rev-parse` until the per-uid process table fills
-- (EAGAIN) and Neovim wedges. Remove once fixed upstream.
return {
  "lewis6991/gitsigns.nvim",
  opts = function(_, opts)
    local uv = vim.uv or vim.loop
    local unpack = table.unpack or unpack

    -- Guard 1: neuter ONLY the cwd-HEAD watcher (fs_event on '*/HEAD').
    -- The per-buffer sign watcher watches the gitdir directory, so it is
    -- unaffected. Applied to the shared fs_event metatable before setup().
    local ok, probe = pcall(uv.new_fs_event)
    if ok and probe then
      local mt = getmetatable(probe)
      pcall(function() probe:close() end)
      if mt and mt.__index and type(mt.__index.start) == "function" then
        local orig_start = mt.__index.start
        mt.__index.start = function(self, path, flags, cb)
          if type(path) == "string" and path:match("/HEAD$") then
            return 0 -- pretend success; do not actually watch HEAD
          end
          return orig_start(self, path, flags, cb)
        end
      end
    end

    -- Guard 2: serialize repo detection (bounds the DirChanged path too).
    local okg, gitmod = pcall(require, "gitsigns.git")
    local oka, async = pcall(require, "gitsigns.async")
    if okg and oka and gitmod.Repo and async.semaphore then
      local Repo = gitmod.Repo
      local orig_get_info = Repo.get_info
      local sem = async.semaphore(1)
      Repo.get_info = function(...)
        local n = select("#", ...)
        local args = { ... }
        return sem:with(function()
          return orig_get_info(unpack(args, 1, n))
        end)
      end
    end

    return opts
  end,
}
