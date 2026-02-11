#!/usr/bin/env python3

import sys
import re
from sympy import sympify, simplify, latex
from sympy.parsing.latex import parse_latex

def latex_to_result(latex_expr):
    try:
        # 預處理：移除 $ 符號與多餘空白
        expr_str = latex_expr.strip().strip('$').replace(' ', '')
        
        # 嘗試解析 LaTeX
        try:
            expr = parse_latex(expr_str)
        except:
            # 備援機制 (Fallback)：簡單移除 LaTeX 指令，將 {} 換成 ()
            simple = re.sub(r'\\[a-zA-Z]+', '', expr_str).replace('{', '(').replace('}', ')')
            expr = sympify(simple)
            
        # --- 核心修改開始 ---
        
        # 原本是 expr.evalf() -> 轉為浮點數
        # 改為 simplify(expr) -> 進行符號化簡運算 (保留分數、根號等精確形式)
        result = simplify(expr)
        
        # 使用 sympy.latex() 將結果轉回 LaTeX 格式字串
        # 例如: 2/3 會轉為 \frac{2}{3}
        return latex(result)
        
        # --- 核心修改結束 ---

    except Exception:
        # 發生錯誤時回傳空字串，避免干擾編輯器
        return ""

if __name__ == "__main__":
    if len(sys.argv) < 2: sys.exit(1)
    try:
        with open(sys.argv[1], 'r') as f:
            content = f.read()
        res = latex_to_result(content)
        if res:
            print(res, end='') # 重要：不要換行，直接輸出結果
    except:
        sys.exit(1)
