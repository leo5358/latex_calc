#!/usr/bin/env python3

import sys
import re
from sympy import sympify, simplify, latex, Matrix, Symbol
from sympy.parsing.latex import parse_latex

# 用於暫存提取出來的矩陣物件
matrix_store = {}

def parse_matrix_content(content):
    """
    手動解析矩陣內容：
    1. 用 '\\' 分割列
    2. 用 '&' 分割行
    3. 對每個單元格遞迴呼叫 parse_latex
    """
    rows = []
    # 分割列，並過濾空字串
    raw_rows = [r for r in re.split(r'\\\\', content) if r.strip()]
    
    for raw_row in raw_rows:
        cols = []
        raw_cols = raw_row.split('&')
        for raw_col in raw_cols:
            cell_text = raw_col.strip()
            if not cell_text:
                # 處理空單元格，預設為 0
                cols.append(sympify(0))
            else:
                try:
                    # 遞迴解析單元格內容 (例如矩陣裡有 \frac{1}{2})
                    cols.append(parse_latex(cell_text))
                except:
                    # 備援：如果 parse_latex 失敗，嘗試 sympify
                    cols.append(sympify(cell_text))
        rows.append(cols)
    return Matrix(rows)

def preprocess_matrices(expr_str):
    """
    使用正則表達式找出所有矩陣環境，
    將其轉換為 Matrix 物件存入 matrix_store，
    並在原字串中替換為占位符號 __MAT_X__
    """
    env_pattern = r'\\begin\{(pmatrix|bmatrix|Bmatrix|vmatrix|Vmatrix|matrix)\}(.*?)\\end\{\1\}'
    
    def replacer(match):
        content = match.group(2)
        mat_obj = parse_matrix_content(content)
        
        key = f"__MAT_{len(matrix_store)}__"
        matrix_store[key] = mat_obj
        return key

    new_str = re.sub(env_pattern, replacer, expr_str, flags=re.DOTALL | re.IGNORECASE)
    return new_str

def latex_to_result(latex_expr):
    try:
        global matrix_store
        matrix_store = {} # 清空暫存
        
        # 1. 預處理：移除前後空白與 $
        expr_str = latex_expr.strip().strip('$')
        
        # 2. 預處理矩陣：把 \begin{pmatrix}... 換成 __MAT_0__
        #    這樣 parse_latex 就不會看到它看不懂的 '&' 符號
        processed_str = preprocess_matrices(expr_str)
        
        # 3. 解析剩餘的數學算式 (例如 __MAT_0__ + __MAT_1__)
        try:
            expr = parse_latex(processed_str)
        except Exception:
            # 如果 parse_latex 還是失敗 (例如缺 antlr4)，嘗試用簡單替換
            simple = processed_str.replace('{', '(').replace('}', ')')
            expr = sympify(simple)

        # 4. 將矩陣物件塞回表達式中
        #    使用 subs 將 Symbol('__MAT_0__') 替換為實際的 Matrix 物件
        if matrix_store:
            # 建立替換字典：{Symbol('__MAT_0__'): Matrix(...), ...}
            subs_dict = {Symbol(k): v for k, v in matrix_store.items()}
            expr = expr.subs(subs_dict)

        # 5. 強制執行運算 (矩陣乘法、反矩陣、微積分等)
        if hasattr(expr, 'doit'):
            expr = expr.doit()
            
        # 6. 化簡並輸出
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
