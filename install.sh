#!/bin/bash

# 設定 Neovim 配置目錄
NVIM_CONFIG_DIR="$HOME/.config/nvim"
TARGET_DIR="$NVIM_CONFIG_DIR/lua/latex_calc"

echo "=== 開始安裝 latex-calc.nvim ==="

# 檢查是否在專案根目錄執行
if [ ! -d "lua/latex_calc" ]; then
    echo "錯誤：找不到 lua/latex_calc 目錄。"
    echo "請確保您是在專案的根目錄下執行此腳本。"
    exit 1
fi

# --- [新增] 自動偵測最佳 Python 執行檔 ---
echo "[0/3] 偵測 Python 環境..."

# 優先尋找 Homebrew 的 Python (Apple Silicon & Intel)
if [ -f "/opt/homebrew/bin/python3" ]; then
    PYTHON_EXEC="/opt/homebrew/bin/python3"
elif [ -f "/usr/local/bin/python3" ]; then
    PYTHON_EXEC="/usr/local/bin/python3"
else
    # 最後才使用系統預設，並發出警告
    PYTHON_EXEC=$(which python3)
    echo "警告：未偵測到 Homebrew Python，將使用系統預設：$PYTHON_EXEC"
    echo "      如果安裝失敗，建議執行 'brew install python' 後重試。"
fi

echo "使用 Python: $PYTHON_EXEC"
# ----------------------------------------

# 1. 複製檔案
echo "[1/3] 正在複製檔案到 $TARGET_DIR ..."
mkdir -p "$TARGET_DIR"
cp -R lua/latex_calc/* "$TARGET_DIR/"

if [ $? -ne 0 ]; then
    echo "錯誤：檔案複製失敗。"
    exit 1
fi

# 2. 設定 Python 虛擬環境
PYTHON_SCRIPT_DIR="$TARGET_DIR/python"
VENV_DIR="$PYTHON_SCRIPT_DIR/.venv"

echo "[2/3] 正在建立 Python 虛擬環境..."

# 如果舊的 venv 存在且損壞，先刪除它
if [ -d "$VENV_DIR" ]; then
    echo "移除舊的虛擬環境..."
    rm -rf "$VENV_DIR"
fi

# 使用指定的 PYTHON_EXEC 建立 venv
"$PYTHON_EXEC" -m venv "$VENV_DIR"

if [ $? -ne 0 ]; then
    echo "錯誤：建立虛擬環境失敗。"
    exit 1
fi

# 3. 安裝 Python 依賴套件
echo "[3/3] 正在安裝 Python 依賴 (sympy, antlr4-python3-runtime)..."

# 確保使用 venv 裡的 pip
PIP_EXEC="$VENV_DIR/bin/pip"

# 再次確認 pip 是否存在 (如果上一步失敗，這裡會報錯)
if [ ! -f "$PIP_EXEC" ]; then
    echo "錯誤：虛擬環境中找不到 pip，可能是 venv 建立不完全。"
    exit 1
fi

"$PIP_EXEC" install --upgrade pip
"$PIP_EXEC" install sympy antlr4-python3-runtime==4.11

if [ $? -eq 0 ]; then
    echo ""
    echo "=== 安裝成功！ ==="
    echo "插件已安裝至：$TARGET_DIR"
    echo "Python 環境：$VENV_DIR"
    echo "使用直譯器：$PYTHON_EXEC"
    echo ""
    echo "請記得在您的 Neovim 設定中加入："
    echo "require('latex_calc').setup({})"
else
    echo "錯誤：Python 依賴安裝失敗。"
    exit 1
fi