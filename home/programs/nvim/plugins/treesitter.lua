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

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("ts_highlight", { clear = true }),
  callback = function(args)
    local ft = vim.bo[args.buf].filetype
    local lang = vim.treesitter.language.get_lang(ft) or ft
    if disabled[lang] then return end
    -- pcall: silently skip filetypes with no installed parser
    pcall(vim.treesitter.start, args.buf, lang)
  end,
})
