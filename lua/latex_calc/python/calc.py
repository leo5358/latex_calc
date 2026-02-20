#!/usr/bin/env python3

import sys
import re
from sympy import sympify, simplify, latex, Matrix
from sympy.parsing.latex import parse_latex

matrix_store = {}

def parse_matrix_content(content):
    rows = []
    raw_rows = [r for r in re.split(r'\\\\', content) if r.strip()]
    for raw_row in raw_rows:
        cols = []
        raw_cols = raw_row.split('&')
        for raw_col in raw_cols:
            cell_text = raw_col.strip()
            if not cell_text:
                cols.append(sympify(0))
            else:
                try:
                    cols.append(parse_latex(cell_text))
                except:
                    cols.append(sympify(cell_text))
        rows.append(cols)
    return Matrix(rows)

def latex_to_result(latex_expr):
    try:
        global matrix_store
        matrix_store = {}
        
        # 安全移除 LaTeX 註解
        expr_str = re.sub(r'(?<!\\)%.*', '', latex_expr)
        expr_str = expr_str.strip().strip('$')
        if not expr_str:
            return ""
        
        env_pattern = r'\\begin\{(pmatrix|bmatrix|Bmatrix|vmatrix|Vmatrix|matrix)\*?\}(.*?)\\end\{\1\*?\}'
        def replacer(match):
            content = match.group(2)
            mat_obj = parse_matrix_content(content)
            key = f"MATZ{len(matrix_store)}"
            matrix_store[key] = mat_obj
            return f" {key} "

        processed_str = re.sub(env_pattern, replacer, expr_str, flags=re.DOTALL | re.IGNORECASE)
        
        #  處理 align* 等多行環境：僅取最後一行
        if '\\\\' in processed_str:
            processed_str = processed_str.split('\\\\')[-1]
            
        processed_str = processed_str.replace('&', '').strip()
        
        processed_str = re.sub(r'\\begin\{(equation|align|gather|math|displaymath)\*?\}', '', processed_str).strip()
        
        if not processed_str:
            return ""
        
        #  自動補齊矩陣乘法符號
        while re.search(r'(MATZ\d+)\s+(MATZ\d+)', processed_str):
            processed_str = re.sub(r'(MATZ\d+)\s+(MATZ\d+)', r'\1 * \2', processed_str)

        local_dict = {k: v for k, v in matrix_store.items()}
        
        #  解析與計算
        try:
            if "MATZ" in processed_str:
                raise ValueError("Force sympify for matrices")
            expr = parse_latex(processed_str)
        except Exception:
            simple = processed_str.replace('{', '(').replace('}', ')')
            simple = simple.replace('\\times', '*').replace('\\cdot', '*')
            expr = sympify(simple, locals=local_dict)

        if hasattr(expr, 'doit'):
            expr = expr.doit()
            
        result = simplify(expr)
        return latex(result)

    except Exception:
        return ""

if __name__ == "__main__":
    if len(sys.argv) < 2: sys.exit(1)
    try:
        with open(sys.argv[1], 'r') as f:
            content = f.read()
        res = latex_to_result(content)
        if res:
            print(res, end='')
    except:
        sys.exit(1)
