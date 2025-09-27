-- Enable filetype plugins, indent, and syntax highlighting.
vim.cmd("filetype plugin indent on")
vim.cmd("syntax enable")

-- Viewer options: either with a built-in viewer method or with a generic interface.
vim.g.vimtex_view_method = 'zathura'
vim.g.vimtex_view_general_viewer = 'zathura'
vim.g.vimtex_view_general_options = '--unique file:@pdf#src:@line@tex'

-- Set the TeX flavor and quickfix mode.
vim.g.tex_flavor = 'latex'
vim.g.vimtex_quickfix_mode = 0
vim.g.vimtex_quickfix_enabled = 0

-- Compiler backend.
vim.g.vimtex_compiler_method = 'latexmk'

-- Set the local leader (default is "\"; here we change it to comma).
vim.g.maplocalleader = ','

-- Configure warnings to ignore.
vim.g.Tex_IgnoredWarnings = [[
Package hyperref Warning
Token not allowed in a PDF string (Unicode)
removing math shift
removing superscript
Underfull
Overfull
specifier changed to
You have requested
Missing number, treated as zero.
There were undefined references
Citation %.%# undefined
Double space found.
]]
vim.g.Tex_IgnoreLevel = 8

-- Delete extra compilation files when a TeX buffer is deleted.
vim.api.nvim_create_autocmd("BufDelete", {
  pattern = "*.tex",
  command = "silent! !latexmk -c > /dev/null 2>&1 %:p",
})
