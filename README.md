# markdown-table-mode.nvim
format markdown table under cursor when you leave insert mode or input `|`

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

### Configuration
defualt config
```lua
require('markdown-table-mode').setup({
    filetype = {
        '*.md'
    }
    options = {
        insert = true,
        insert_leave = true,
    }
})
```
