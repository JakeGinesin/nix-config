-- =========================================================
--  FILE: init.lua
--  A translation of the provided Vimscript config to Lua.
-- =========================================================

-- filetype detection / plugin / indent
vim.cmd([[
  filetype on
  filetype plugin on
  filetype indent on
  syntax on
]])

-- Basic UI
vim.opt.number = true           -- set number
vim.opt.relativenumber = false  -- 'set nu' in Vimscript doesn't mean relative. If you prefer relativenumber, set it to true
vim.opt.showcmd = true
vim.opt.showmode = true
vim.opt.showmatch = true        -- highlights matching brackets
vim.opt.hlsearch = true
vim.opt.history = 1000
vim.opt.wrap = false
vim.opt.scrolloff = 10
vim.opt.incsearch = true
vim.opt.ignorecase = true
vim.opt.smartcase = true


-- Tab / indentation
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2
vim.opt.smarttab = true
vim.opt.cindent = true
vim.opt.expandtab = true

-- Turn off backups, swaps
vim.opt.backup = false
vim.opt.swapfile = false
vim.opt.undofile = true
vim.opt.undodir = os.getenv("HOME") .. "/.local/share/nvim/cache"

-- For line length column marking
vim.opt.colorcolumn = "0"
vim.opt.textwidth = 0  -- alternative if you want no fixed textwidth

-- Some other miscellaneous settings
vim.opt.shortmess:append("c")    -- don't give |ins-completion-menu| messages
vim.opt.wildmenu = true
vim.opt.wildmode = { "longest", "list" }
vim.opt.wildignore:append({
  "*.docx", "*.jpg", "*.png", "*gif", "*.pdf", "*.pyc",
  "*.exe", "*.flv", "*.img", "*.png"
})
vim.opt.termguicolors = true     -- truecolor mode
vim.opt.mouse = "a"              -- enable mouse
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.updatetime = 300         -- faster completion
vim.opt.signcolumn = "auto"
vim.opt.title = true
vim.opt.titlestring = "%F - NVIM" -- File path and "Neovim" branding
-- vim.opt.titlestring = "%(%{expand(\"%:~:h\")}%)#%(% t%)%(% M%)%(% )NVIM"

-- Append '+' register to clipboard
vim.opt.clipboard:append("unnamedplus")

-- Stop showing matching paren (and disable matchparen plugin)
vim.g.loaded_matchparen = 1
vim.opt.showmatch = false

-- t_ZH, t_ZR (italics) — for older terminal support
vim.cmd([[ let &t_ZH = "\e[3m" ]])
vim.cmd([[ let &t_ZR = "\e[23m" ]])

-- netrw settings
vim.g.netrw_banner = 0
vim.g.netrw_liststyle = 0
vim.g.netrw_browse_split = 4
vim.g.netrw_altv = 1
vim.g.netrw_winsize = 25
vim.g.netrw_keepdir = 0
vim.g.netrw_localcopydircmd = "cp -r"

-- Remember cursor location (viminfo)
vim.opt.viminfo = "'100,\"2500,:200,%,n~/.cache/.viminfo"

-- Encodings
vim.opt.fileencodings = { "utf-8" }
vim.opt.encoding = "utf-8"

-- Leader key
vim.g.mapleader = ","

vim.opt_local.conceallevel = 0
vim.opt_local.foldmethod  = 'manual'
-- Keep treesitter, ditch legacy syntax:
vim.g.markdown_fenced_languages = {}

vim.opt.shell = "zsh"

vim.loader.enable() 

------------------------------------------------------
--                  KEY MAPPINGS
------------------------------------------------------
local opts = { noremap = true, silent = true }

-- Clear search highlights when pressing ESC in normal mode
vim.api.nvim_set_keymap("n", "<Esc>", ":noh<CR><Esc>", opts)

-- The literal mapping from the original: "nnoremap <esc>^[ <esc>^["
vim.api.nvim_set_keymap("n", "<Esc>^[", "<Esc>^[", { noremap = true })

-- inoremap {<CR> {<CR>}<C-o>O}
vim.api.nvim_set_keymap("i", "{<CR>", "{<CR>}<C-o>O", { noremap = true })

local map  = vim.keymap.set
local opts = { noremap = true, silent = true }
-- yank link
map("n", "<leader>yl", "?\\](<CR>lvi)y<Cmd>nohlsearch<CR>", opts)

-- Save file with Ctrl+S
vim.cmd([[
  command -nargs=0 -bar Update if &modified
    \| if empty(bufname('%'))
    \|   browse confirm write
    \| else
    \|   confirm write
    \| endif
    \|endif
]])
vim.api.nvim_set_keymap("n", "<C-S>", ":<C-u>Update<CR>", opts)
vim.api.nvim_set_keymap("i", "<C-S>", "<Esc>:Update<CR>", opts)

-- Terminal toggles
vim.api.nvim_set_keymap("n", "<C-t>", ":term<CR>A", { noremap = true, silent = false })
vim.api.nvim_set_keymap("t", "<Esc>", [[<C-\><C-n>]], { noremap = true })

-- "Focus" commands that rely on the Goyo plugin
-- vim.api.nvim_set_keymap("n", "<C-a>z", ":Goyo 80<CR>", opts)
-- vim.api.nvim_set_keymap("n", "<C-a>q", ":Goyo!<CR>", opts)

-- Movements in visual mode
vim.api.nvim_set_keymap("x", "<C-h>", "b", { noremap = true })
vim.api.nvim_set_keymap("x", "<C-l>", "w", { noremap = true })

-- Map Ctrl-Backspace to delete the previous word in insert mode
vim.api.nvim_set_keymap("i", "<C-BS>", "<C-W>", { noremap = true })
vim.api.nvim_set_keymap("i", "<C-H>", "<C-W>", { noremap = true })

-- nagiation
vim.api.nvim_set_keymap('n', '<C-j>', '<C-w>h', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<C-k>', '<C-w>j', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<C-i>', '<C-w>k', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<C-l>', '<C-w>l', { noremap = true, silent = true })

------------------------------------------------------
--                    AUTOCMD
------------------------------------------------------
local wrapLineInTexFile = vim.api.nvim_create_augroup("WrapLineInTexFile", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "md" },
  group = wrapLineInTexFile,
  command = "setlocal wrap"
})

vim.api.nvim_create_augroup("vimrc", { clear = true })

-- vim.api.nvim_create_autocmd("FileType", {
    -- desc = "texpresso compile",
    -- group = "vimrc",
    -- pattern = "tex",
    -- callback = function(args)
        -- -- start server on first BufWrite
        -- vim.api.nvim_create_autocmd("BufWritePost", {
            -- group = vim.api.nvim_create_augroup(
                -- string.format("latex<buffer=%d>", args.buf),
                -- { clear = true }
            -- ),
            -- buffer = args.buf,
            -- callback = function()
                -- if not vim.b.latex_started then
                    -- vim.cmd "TeXpresso %"
                    -- vim.b.latex_started = true
                -- end
                -- -- vim.cmd "VimtexView"
            -- end,
        -- })
    -- end,
-- })

-- idk why i need to define it here bro
-- local builtin = require('telescope.builtin')
-- vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Telescope find files' })
-- vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Telescope live grep' })
-- vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Telescope buffers' })
-- vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Telescope help tags' })
