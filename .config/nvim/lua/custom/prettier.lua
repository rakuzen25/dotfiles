-- Resolve shared defaults per input file before sending them to Prettierd.
local config_path = vim.fn.expand '~/.config/prettier/.prettierrc.json'

local function matches(patterns, filename)
  if not patterns then
    return false
  end
  for _, pattern in ipairs(type(patterns) == 'table' and patterns or { patterns }) do
    local subject = pattern:find('/', 1, true) and vim.fs.relpath(vim.fs.dirname(config_path), filename)
      or vim.fs.basename(filename)
    if subject and vim.glob.to_lpeg(pattern):match(subject) then
      return true
    end
  end
  return false
end

return {
  env = {
    -- Avoid Prettierd's fallback override bug; defaults are supplied as flags.
    PRETTIERD_DEFAULT_CONFIG = '',
  },
  prepend_args = function(_, ctx)
    local config = vim.json.decode(table.concat(vim.fn.readfile(config_path), '\n'))
    local options = vim.deepcopy(config)
    options.overrides = nil
    options['$schema'] = nil
    for _, override in ipairs(config.overrides or {}) do
      if matches(override.files, ctx.filename) and not matches(override.excludeFiles, ctx.filename) then
        options = vim.tbl_extend('force', options, override.options)
      end
    end

    -- Project config values override the shared defaults.
    local args = { '--config-precedence=file-override' }
    for _, key in ipairs(vim.fn.sort(vim.tbl_keys(options))) do
      local value = options[key]
      assert(type(value) ~= 'table', 'Shared Prettier adapter requires a scalar option: ' .. key)
      local flag = key:gsub('%u', function(letter)
        return '-' .. letter:lower()
      end)
      args[#args + 1] = '--' .. flag .. '=' .. tostring(value)
    end
    return args
  end,
}
