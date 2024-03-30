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
        width[_] = math.max(width[_], vim.fn.strdisplaywidth(cell))
      end
    end
  end
  return width
end

local function update_cell_contents(table_contents, width)
  local function add_space(cell, num)
    cell = ' ' .. cell .. ' '
    cell = cell .. string.rep(' ', num)
    return cell
  end

  for i, cells in ipairs(table_contents) do
    if i == 2 then
      for j, _ in ipairs(cells) do
        table_contents[i][j] = string.rep('-', (width[j] + 2))
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
  local corner_char, corner_number = '|', #table_contents[1]
  for i = 1, #table_contents, 1 do
    local line = corner_char
    for j = 1, corner_number, 1 do
      line = line .. table_contents[i][j] .. corner_char
    end
    table_contents[i] = line
  end
  return table_contents
end

local function judge_markdown_table(table_contents)
  if #table_contents < 2 then
    return false
  end
  for i = 2, #table_contents, 1 do
    if #table_contents[i - 1] ~= #table_contents[i] then
      return false
    end
  end
  return true
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

  if judge_markdown_table(table_contents) then
    local width = markdon_table_cells_width_get(table_contents)
    table_contents = update_cell_contents(table_contents, width)
    table_contents = cells_to_table(table_contents)

    vim.api.nvim_buf_set_lines(0, table_start_line - 1, table_end_line, true, table_contents)
  end
end

vim.api.nvim_create_autocmd('InsertLeave', {
  callback = function()
    markdown_table_format()
  end
})
