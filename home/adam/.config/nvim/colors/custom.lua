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

--%= hls.PreProc = { fg = '#$GRAY_10' }
--%= hls.Comment = { fg = '#$GRAY_10' }
--%= hls['@variable'] = { fg = '#$GRAY_12' }
--%= hls['@none'] = { fg = '#$GRAY_12' }
--%= hls.Delimiter = { fg = '#$GRAY_10' }
--%= hls.Constant = { fg = '#$GREEN_11' }
--%= hls.String = { fg = '#$GREEN_11' }

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
