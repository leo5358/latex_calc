# latex-calc.nvim
A Neovim plugin to calculate LaTeX math expressions with ghost text support.

## Prerequisites
- `nvim-treesitter` (with `latex` parser)
- Python 3 with `sympy` and `antlr4-python3-runtime==4.11`

## Installation (Lazy.nvim)
```lua
{
  '你的使用者名稱/latex-calc.nvim',
  ft = 'tex',
  opts = {
    -- python_path = "指向你的 venv python",
  },
  config = function(_, opts)
    require('latex_calc').setup(opts)
  end
}
