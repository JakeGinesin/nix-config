-- require('nvim-treesitter.configs').setup {
  -- ensure_installed = {},
  -- auto_install = false,
  -- highlight = { enable = true },
  -- indent = { enable = true },
-- }

-- require('nvim-treesitter.configs').setup({
  -- highlight = {
    -- enable = true,                -- keep TS for everything else
    -- disable = { "markdown", "markdown_inline" },
    -- additional_vim_regex_highlighting = false,
  -- },
  -- indent                = { enable = false },
  -- incremental_selection = { enable = false },
-- })

local disabled = { markdown = true, markdown_inline = true }

-- Newer Neovim's runtime markdown ftplugin calls vim.treesitter.start() itself.
-- Wrap it so disabled languages never start at all, instead of starting and
-- getting stopped afterward (which costs a full parse on big files).
local ts_start = vim.treesitter.start
vim.treesitter.start = function(bufnr, lang)
  if bufnr == nil or bufnr == 0 then bufnr = vim.api.nvim_get_current_buf() end
  lang = lang or vim.treesitter.language.get_lang(vim.bo[bufnr].filetype)
  if lang and disabled[lang] then return end
  return ts_start(bufnr, lang)
end

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("ts_highlight", { clear = true }),
  callback = function(args)
    local ft = vim.bo[args.buf].filetype
    local lang = vim.treesitter.language.get_lang(ft) or ft
    -- pcall: silently skip filetypes with no installed parser
    pcall(vim.treesitter.start, args.buf, lang)
  end,
})
