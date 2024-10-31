hls = {}
--%= hls.Normal = { fg = '#$GRAY_11' }
--%= hls.StatusLine = { bg = '#$GRAY_02', fg = '#$GRAY_11' }
--%= hls.StatusLineNC = { bg = '#$GRAY_02', fg = '#$GRAY_10' }
--%= hls.WinSeparator = { fg = '#$GRAY_06' }
--%= hls.LineNr = { fg = '#$GRAY_08' }
--%= hls.NonText = { fg = '#$GRAY_08' }
--%= hls.Search = { bg = '#$AMBER_04', fg = '#$AMBER_11' }
--%= hls.CurSearch = { bg = '#$AMBER_09', fg = '#$AMBER_01' }
--%= hls.Visual = { bg = '#$GRAY_03' }
--%= hls.Pmenu = { bg = '#$GRAY_03' }
--%= hls.PmenuSel = { reverse = true }

--%= hls.Added = { bg = '#$GREEN_02', fg = '#$GREEN_11' }
--%= hls.Removed = { bg = '#$RED_02', fg = '#$RED_11' }
--%= hls.Changed = { bg = '#$BLUE_02', fg = '#$BLUE_11' }

--%= hls.DiagnosticError = { bg = '#$RED_02', fg = '#$RED_11' }
--%= hls.DiagnosticWarn = { bg = '#$AMBER_02', fg = '#$AMBER_11' }
--%= hls.DiagnosticInfo = { bg = '#$GRAY_02', fg = '#$GRAY_11' }
--%= hls.DiagnosticHint = { bg = '#$BLUE_02', fg = '#$BLUE_11' }
--%= hls.DiagnosticOk = { bg = '#$GREEN_02', fg = '#$GREEN_11' }
--%= hls.DiagnosticDeprecated = { strikethrough = true, bg = '#$RED_02', fg = '#$RED_11' }
--%= hls.DiagnosticUnnecessary = { strikethrough = true, bg = '#$AMBER_02', fg = '#$AMBER_11' }
--%= hls.DiagnosticUnderlineError = { undercurl = true, sp = '#$RED_08' }
--%= hls.DiagnosticUnderlineWarn = { undercurl = true, sp = '#$AMBER_08' }
--%= hls.DiagnosticUnderlineInfo = { undercurl = true, sp = '#$GRAY_08' }
--%= hls.DiagnosticUnderlineHint = { undercurl = true, sp = '#$BLUE_08' }
--%= hls.DiagnosticUnderlineOk = { undercurl = true, sp = '#$GREEN_08' }

--%= hls.PreProc = { fg = '#$GRAY_10' }
--%= hls.Comment = { fg = '#$GRAY_10' }
--%= hls.Delimiter = { fg = '#$GRAY_07' }
--%= hls.Statement = { fg = '#$GRAY_10' }
--%= hls.Operator = { fg = '#$GRAY_10' }
--%= hls.Constant = { fg = '#$GREEN_11' }
--%= hls.String = { fg = '#$GREEN_11' }
--%= hls.Special = { fg = '#$GRAY_10' }

for group, def in pairs(vim.api.nvim_get_hl(0, {})) do
  if hls[group] then
    vim.api.nvim_set_hl(0, group, hls[group])
    hls[group] = nil
  elseif not def.link then
    vim.api.nvim_set_hl(0, group, {})
  end
end

for group, def in pairs(hls) do
  vim.api.nvim_set_hl(0, group, hls[group])
  hls[group] = nil
end
