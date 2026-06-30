return {
	-- Add solarized
	{ "altercation/vim-colors-solarized" },
	-- Configure LazyVim to load solarized
	{
		"LazyVim/LazyVim",
		opts = {
			colorscheme = "solarized",
		},
	},
}
