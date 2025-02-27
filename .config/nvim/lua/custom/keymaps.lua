local map = vim.keymap.set

-- Resize window using <ctrl> arrow keys
map('n', '<C-Up>', '<cmd>resize +2<cr>', { desc = 'Increase Window Height' })
map('n', '<C-Down>', '<cmd>resize -2<cr>', { desc = 'Decrease Window Height' })
map('n', '<C-Left>', '<cmd>vertical resize -2<cr>', { desc = 'Decrease Window Width' })
map('n', '<C-Right>', '<cmd>vertical resize +2<cr>', { desc = 'Increase Window Width' })

-- buffers
map('n', '<leader>bb', '<cmd>e #<cr>', { desc = 'Switch to other [b]uffer' })
-- map('n', '<leader>`', '<cmd>e #<cr>', { desc = 'Switch to Other Buffer' })
map('n', '<leader>bd', function()
  Snacks.bufdelete()
end, { desc = '[D]elete buffer' })
map('n', '<leader>bo', function()
  Snacks.bufdelete.other()
end, { desc = 'Delete [o]ther buffers' })
map('n', '<leader>bD', '<cmd>:bd<cr>', { desc = '[D]elete buffer and window' })

-- Add undo break-points
map('i', ',', ',<c-g>u')
map('i', '.', '.<c-g>u')
map('i', ';', ';<c-g>u')

-- save file
map({ 'i', 'x', 'n', 's' }, '<C-s>', '<cmd>w<cr><esc>', { desc = 'Save File' })
map('n', '<leader>ts', ':ASToggle<CR>', { desc = '[T]oggle Auto[S]ave' })

-- lazygit
if vim.fn.executable 'lazygit' == 1 then
  map('n', '<leader>gg', function()
    Snacks.lazygit()
  end, { desc = 'Lazy[g]it' })
  map('n', '<leader>gf', function()
    Snacks.lazygit.log_file()
  end, { desc = 'Lazygit: current [f]ile history' })
  map('n', '<leader>gL', function()
    Snacks.lazygit.log()
  end, { desc = 'Lazygit: [L]og' })
end

map('n', '<leader>gb', function()
  Snacks.git.blame_line()
end, { desc = 'Git: [b]lame line' })
map({ 'n', 'x' }, '<leader>gy', function()
  Snacks.gitbrowse {
    open = function(url)
      vim.fn.setreg('+', url)
    end,
    notify = false,
  }
end, { desc = 'Git: [y]ank repo URL' })

-- luasnip
local ls = require 'luasnip'
map({ 'i' }, '<C-K>', function()
  ls.expand()
end, { silent = true })
map({ 'i', 's' }, '<C-L>', function()
  ls.jump(1)
end, { silent = true })
map({ 'i', 's' }, '<C-J>', function()
  ls.jump(-1)
end, { silent = true })
map({ 'i', 's' }, '<C-E>', function()
  if ls.choice_active() then
    ls.change_choice(1)
  end
end, { silent = true })

-- Session search
map('n', '<leader>ss', '<cmd>SessionSearch<cr>', { desc = '[S]earch [s]essions' })

-- neogen
map('n', '<Leader>n', ":lua require('neogen').generate()<CR>", { noremap = true, silent = true, desc = 'neogen' })

-- Configuration files
map('n', '<leader>,,', '<cmd>e ~/.config/nvim/init.lua<cr>', { desc = 'Configure init.lua' })
map('n', '<leader>,k', '<cmd>e ~/.config/nvim/lua/custom/keymaps.lua<cr>', { desc = 'Configure [k]eymaps' })
map('n', '<leader>,p', '<cmd>e ~/.config/nvim/lua/custom/plugins/init.lua<cr>', { desc = 'Configure [p]lugins' })
