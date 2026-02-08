# latex-calc.nvim

A powerful Neovim plugin that calculates LaTeX math expressions in real-time using **Ghost Text** (virtual text). It allows you to seamlessly insert the results into your document without leaving the editor.

Powered by Python's `SymPy` library for accurate symbolic and numerical calculations.

## Features

- **Real-time Preview**: Shows the calculation result as ghost text next to your equation.
- **Context Aware**: Only triggers within LaTeX math environments (e.g., `$ ... $`, `\[ ... \]`, `\begin{equation}`).
- **Smart Insertion**: Press `<Tab>` (configurable) to replace the ghost text with the actual result.
- **Complex Math Support**: Handles arithmetic, integrals, derivatives, and simplifications supported by SymPy.
- **Automatic Setup**: Includes an installation script to handle Python dependencies and virtual environments.

## ⚡ Prerequisites

Before installing, ensure you have the following:

- **Neovim >= 0.9**
- **Python 3.8+** (installed on your system)
- **nvim-treesitter** (with the `latex` parser installed)

## Installation

### Option 1: Install via Lazy.nvim (Recommended)

If you are installing directly from GitHub, `lazy.nvim` can run the installation script automatically.

```lua
{
  "leo5358/latex-calc.nvim",
  ft = "tex",
  build = "./install.sh", -- IMPORTANT: Runs the script to set up the Python venv
  opts = {
    -- Configuration options (see below)
    trigger_key = "<Tab>", 
  },
  config = function(_, opts)
    require("latex_calc").setup(opts)
  end,
}

```

### Option 2: Manual / Local Development

If you have cloned the repository locally or are developing it:

1. **Run the installation script** to set up the Python environment:
```bash
cd /path/to/latex-calc.nvim
chmod +x install.sh
./install.sh

```


2. **Configure Lazy.nvim** to point to your local directory:
```lua
{
  dir = "/path/to/latex-calc.nvim", -- Update this path
  name = "latex-calc.nvim",
  ft = "tex",
  opts = {
     enabled = true,
     -- Point to the venv created by install.sh
     python_path = "/path/to/latex-calc.nvim/lua/latex_calc/python/.venv/bin/python3",
     trigger_key = "<Tab>",
  },
  config = function(_, opts)
    require("latex_calc").setup(opts)
  end,
}

```



## ⚙️ Configuration

Pass these options to the `setup()` function or the `opts` table in Lazy.nvim:

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `enabled` | `boolean` | `true` | Enable/Disable the plugin on startup. |
| `trigger_key` | `string` | `"<Tab>"` | The key to insert the ghost text result into the buffer. |
| `highlight_group` | `string` | `"Comment"` | The highlight group used for the ghost text preview. |
| `python_path` | `string` | *(Auto-detected)* | Path to the Python executable. Defaults to the internal `.venv`. |

### Example Configuration

```lua
require("latex_calc").setup({
    enabled = true,
    trigger_key = "<C-e>", -- Change trigger to Ctrl+e
    highlight_group = "DiagnosticVirtualTextInfo", -- Change color
})

```

## Usage

1. Open a `.tex` file.
2. Enter a math environment (e.g., `$ ... $`).
3. Type a mathematical expression followed by `=`.
* Example: `$ 10 + 5 = $`


4. The result `15` will appear as ghost text.
5. Press `<Tab>` (or your configured `trigger_key`) to insert the result.

### Commands

* `:lua require("latex_calc").toggle()` - Enable or disable the plugin dynamically.
* `:lua require("latex_calc").calculate()` - Manually trigger a calculation for the current line.

## Troubleshooting

### Ghost text not showing?

1. Ensure you are inside a supported LaTeX math environment.
2. Check if `nvim-treesitter` has the latex parser installed: `:TSInstall latex`.
3. Verify that the Python environment was set up correctly.

### Python Errors?

The plugin relies on a virtual environment located at `lua/latex_calc/python/.venv`.
If you see errors related to `sympy` or imports:

1. Go to the plugin directory.
2. Re-run `./install.sh`.
3. If on **macOS**, ensure you have a valid Python installation (Homebrew recommended: `brew install python`). The script tries to avoid the system Xcode Python which often causes permission issues.