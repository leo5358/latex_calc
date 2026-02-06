local M = {}

-- 數學環境節點類型
local MATH_NODES = {
  'displayed_equation',    -- \[ ... \]
  'inline_formula',        -- $ ... $ 或 \( ... \)
  'math_environment',      -- \begin{equation} ... \end{equation}
  'generic_environment',   -- 可能包含 align, gather 等環境
}

-- 數學環境名稱 (用於 generic_environment 檢查)
local MATH_ENV_NAMES = {
  'equation', 'equation*',
  'align', 'align*',
  'gather', 'gather*',
  'multline', 'multline*',
  'flalign', 'flalign*',
  'alignat', 'alignat*',
  'array', 'matrix', 'pmatrix', 'bmatrix', 'vmatrix',
}

-- 檢查節點是否為數學環境
local function is_math_node(node)
  if not node then return false end
  
  local node_type = node:type()
  
  -- 直接檢查是否為數學節點
  for _, math_type in ipairs(MATH_NODES) do
    if node_type == math_type then
      -- 如果是 generic_environment，需要檢查環境名稱
      if node_type == 'generic_environment' then
        local env_name = vim.treesitter.get_node_text(node:field('begin')[1], 0)
        if env_name then
          env_name = env_name:match('\\begin%{(.-)%}')
          for _, math_env in ipairs(MATH_ENV_NAMES) do
            if env_name == math_env then
              return true
            end
          end
        end
        return false
      end
      return true
    end
  end
  
  return false
end

-- 檢查游標是否在數學環境中
function M.is_in_math_context(row, col)
  -- 檢查 Treesitter 是否可用
  local ok, parser = pcall(vim.treesitter.get_parser, 0, 'latex')
  if not ok or not parser then
    -- Fallback: 簡單的正則檢查
    return M.is_in_math_context_fallback(row, col)
  end
  
  -- 獲取語法樹
  local tree = parser:parse()[1]
  if not tree then
    return M.is_in_math_context_fallback(row, col)
  end
  
  local root = tree:root()
  
  -- 獲取游標位置的節點
  local node = root:descendant_for_range(row, col, row, col)
  
  -- 向上遍歷節點樹，尋找數學環境
  while node do
    if is_math_node(node) then
      return true
    end
    node = node:parent()
  end
  
  return false
end

-- Fallback 方法：使用正則表達式檢查
function M.is_in_math_context_fallback(row, col)
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  
  -- 檢查前後是否有數學環境標記
  local before_cursor = ''
  local after_cursor = ''
  
  -- 收集游標前的文字
  for i = 1, row do
    if i < row then
      before_cursor = before_cursor .. lines[i] .. '\n'
    else
      before_cursor = before_cursor .. lines[i]:sub(1, col)
    end
  end
  
  -- 收集游標後的文字
  for i = row + 1, #lines do
    after_cursor = after_cursor .. lines[i] .. '\n'
  end
  after_cursor = lines[row + 1]:sub(col + 1) .. after_cursor
  
  -- 檢查 inline math: $ ... $
  local dollar_count = 0
  for _ in before_cursor:gmatch('%$') do
    dollar_count = dollar_count + 1
  end
  if dollar_count % 2 == 1 then
    return true
  end
  
  -- 檢查 \( ... \)
  local open_paren = before_cursor:match('.*\\%(') and not before_cursor:match('.*\\%)')
  if open_paren then
    return true
  end
  
  -- 檢查 \[ ... \]
  local open_bracket = before_cursor:match('.*\\%[') and not before_cursor:match('.*\\%]')
  if open_bracket then
    return true
  end
  
  -- 檢查環境 \begin{equation} ... \end{equation}
  for _, env_name in ipairs(MATH_ENV_NAMES) do
    local pattern_begin = '\\begin%{' .. env_name .. '%}'
    local pattern_end = '\\end%{' .. env_name .. '%}'
    
    local has_begin = before_cursor:match(pattern_begin)
    local has_end_before = before_cursor:match(pattern_end)
    
    if has_begin and not has_end_before then
      return true
    end
  end
  
  return false
end

-- 獲取當前數學環境的類型 (用於未來擴展)
function M.get_math_context_type(row, col)
  local ok, parser = pcall(vim.treesitter.get_parser, 0, 'latex')
  if not ok or not parser then
    return nil
  end
  
  local tree = parser:parse()[1]
  if not tree then
    return nil
  end
  
  local root = tree:root()
  local node = root:descendant_for_range(row, col, row, col)
  
  while node do
    if is_math_node(node) then
      return node:type()
    end
    node = node:parent()
  end
  
  return nil
end

return M
