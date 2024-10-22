-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Setup lazy.nvim
require("lazy").setup({
  "tpope/vim-sleuth",
  {
    "tpope/vim-fugitive",
    config = function ()
      vim.keymap.set('n', '<leader>g', vim.cmd.Git) 
    end
  },
  {
    "junegunn/fzf.vim",
    dependencies = {
      "junegunn/fzf",
    },
    config = function ()
      vim.keymap.set('n', '<leader>f', vim.cmd.Files) 
      vim.keymap.set('n', '<leader>b', vim.cmd.Buffers) 
      vim.keymap.set('n', '<leader>/', vim.cmd.RG) 
    end
  },
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function () 
      local configs = require("nvim-treesitter.configs")

      configs.setup({
        ensure_installed = { "bash", "c", "lua", "vim", "vimdoc", "query", "javascript", "typescript", "html", "css" },
        sync_install = false,
        highlight = { enable = true },
        indent = { enable = true },  
      })
    end
  },
  {
    "neovim/nvim-lspconfig",
    config = function ()
      local lspconfig = require("lspconfig")

      lspconfig.bashls.setup({})
      lspconfig.ts_ls.setup({
        filetypes = {
          "javascript",
          "typescript"
        }
      })
    end
  }
})

vim.opt.clipboard = "unnamedplus"
