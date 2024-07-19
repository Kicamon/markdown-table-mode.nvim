local function check_markdonw_table(line_number)
  if not line_number then
    line_number = vim.fn.line('.')
  end
  local line = vim.api.nvim_buf_get_lines(0, line_number - 1, line_number, true)[1]
  return string.match(line, "^|.*|$")
end

local function fine_markdown_table(range)
  local cursor_line, end_line = vim.fn.line('.'), range == -1 and 1 or vim.fn.line('$')

  for l = cursor_line, end_line, range do
    if not check_markdonw_table(l) then
      return l - range
    end
    if (range == -1 and l == 1) or (range == 1 and l == vim.fn.line('$')) then
      return l
    end
  end
end

local function markdon_table_cells_width_get(table_contents)
  local width = {}
  for _ = 1, #table_contents[1], 1 do
    table.insert(width, 0)
  end
  for i = 1, #table_contents, 1 do
    if i ~= 2 then
      for _, cell in ipairs(table_contents[i]) do
        width[_] = math.max(width[_], cell and vim.fn.strdisplaywidth(cell) or 0)
      end
    end
  end
  return width
end

local table_line_char = {
  { ':', ':' },
  { ':', '-' },
  { '-', ':' },
}

local table_line_char_insert = {
  { ':', ':' },
  { ':', ' ' },
  { ' ', ':' },
}

local function update_cell_contents(table_contents, width)
  local function add_space(cell, num)
    cell = ' ' .. cell .. ' '
    cell = cell .. string.rep(' ', num)
    return cell
  end

  local function get_chars(cell)
    local char_left = string.sub(cell, 1, 1)
    local char_right = string.sub(cell, #cell)
    return { char_left, char_right }
  end

  local function get_table_line_char_id(chars)
    for i, v in ipairs(table_line_char) do
      if chars[1] == v[1] and chars[2] == v[2] then
        return i
      end
    end
    for i, v in ipairs(table_line_char_insert) do
      if chars[1] == v[1] and chars[2] == v[2] then
        return i
      end
    end
    return 0
  end

  local function add_chars(cell, chars)
    cell = chars[1] .. cell .. chars[2]
    return cell
  end

  for i, cells in ipairs(table_contents) do
    if i == 2 then
      for j, _ in ipairs(cells) do
        local chars          = get_chars(table_contents[i][j])
        local id             = get_table_line_char_id(chars)
        table_contents[i][j] = string.rep('-', width[j])
        table_contents[i][j] = add_chars(table_contents[i][j], id ~= 0 and table_line_char[id] or { '-', '-' })
      end
    else
      for j, cell in ipairs(cells) do
        local charnge_length = width[j] - vim.fn.strdisplaywidth(cell)
        table_contents[i][j] = add_space(cell, charnge_length)
      end
    end
  end

  return table_contents
end

local function cells_to_table(table_contents)
  local corner_char = '|'
  for i = 1, #table_contents, 1 do
    local line = corner_char
    for j = 1, #table_contents[i], 1 do
      line = line .. table_contents[i][j] .. corner_char
    end
    table_contents[i] = line
  end
  return table_contents
end

local function markdown_table_format()
  if not check_markdonw_table() then
    return
  end

  local table_start_line, table_end_line = fine_markdown_table(-1), fine_markdown_table(1)
  local table_contents = {}

  for lnum = table_start_line, table_end_line, 1 do
    local line = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, true)[1]
    local table_cells = {}
    for cell in line:gmatch("([^|]+)%|") do
      cell = cell:match("^%s*(.-)%s*$")
      table.insert(table_cells, cell)
    end
    table.insert(table_contents, table_cells)
  end

  local width = markdon_table_cells_width_get(table_contents)
  table_contents = update_cell_contents(table_contents, width)
  table_contents = cells_to_table(table_contents)

  vim.api.nvim_buf_set_lines(0, table_start_line - 1, table_end_line, true, table_contents)
end

local opt = {
  filetype = {
    '*.md',
  }
}

local function setup(opts)
  opt = vim.tbl_extend('force', opt, opts or {})
  vim.api.nvim_create_autocmd('InsertLeave', {
    pattern = opt.filetype,
    callback = function()
      markdown_table_format()
    end
  })
  vim.api.nvim_create_autocmd('TextChangedI', {
    pattern = opt.filetype,
    callback = function()
      local current_line = vim.api.nvim_get_current_line()
      local cursor_pos = vim.api.nvim_win_get_cursor(0)
      local char = current_line:sub(cursor_pos[2], cursor_pos[2])
      if char == '|' then
        markdown_table_format()
        local length = #vim.api.nvim_get_current_line()
        vim.api.nvim_win_set_cursor(0, { cursor_pos[1], length })
      end
    end
  })
end

return {
  setup = setup
}
