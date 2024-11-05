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
        ensure_installed = { "bash", "c", "lua", "vim", "vimdoc", "query", "javascript", "typescript", "svelte", "html", "css", "glsl" },
        sync_install = false,
        highlight = { enable = true },
        indent = { enable = true },  
      })
    end
  },
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp"
    },
    config = function ()
      local lspconfig = require("lspconfig")
      local cmp_nvim_lsp = require("cmp_nvim_lsp")
      local capabilities = cmp_nvim_lsp.default_capabilities()

      lspconfig.bashls.setup({
        capabilities = capabilities
      })
      lspconfig.ts_ls.setup({
        capabilities = capabilities,
        filetypes = {
          "javascript",
          "typescript"
        }
      })
      lspconfig.svelte.setup({
        capabilities = capabilities,
      })

      vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
        group = vim.api.nvim_create_augroup("float_diagnostic", { clear = true }),
        callback = function ()
          vim.diagnostic.open_float(nil, { focus=false })
        end
      })

      vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(args)
          vim.keymap.set('n', '<leader>r', vim.lsp.buf.rename, { buffer = args.buf }) 
          vim.keymap.set('n', '<leader>d', vim.lsp.buf.definition, { buffer = args.buf }) 
        end,
      })
    end
  },
  {
    'hrsh7th/nvim-cmp',
    dependencies = {
      "hrsh7th/cmp-nvim-lsp"
    },
    config = function()
      local cmp = require('cmp')
      cmp.setup({
        sources = cmp.config.sources({
          { name = 'nvim_lsp' }
        }),
        mapping = cmp.mapping.preset.insert()
      })
    end
  }
})

vim.o.updatetime = 250
vim.wo.signcolumn = "yes"
vim.wo.number = true
vim.opt.clipboard = "unnamedplus"
vim.cmd.colorscheme "custom"

vim.filetype.add({
  extension = {
    glsl = 'glsl',
    vert = 'glsl',
    frag = 'glsl',
    svelte = 'svelte',
    ['svelte.js'] = 'svelte',
    ['svelte.ts'] = 'svelte',
  }
})

vim.diagnostic.config({
  virtual_text = false
})

local orig_util_open_floating_preview = vim.lsp.util.open_floating_preview
function vim.lsp.util.open_floating_preview(contents, syntax, opts, ...)
  opts = opts or {}
  opts.border = opts.border or "rounded"
  return orig_util_open_floating_preview(contents, syntax, opts, ...)
end
