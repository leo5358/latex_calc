local M = {}
local detector = require("latex_calc.detector")

-- 配置選項
M.config = {
    enabled = true,
    python_path = vim.fn.stdpath("config") .. "/lua/latex_calc/python/.venv/bin/python3",
    calc_script = vim.fn.stdpath("config") .. "/lua/latex_calc/python/calc.py",
    highlight_group = "Comment",
    trigger_key = "<Tab>",
    debounce_ms = 250, -- 防抖動延遲
}

-- 狀態管理
local state = {
    ns_id = vim.api.nvim_create_namespace("latex_calc"),
    current_result = nil,
    current_line = nil,
    current_col = nil,
    timer = nil,
}

-- 清除 Ghost Text
local function clear_ghost_text()
    local bufnr = vim.api.nvim_get_current_buf()
    if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_clear_namespace(bufnr, state.ns_id, 0, -1)
    end
    state.current_result = nil
    state.current_line = nil
    state.current_col = nil
end

-- [Fix] 顯示 Ghost Text (包含安全檢查)
local function show_ghost_text(target_bufnr, line, col, text)
    -- 如果結果是空的，就不顯示
    if not text or text:match("^%s*$") then
        clear_ghost_text()
        return
    end

    -- 安全檢查 1: Buffer 是否還有效？
    if not vim.api.nvim_buf_is_valid(target_bufnr) then
        return
    end

    -- 安全檢查 2: 行數是否超出範圍？
    local line_count = vim.api.nvim_buf_line_count(target_bufnr)
    if line >= line_count then
        return
    end

    clear_ghost_text()

    state.current_result = text
    state.current_line = line
    state.current_col = col

    vim.api.nvim_buf_set_extmark(target_bufnr, state.ns_id, line, col, {
        virt_text = { { " " .. text, M.config.highlight_group } },
        virt_text_pos = "overlay",
        hl_mode = "combine",
    })
end

-- 非同步呼叫 Python 計算引擎
local function call_calculator(latex_expr, callback)
    if not M.config.enabled then
        return
    end

    local temp_file = vim.fn.tempname()
    local f = io.open(temp_file, "w")
    if not f then
        return
    end
    f:write(latex_expr)
    f:close()

    local cmd = {
        M.config.python_path,
        M.config.calc_script,
        temp_file,
    }

    vim.fn.jobstart(cmd, {
        stdout_buffered = true,
        on_stdout = function(_, data)
            if data then
                local result = table.concat(data, "")
                result = result:gsub("%s+$", "")
                vim.schedule(function()
                    callback(result)
                end)
            end
        end,
        on_exit = function()
            os.remove(temp_file)
        end,
    })
end

-- 解析當前行，尋找算式
local function parse_current_line()
    if not vim.api.nvim_buf_is_valid(0) then
        return
    end

    local bufnr = vim.api.nvim_get_current_buf()
    local line = vim.api.nvim_get_current_line()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1] - 1
    local col = cursor[2]

    if not detector.is_in_math_context(row, col) then
        clear_ghost_text()
        return
    end

    local before_cursor = line:sub(1, col)
    local expr = before_cursor:match("([^$%%]+)%s*=%s*$")

    if not expr or expr == "" then
        clear_ghost_text()
        return
    end

    -- [Feature] 檢查游標後方內容
    -- 防止在已經有結果時（例如 $ 1+1=2 $）回頭編輯等號觸發 ghost text
    local after_cursor = line:sub(col + 1)
    local trimmed = after_cursor:match("^%s*(.*)") -- 去除前導空白

    if trimmed ~= "" then
        -- 定義允許的「結尾字符」
        -- 意思是：如果游標後面是這些符號，代表這行算式已經結束，可以顯示計算結果。
        -- 如果不是這些符號（例如是數字 2 或變數 x），代表後面已經有東西了，則不顯示。
        local is_closer = trimmed:sub(1, 1) == "}"
            or trimmed:sub(1, 1) == ")"
            or trimmed:sub(1, 1) == "]"
            or trimmed:sub(1, 1) == "$"
            or trimmed:sub(1, 1) == "%" -- 允許後面跟著註解
            or trimmed:sub(1, 2) == "\\\\" -- 換行符號 \\
            or trimmed:sub(1, 2) == "\\)" -- Inline math 結尾
            or trimmed:sub(1, 2) == "\\]" -- Display math 結尾
            or trimmed:sub(1, 4) == "\\end" -- 環境結尾

        if not is_closer then
            clear_ghost_text()
            return
        end
    end

    call_calculator(expr, function(result)
        show_ghost_text(bufnr, row, col, result)
    end)
end

-- 防抖動觸發函數
local function trigger_calculation_debounced()
    if state.timer then
        state.timer:stop()
        if not state.timer:is_closing() then
            state.timer:close()
        end
    end

    state.timer = vim.loop.new_timer()

    state.timer:start(
        M.config.debounce_ms,
        0,
        vim.schedule_wrap(function()
            parse_current_line()
            if state.timer then
                state.timer:stop()
                if not state.timer:is_closing() then
                    state.timer:close()
                end
                state.timer = nil
            end
        end)
    )
end

-- Tab 鍵處理邏輯
local function handle_tab()
    if state.current_result then
        local result = state.current_result
        local text_to_insert = result
        vim.schedule(function()
            clear_ghost_text()
        end)
        return text_to_insert
    end
    return nil
end

-- 設定自動命令
local function setup_autocmds()
    local group = vim.api.nvim_create_augroup("LatexCalc", { clear = true })

    vim.api.nvim_create_autocmd({ "TextChangedI", "CursorMovedI" }, {
        group = group,
        pattern = "*.tex",
        callback = function()
            trigger_calculation_debounced()
        end,
    })

    vim.api.nvim_create_autocmd("InsertLeave", {
        group = group,
        pattern = "*.tex",
        callback = function()
            if state.timer then
                state.timer:stop()
                state.timer:close()
                state.timer = nil
            end
            clear_ghost_text()
        end,
    })

    vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = "tex",
        callback = function(args)
            vim.keymap.set("i", M.config.trigger_key, function()
                local result = handle_tab()
                if result then
                    return result
                else
                    return vim.api.nvim_replace_termcodes(M.config.trigger_key, true, true, true)
                end
            end, {
                buffer = args.buf,
                expr = true,
                replace_keycodes = false,
                desc = "LaTeX Calc: Insert result or normal tab",
            })
        end,
    })
end

function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})
    setup_autocmds()
end

function M.calculate()
    parse_current_line()
end

function M.toggle()
    M.config.enabled = not M.config.enabled
    if not M.config.enabled then
        clear_ghost_text()
    end
    vim.notify("LaTeX Calc " .. (M.config.enabled and "enabled" or "disabled"))
end

return M
