vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

vim.wo.signcolumn = "yes"
vim.wo.number = true

vim.o.clipboard = "unnamedplus"
vim.o.shiftwidth = 0
vim.o.tabstop = 2
vim.o.expandtab = true
vim.o.showmode = false

vim.keymap.set({'n', 't'}, '<C-h>', function() vim.cmd.wincmd 'h' end, {})
vim.keymap.set({'n', 't'}, '<C-j>', function() vim.cmd.wincmd 'j' end, {})
vim.keymap.set({'n', 't'}, '<C-k>', function() vim.cmd.wincmd 'k' end, {})
vim.keymap.set({'n', 't'}, '<C-l>', function() vim.cmd.wincmd 'l' end, {})
vim.keymap.set({'n', 't'}, '<C-Tab>', vim.cmd.tabnext, {})
vim.keymap.set({'n', 't'}, '<CS-Tab>', vim.cmd.tabprevious, {})

vim.keymap.set('t', '<Esc>', '<C-\\><C-n>', {})
vim.keymap.set('t', '<C-Esc>', '<Esc>', {})

vim.api.nvim_create_autocmd('TermOpen', {
  callback = function(args)
    local winid = vim.api.nvim_get_current_win()
    vim.wo[winid][args.buf].number = false
    vim.wo[winid][args.buf].signcolumn = "no"
    vim.cmd.startinsert()
  end,
})

vim.keymap.set('n', '<leader>t', vim.cmd.terminal, {})


local path_package = vim.fn.stdpath('data') .. '/site/'
local mini_path = path_package .. 'pack/deps/start/mini.nvim'
if not vim.loop.fs_stat(mini_path) then
  vim.cmd('echo "Installing `mini.nvim`" | redraw')
  local clone_cmd = {
    'git', 'clone', '--filter=blob:none',
    'https://github.com/echasnovski/mini.nvim', mini_path
  }
  vim.fn.system(clone_cmd)
  vim.cmd('packadd mini.nvim | helptags ALL')
  vim.cmd('echo "Installed `mini.nvim`" | redraw')
end

require('mini.deps').setup({ path = { package = path_package } })

local add = MiniDeps.add

add({
  source = "folke/tokyonight.nvim"
})

vim.cmd[[ colorscheme tokyonight-night ]]

local hostname = vim.fn.hostname()

if hostname == "hippo" or hostname == "kangaroo" then
  add({
    source = 'neovim/nvim-lspconfig',
  })

  local lspconfig = require("lspconfig")
  lspconfig.bashls.setup({})
  lspconfig.ts_ls.setup({
    filetypes = {
      "javascript",
      "javascriptreact",
      "typescript",
      "typescriptreact"
    }
  })
  lspconfig.svelte.setup({})

  vim.api.nvim_create_autocmd('LspAttach', {
    callback = function(args)
      vim.keymap.set('n', '<leader>lr', vim.lsp.buf.rename, { buffer = args.buf })
    end,
  })

  add({
    source = "nvim-treesitter/nvim-treesitter",
    hooks = { post_checkout = function() vim.cmd('TSUpdate') end },
  })

  require("nvim-treesitter.configs").setup({
    ensure_installed = { "bash", "c", "lua", "vim", "vimdoc", "query", "javascript", "typescript", "svelte", "html", "css", "glsl" },
    sync_install = false,
    highlight = { enable = true },
    indent = { enable = true },
  })
end

require('mini.icons').setup({})
require('mini.completion').setup({})
require('mini.git').setup({})

require('mini.pick').setup({})
vim.keymap.set('n', '<leader>ff', MiniPick.builtin.files)
vim.keymap.set('n', '<leader>fg', MiniPick.builtin.grep_live)
vim.keymap.set('n', '<leader>bb', MiniPick.builtin.buffers)

require('mini.statusline').setup({})
require('mini.surround').setup({})
require('mini.trailspace').setup({})
require('mini.bracketed').setup({})
require('mini.comment').setup({})
require('mini.diff').setup({})
require('mini.bufremove').setup({})
vim.keymap.set('n', '<leader>bd', MiniBufremove.delete)

require('mini.files').setup({})
vim.keymap.set('n', '<leader>e', MiniFiles.open)
