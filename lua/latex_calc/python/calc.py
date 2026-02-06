#!/usr/bin/env python3
import sys
import re
from sympy import sympify, nsimplify
from sympy.parsing.latex import parse_latex

def latex_to_result(latex_expr):
    try:
        # 預處理：移除 $ 符號與多餘空白
        expr_str = latex_expr.strip().strip('$').replace(' ', '')
        
        # 嘗試解析
        try:
            expr = parse_latex(expr_str)
        except:
            # 備援機制
            simple = re.sub(r'\\[a-zA-Z]+', '', expr_str).replace('{', '(').replace('}', ')')
            expr = sympify(simple)
            
        result = expr.evalf()
        
        # 格式化輸出：如果是整數就顯示整數
        if result.is_integer:
            return str(int(result))
        
        # 否則保留四位小數並移除末尾的 0
        return f"{float(result):.4f}".rstrip('0').rstrip('.')
    except:
        return ""

if __name__ == "__main__":
    if len(sys.argv) < 2: sys.exit(1)
    try:
        with open(sys.argv[1], 'r') as f:
            content = f.read()
        res = latex_to_result(content)
        if res:
            print(res, end='') # 重要：不要換行
    except:
        sys.exit(1)
