local api, fn, ffi = vim.api, vim.fn, require('ffi')
local group = api.nvim_create_augroup('MTMgroup', {})
local mtm_startup = false

ffi.cdef([[
  typedef int32_t linenr_T;
  char *ml_get(linenr_T lnum);
]])

local alignment = {
  ['default'] = '--|',
  ['left'] = ':-|',
  ['center'] = '::|',
  ['right'] = '-:|',
}

local opt = {
  filetype = {
    '*.md',
  },
  options = {
    insert = true, -- when typing "|"
    insert_leave = true, -- when leaving insert
    pad_separator_line = false, -- add space in separator line
    align_style = 'default', -- default, left, center, right
  },
}

local function table_insert(tab, cell, num)
  for _ = 1, num do
    table.insert(tab, cell)
  end
  return tab
end

local function add_char_inline(line, char, pos)
  return line:sub(1, pos) .. char .. line:sub(pos + 1)
end

local function check_line_is_table(line_number)
  local line = ffi.string(ffi.C.ml_get(line_number))
  return string.match(line, '^|.*|$')
end

local function line_to_cells(line)
  local table_cells = {}
  for cell in line:gmatch('([^|]+)%|') do
    cell = cell:match('^%s*(.-)%s*$')
    table.insert(table_cells, cell)
  end
  return table_cells
end

local function format_cell(cell, width)
  cell = ' ' .. cell .. ' '
  cell = cell .. string.rep(' ', width - fn.strdisplaywidth(cell) + 2)
  return cell
end

local function find_table_range(cursor_pos, range)
  local start_line_number, end_line_number = cursor_pos[1], range == -1 and 1 or fn.line('$')

  for i = start_line_number, end_line_number, range do
    if not check_line_is_table(i) then
      return i - range
    end
    if i == end_line_number then
      return i
    end
  end

  return -1
end

local function table_to_cells(tab)
  local cells = {}
  for i = 1, #tab do
    table.insert(cells, line_to_cells(tab[i]))
  end
  return cells
end

local function get_max_cells_width(cells)
  local width = {}
  for _ = 1, #cells[1], 1 do
    table.insert(width, 0)
  end

  for i = 1, #cells, 1 do
    if i == 2 then
      goto continue
    end

    if #cells[i] > #width then
      table_insert(width, 0, #cells[i] - #width)
    end
    for _, cell in ipairs(cells[i]) do
      width[_] = math.max(width[_], cell and fn.strdisplaywidth(cell) or 0)
    end

    ::continue::
  end
  return width
end

local function get_table_infos()
  local table_infos = {}
  local cursor_pos = api.nvim_win_get_cursor(0)
  table_infos.table_start_line_number, table_infos.table_end_line_number =
    find_table_range(cursor_pos, -1), find_table_range(cursor_pos, 1)
  table_infos.current_table = api.nvim_buf_get_lines(
    0,
    table_infos.table_start_line_number - 1,
    table_infos.table_end_line_number,
    true
  )
  table_infos.cells = table_to_cells(table_infos.current_table)
  table_infos.max_cells_width = get_max_cells_width(table_infos.cells)
  return table_infos
end

local function format_separator_line(cells, width)
  local line, bias = '|', opt.options.pad_separator_line
  for i = 1, #cells do
    local left_char = cells[i]:sub(1, 1)
    local right_char = cells[i]:sub(#cells[i])
    local num = width[i]
    if bias then
      num = num - 2
      left_char = ' ' .. left_char
      right_char = right_char .. ' '
    end
    line = line .. left_char .. string.rep('-', num) .. right_char .. '|'
  end
  return line
end

local function cells_to_table(cells, max_cells_width)
  local lines = {}
  for i = 1, #cells do
    local line = '|'
    if i == 2 then
      line = format_separator_line(cells[i], max_cells_width)
    else
      for j = 1, #cells[i] do
        line = line .. format_cell(cells[i][j], max_cells_width[j]) .. '|'
      end
    end
    table.insert(lines, line)
  end
  return lines
end

local function add_new_col(table_infos)
  if #table_infos.current_table == 1 then
    table.insert(table_infos.current_table, '|')
  end

  if #table_infos.cells == 1 or #table_infos.cells[2] < #table_infos.cells[1] then
    table_infos.current_table[2] = table_infos.current_table[2] .. '--|'
    for i = 3, #table_infos.current_table do
      table_infos.current_table[i] = table_infos.current_table[i] .. '  |'
    end
  end

  api.nvim_buf_set_lines(
    0,
    table_infos.table_start_line_number - 1,
    table_infos.table_end_line_number,
    true,
    table_infos.current_table
  )
end

local function format_markdown_table()
  if not check_line_is_table(fn.line('.')) then
    return
  end
  local table_infos = get_table_infos()
  local lines = cells_to_table(table_infos.cells, table_infos.max_cells_width)
  api.nvim_buf_set_lines(
    0,
    table_infos.table_start_line_number - 1,
    table_infos.table_end_line_number,
    true,
    lines
  )
end

local function format_markdown_table_lines()
  local current_line = api.nvim_get_current_line()
  local cursor_pos = api.nvim_win_get_cursor(0)
  current_line = add_char_inline(current_line, '|', cursor_pos[2])
  api.nvim_buf_set_lines(0, cursor_pos[1] - 1, cursor_pos[1], true, { current_line })

  if check_line_is_table(fn.line('.')) then
    local table_infos = get_table_infos()
    if cursor_pos[1] == table_infos.table_start_line_number then
      add_new_col(table_infos)
    end
    format_markdown_table()
  end

  local length = string.len(api.nvim_get_current_line())
  api.nvim_win_set_cursor(0, { cursor_pos[1], length })
end

local function init()
  local acid = nil
  if opt.options.insert_leave then
    acid = api.nvim_create_autocmd('InsertLeave', {
      group = group,
      pattern = opt.filetype,
      callback = function()
        format_markdown_table()
      end,
    })
  end
  if opt.options.insert then
    vim.keymap.set('i', '|', function()
      format_markdown_table_lines()
    end, {})
  end
  return acid
end

local function final(acid)
  if opt.options.insert_leave and acid then
    api.nvim_del_autocmd(acid)
  end
  if opt.options.insert then
    vim.keymap.del('i', '|', {})
  end
end

local function setup(opts)
  opt = vim.tbl_deep_extend('force', opt, opts or {})
  local acid = nil
  api.nvim_create_user_command('Mtm', function()
    mtm_startup = not mtm_startup
    vim.notify('Markdown table mode ' .. (mtm_startup and 'on' or 'off'))
    if mtm_startup then
      acid = init()
    else
      final(acid)
    end
  end, {})
  api.nvim_create_autocmd('BufEnter', {
    pattern = opt.filetype,
    callback = function()
      if mtm_startup then
        acid = init()
      end
    end,
  })
  api.nvim_create_autocmd('BufLeave', {
    pattern = opt.filetype,
    callback = function()
      if mtm_startup then
        final(acid)
      end
    end,
  })
end

return { setup = setup }
