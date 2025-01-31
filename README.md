# markdown-table-mode.nvim
Formats markdown table under cursor when you leave insert mode or input `|`.

### Screenshot
![Screenshot](./Screenshot.gif)

### Install
**lazy.nvim**

```lua
{
  'Kicamon/markdown-table-mode.nvim',
  config = function()
    require('markdown-table-mode').setup()
  end
}
```

**vim-plug**

```vim script
Plug 'Kicamon/markdown-table-mode.nvim'
lua require('markdown-table-mode').setup()
```

### Usage
Run the `:Mtm` command to toggle markdown table mode.

### Configuration
default config
```lua
require('markdown-table-mode').setup({
  filetype = {
    '*.md',
  },
  options = {
    insert = true, -- when typing "|"
    insert_leave = true, -- when leaving insert
    pad_separator_line = false, -- add space in separator line
    alig_style = 'default', -- default, left, center, right
  },
})
```
