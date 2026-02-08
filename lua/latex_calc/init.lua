local M = {}
local detector = require("latex_calc.detector")

-- 配置選項
M.config = {
    enabled = true,
    python_path = vim.fn.stdpath("config") .. "/lua/latex_calc/python/.venv/bin/python3",
    calc_script = vim.fn.stdpath("config") .. "/lua/latex_calc/python/calc.py",
    highlight_group = "Comment",
    trigger_key = "<Tab>",
}

-- 狀態管理
local state = {
    ns_id = vim.api.nvim_create_namespace("latex_calc"),
    current_result = nil,
    current_line = nil,
    current_col = nil,
}

-- 清除 Ghost Text
local function clear_ghost_text()
    local bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_clear_namespace(bufnr, state.ns_id, 0, -1)
    state.current_result = nil
    state.current_line = nil
    state.current_col = nil
end

-- 顯示 Ghost Text
local function show_ghost_text(line, col, text)
    clear_ghost_text()

    local bufnr = vim.api.nvim_get_current_buf()
    state.current_result = text
    state.current_line = line
    state.current_col = col

    vim.api.nvim_buf_set_extmark(bufnr, state.ns_id, line, col, {
        virt_text = { { " " .. text, M.config.highlight_group } },
        virt_text_pos = "overlay",
        hl_mode = "combine",
    })
end

-- 呼叫 Python 計算引擎
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

    local cmd = string.format(
        "%s %s %s",
        M.config.python_path,
        vim.fn.shellescape(M.config.calc_script),
        vim.fn.shellescape(temp_file)
    )

    local result = vim.fn.system(cmd)
    local err_code = vim.v.shell_error
    os.remove(temp_file)

    if err_code == 0 then
        result = result:gsub("%s+$", "")
        if result ~= "" then
            callback(result)
        end
    end
end

-- 解析當前行，尋找算式
local function parse_current_line()
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

    call_calculator(expr, function(result)
        show_ghost_text(row, col, result)
    end)
end

-- Tab 鍵處理邏輯：修改為返回字串而非直接操作 Buffer
local function handle_tab()
    if state.current_result then
        local result = state.current_result
        -- 這裡我們只回傳結果，清空 Ghost Text 則放在下一行執行
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

    -- 監聽文字變動與游標移動，觸發 Ghost Text 顯示
    vim.api.nvim_create_autocmd({ "TextChangedI", "CursorMovedI" }, {
        group = group,
        pattern = "*.tex",
        callback = function()
            vim.schedule(parse_current_line)
        end,
    })

    -- 離開插入模式時清除 Ghost Text
    vim.api.nvim_create_autocmd("InsertLeave", {
        group = group,
        pattern = "*.tex",
        callback = clear_ghost_text,
    })

    -- 確保每次開啟或進入 tex 檔案時，該 Buffer 都會被綁定按鍵
    vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = "tex",
        callback = function(args)
            vim.keymap.set("i", M.config.trigger_key, function()
                local result = handle_tab()
                if result then
                    -- 如果有結果，直接 return 字串讓 Neovim 插入
                    return result
                else
                    -- 否則執行正常 Tab（解決 blink.cmp 衝突的關鍵）
                    -- 這裡必須使用 api.nvim_replace_termcodes 確保回傳正確的鍵碼
                    return vim.api.nvim_replace_termcodes(M.config.trigger_key, true, true, true)
                end
            end, {
                buffer = args.buf, -- 綁定到觸發此事件的 Buffer
                expr = true,
                replace_keycodes = false,
                desc = "LaTeX Calc: Insert result or normal tab",
            })
        end,
    })
end

-- 初始化插件
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
