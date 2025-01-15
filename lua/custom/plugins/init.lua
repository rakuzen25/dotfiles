-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information
return {
  {
    'folke/snacks.nvim',
    priority = 1000,
    lazy = false,
    opts = {},
  },
  {
    'rmagatti/auto-session',
    lazy = false,

    ---enables autocomplete for opts
    ---@module "auto-session"
    ---@type AutoSession.Config
    opts = {
      suppressed_dirs = { '~/', '~/Projects', '~/Downloads', '/' },
      -- log_level = 'debug',
    },
  },
  { 'numToStr/Comment.nvim', opts = {} },
  {
    'okuuva/auto-save.nvim',
    cmd = 'ASToggle', -- optional for lazy loading on command
    event = { 'InsertLeave', 'TextChanged' }, -- optional for lazy loading on trigger events
    opts = {},
  },
  {
    'zbirenbaum/copilot.lua',
    cmd = 'Copilot',
    event = 'InsertEnter',
    opts = {
      -- suggestion = { enabled = false },
      -- panel = { enabled = false },
      suggestion = {
        auto_trigger = true,
      },
      filetypes = {
        yaml = true,
        markdown = true,
      },
    },
  },
  -- {
  --   'zbirenbaum/copilot-cmp',
  --   config = function()
  --     require('copilot_cmp').setup()
  --   end,
  -- },
  {
    {
      'CopilotC-Nvim/CopilotChat.nvim',
      dependencies = {
        -- { 'github/copilot.vim' }, -- or zbirenbaum/copilot.lua
        { 'zbirenbaum/copilot.lua' },
        { 'nvim-lua/plenary.nvim' }, -- for curl, log wrapper
      },
      build = 'make tiktoken', -- Only on MacOS or Linux
      opts = {
        -- See Configuration section for options
      },
      keys = {
        {
          '<leader>ccq',
          function()
            local input = vim.fn.input 'Quick Chat: '
            if input ~= '' then
              require('CopilotChat').ask(input, { selection = require('CopilotChat.select').buffer })
            end
          end,
          desc = 'CopilotChat: [q]uick chat',
        },
        {
          '<leader>ccp',
          function()
            local actions = require 'CopilotChat.actions'
            require('CopilotChat.integrations.telescope').pick(actions.prompt_actions())
          end,
          desc = 'CopilotChat: [p]rompt actions',
        },
      },
    },
  },
  { 'wakatime/vim-wakatime', lazy = false },
  {
    'danymat/neogen',
    opts = {
      snippet_engine = 'luasnip',
    },
  },
  { 'akinsho/toggleterm.nvim', version = '*', opts = { open_mapping = [[<c-\>]] } },
  {
    'pwntester/octo.nvim',
    requires = {
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope.nvim',
      'nvim-tree/nvim-web-devicons',
    },
    opts = {},
  },
  {
    'petertriho/cmp-git',
    dependencies = { 'hrsh7th/nvim-cmp' },
    opts = {
      -- options go here
    },
    init = function()
      table.insert(require('cmp').get_config().sources, { name = 'git' })
    end,
  },
  {
    'akinsho/bufferline.nvim',
    dependencies = 'nvim-tree/nvim-web-devicons',
    event = 'VeryLazy',
    keys = {
      { '<leader>bp', '<Cmd>BufferLineTogglePin<CR>', desc = 'Toggle [p]in' },
      { '<leader>bP', '<Cmd>BufferLineGroupClose ungrouped<CR>', desc = 'Delete non-[P]inned buffers' },
      { '<leader>br', '<Cmd>BufferLineCloseRight<CR>', desc = 'Delete buffers to the [r]ight' },
      { '<leader>bl', '<Cmd>BufferLineCloseLeft<CR>', desc = 'Delete buffers to the [l]eft' },
      { '<S-h>', '<cmd>BufferLineCyclePrev<cr>', desc = 'Prev Buffer' },
      { '<S-l>', '<cmd>BufferLineCycleNext<cr>', desc = 'Next Buffer' },
      { '[b', '<cmd>BufferLineCyclePrev<cr>', desc = 'Prev [b]uffer' },
      { ']b', '<cmd>BufferLineCycleNext<cr>', desc = 'Next [b]uffer' },
      { '[B', '<cmd>BufferLineMovePrev<cr>', desc = 'Move [B]uffer prev' },
      { ']B', '<cmd>BufferLineMoveNext<cr>', desc = 'Move [B]uffer next' },
    },
    opts = {
      options = {
      -- stylua: ignore
      close_command = function(n) Snacks.bufdelete(n) end,
      -- stylua: ignore
      right_mouse_command = function(n) Snacks.bufdelete(n) end,
        diagnostics = 'nvim_lsp',
        always_show_bufferline = false,
        diagnostics_indicator = function(_, _, diagnostics_dict)
          local s = ' '
          for e, n in pairs(diagnostics_dict) do
            local sym = e == 'error' and ' ' or (e == 'warning' and ' ' or ' ')
            s = s .. n .. sym
          end
          return s
        end,
        offsets = {
          {
            filetype = 'neo-tree',
            text = 'Neo-tree',
            highlight = 'Directory',
            text_align = 'left',
          },
        },
        numbers = function(opts)
          return string.format('%s%s', opts.id, opts.raise(opts.ordinal))
        end,
      },
    },
    config = function(_, opts)
      require('bufferline').setup(opts)
      -- Fix bufferline when restoring a session
      vim.api.nvim_create_autocmd({ 'BufAdd', 'BufDelete' }, {
        callback = function()
          vim.schedule(function()
            pcall(nvim_bufferline)
          end)
        end,
      })
    end,
  },
}
