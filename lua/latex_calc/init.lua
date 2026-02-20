local M = {}
local detector = require("latex_calc.detector")

M.config = {
    enabled = true,
    python_path = vim.fn.stdpath("config") .. "/lua/latex_calc/python/.venv/bin/python3",
    calc_script = vim.fn.stdpath("config") .. "/lua/latex_calc/python/calc.py",
    highlight_group = "Comment",
    trigger_key = "<Tab>",
    debounce_ms = 250,
}

local state = {
    ns_id = vim.api.nvim_create_namespace("latex_calc"),
    current_result = nil,
    current_line = nil,
    current_col = nil,
    timer = nil,
}

local function clear_ghost_text()
    local bufnr = vim.api.nvim_get_current_buf()
    if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_clear_namespace(bufnr, state.ns_id, 0, -1)
    end
    state.current_result = nil
    state.current_line = nil
    state.current_col = nil
end

local function show_ghost_text(target_bufnr, line, col, text)
    if not text or text:match("^%s*$") then
        clear_ghost_text()
        return
    end

    if not vim.api.nvim_buf_is_valid(target_bufnr) then
        return
    end
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

    local cmd = { M.config.python_path, M.config.calc_script, temp_file }

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

local function parse_current_line()
    if not vim.api.nvim_buf_is_valid(0) then
        return
    end

    local bufnr = vim.api.nvim_get_current_buf()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1] - 1
    local col = cursor[2]

    if not detector.is_in_math_context(row, col) then
        clear_ghost_text()
        return
    end

    local current_line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
    local before_cursor_current = current_line:sub(1, col)

    if not before_cursor_current:match("=%s*$") then
        clear_ghost_text()
        return
    end

    local after_cursor = current_line:sub(col + 1)
    local trimmed = after_cursor:match("^%s*(.*)")

    if trimmed ~= "" then
        local is_closer = trimmed:sub(1, 1) == "}"
            or trimmed:sub(1, 1) == ")"
            or trimmed:sub(1, 1) == "]"
            or trimmed:sub(1, 1) == "$"
            or trimmed:sub(1, 1) == "%"
            or trimmed:sub(1, 2) == "\\\\"
            or trimmed:sub(1, 2) == "\\)"
            or trimmed:sub(1, 2) == "\\]"
            or trimmed:sub(1, 4) == "\\end"
        if not is_closer then
            clear_ghost_text()
            return
        end
    end

    local start_row, start_col = row, 0
    local use_treesitter = false

    local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "latex")
    if ok and parser then
        local tree = parser:parse()[1]
        if tree then
            local root = tree:root()
            local node = root:descendant_for_range(row, col, row, col)
            while node do
                local node_type = node:type()
                if
                    node_type == "displayed_equation"
                    or node_type == "inline_formula"
                    or node_type == "math_environment"
                    or node_type == "generic_environment"
                then
                    start_row, start_col = node:range()
                    use_treesitter = true
                    break
                end
                node = node:parent()
            end
        end
    end

    if not use_treesitter then
        start_row = math.max(0, row - 20)
    end

    local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, row + 1, false)
    if #lines == 0 then
        return
    end

    if start_row == row then
        lines[1] = lines[1]:sub(start_col + 1, col)
    else
        lines[#lines] = lines[#lines]:sub(1, col)
        lines[1] = lines[1]:sub(start_col + 1)
    end

    local text_before_cursor = table.concat(lines, "\n")

    -- [修正]: 貪婪匹配直到最後一個等號，完美支援 Lua 的多行字串
    local expr = text_before_cursor:match("^(.*)=%s*$")

    if not expr or expr == "" then
        expr = before_cursor_current:match("([^$%%]+)%s*=%s*$")
        if not expr or expr == "" then
            clear_ghost_text()
            return
        end
    end

    -- 清理環境標籤，避免 Python 解析錯誤
    expr = expr:match("^%s*(.-)%s*$") or expr
    local env_to_remove = { "equation%*?", "align%*?", "gather%*?", "math", "displaymath" }
    for _, env in ipairs(env_to_remove) do
        expr = expr:gsub("^\\begin%{" .. env .. "%}%s*", "")
    end
    expr = expr:gsub("^\\%[%s*", ""):gsub("^\\%(%s*", ""):gsub("^%$+%s*", "")

    call_calculator(expr, function(result)
        show_ghost_text(bufnr, row, col, result)
    end)
end

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

local function handle_tab()
    if state.current_result then
        local result = state.current_result
        local row = state.current_line
        local col = state.current_col

        vim.schedule(function()
            clear_ghost_text()
            local lines = vim.split(" " .. result, "\n", { plain = true })

            -- 強制將結果寫入當前 Buffer
            vim.api.nvim_buf_set_text(0, row, col, row, col, lines)

            -- 計算正確的游標落點，避免錯誤
            local cursor_row = row + #lines - 1
            local cursor_col = 0
            if #lines == 1 then
                cursor_col = col + #lines[1]
            else
                cursor_col = #lines[#lines]
            end
            vim.api.nvim_win_set_cursor(0, { cursor_row + 1, cursor_col })
        end)
        return true
    end
    return false
end

local function setup_autocmds()
    local group = vim.api.nvim_create_augroup("LatexCalc", { clear = true })
    vim.api.nvim_create_autocmd({ "TextChangedI", "CursorMovedI" }, {
        group = group,
        pattern = "*.tex",
        callback = trigger_calculation_debounced,
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
                if handle_tab() then
                    return ""
                end
                return vim.api.nvim_replace_termcodes(M.config.trigger_key, true, true, true)
            end, { buffer = args.buf, expr = true, replace_keycodes = false })
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
