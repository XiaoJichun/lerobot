#!/usr/bin/env bash
#
# 生成 function.bash 函数库文档
#
# 用法: ./generate_docs.sh [输出文件]
# 参数:
#   输出文件: 输出文档路径（可选，默认: doc/function_library.md）
#
# 说明: 从 scripts/function.bash 解析函数注释并按类别生成 Markdown 文档

set -euo pipefail

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_DIR="$(dirname "$SCRIPT_DIR")"

# 默认输出文件
OUTPUT_FILE="${1:-${WS_DIR}/doc/function_library.md}"
FUNCTION_FILE="${SCRIPT_DIR}/function.bash"

# 检查源文件是否存在
if [[ ! -f "$FUNCTION_FILE" ]]; then
    echo "错误: 找不到源文件 $FUNCTION_FILE" >&2
    exit 1
fi

# 创建输出目录（如果不存在）
mkdir -p "$(dirname "$OUTPUT_FILE")"

# 创建临时 Python 脚本
PYTHON_SCRIPT=$(mktemp)
trap "rm -f $PYTHON_SCRIPT" EXIT

cat > "$PYTHON_SCRIPT" << 'PYEOF'
import re
import sys
from datetime import datetime

def parse_function_file(filepath):
    """解析 function.bash 文件，提取函数信息"""
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    functions = []
    current_category = None
    current_function = None
    current_doc = {}
    in_doc = False
    in_params = False
    in_env_vars = False
    in_examples = False
    in_notes = False
    
    i = 0
    while i < len(lines):
        line = lines[i].rstrip()
        
        # 检测类别标记
        category_match = re.match(r'^# --- (.+) ---$', line)
        if category_match:
            # 保存上一个函数
            if current_function and current_doc:
                functions.append({
                    'category': current_category,
                    'name': current_function,
                    **current_doc
                })
            
            current_category = category_match.group(1)
            current_function = None
            current_doc = {}
            in_doc = False
            i += 1
            continue
        
        # 检测功能描述
        func_match = re.match(r'^# 功能: (.+)$', line)
        if func_match:
            # 保存上一个函数
            if current_function and current_doc:
                functions.append({
                    'category': current_category,
                    'name': current_function,
                    **current_doc
                })
            
            current_function = None
            current_doc = {
                'description': func_match.group(1).strip(),
                'usage': '',
                'params': [],
                'returns': '',
                'env_vars': [],
                'examples': [],
                'notes': ''
            }
            in_doc = True
            in_params = False
            in_env_vars = False
            in_examples = False
            in_notes = False
            i += 1
            continue
        
        # 检测函数定义（必须在注释块内）
        if in_doc and not current_function:
            func_def_match = re.match(r'^([a-zA-Z_][a-zA-Z0-9_]*)\(\)', line)
            if func_def_match:
                current_function = func_def_match.group(1)
                i += 1
                continue
        
        if not in_doc:
            i += 1
            continue
        
        # 检测用法
        usage_match = re.match(r'^# 用法: (.+)$', line)
        if usage_match:
            current_doc['usage'] = usage_match.group(1).strip()
            in_params = False
            in_env_vars = False
            in_examples = False
            in_notes = False
            i += 1
            continue
        
        # 检测参数标题
        if re.match(r'^# 参数:$', line):
            in_params = True
            in_env_vars = False
            in_examples = False
            in_notes = False
            i += 1
            continue
        
        # 检测参数行
        if in_params:
            param_match = re.match(r'^#   ([^:]+): (.+)$', line)
            if param_match:
                current_doc['params'].append({
                    'name': param_match.group(1).strip(),
                    'desc': param_match.group(2).strip()
                })
            i += 1
            continue
        
        # 检测返回值
        returns_match = re.match(r'^# 返回: (.+)$', line)
        if returns_match:
            current_doc['returns'] = returns_match.group(1).strip()
            in_params = False
            in_env_vars = False
            in_examples = False
            in_notes = False
            i += 1
            continue
        
        # 检测环境变量标题
        if re.match(r'^# 环境变量:$', line):
            in_env_vars = True
            in_params = False
            in_examples = False
            in_notes = False
            i += 1
            continue
        
        # 检测环境变量
        if in_env_vars:
            env_match = re.match(r'^#   ([A-Z_]+): (.+)$', line)
            if env_match:
                current_doc['env_vars'].append({
                    'name': env_match.group(1).strip(),
                    'desc': env_match.group(2).strip()
                })
            else:
                env_list_match = re.match(r'^#     - (.+)$', line)
                if env_list_match:
                    if not current_doc['env_vars']:
                        current_doc['env_vars'].append({'name': '', 'desc': ''})
                    if current_doc['env_vars'][-1]['desc']:
                        current_doc['env_vars'][-1]['desc'] += ' ' + env_list_match.group(1).strip()
                    else:
                        current_doc['env_vars'][-1]['desc'] = env_list_match.group(1).strip()
            i += 1
            continue
        
        # 检测示例标题
        if re.match(r'^# 示例:$', line):
            in_examples = True
            in_params = False
            in_env_vars = False
            in_notes = False
            i += 1
            continue
        
        # 检测示例代码
        if in_examples:
            example_match = re.match(r'^#   (.+)$', line)
            if example_match:
                current_doc['examples'].append(example_match.group(1).strip())
            elif not line.strip().startswith('#'):
                in_examples = False
            i += 1
            continue
        
        # 检测注意
        notes_match = re.match(r'^# 注意: (.+)$', line)
        if notes_match:
            current_doc['notes'] = notes_match.group(1).strip()
            in_params = False
            in_env_vars = False
            in_examples = False
            in_notes = True
            i += 1
            continue
        
        if in_notes:
            notes_cont_match = re.match(r'^#    (.+)$', line)
            if notes_cont_match:
                current_doc['notes'] += ' ' + notes_cont_match.group(1).strip()
            i += 1
            continue
        
        i += 1
    
    # 保存最后一个函数
    if current_function and current_doc:
        functions.append({
            'category': current_category,
            'name': current_function,
            **current_doc
        })
    
    return functions

def generate_markdown(functions, output_file):
    """生成 Markdown 文档"""
    with open(output_file, 'w', encoding='utf-8') as f:
        # 写入头部
        f.write("# Function Library 函数库文档\n\n")
        f.write(f"本文档自动从 `scripts/function.bash` 生成，包含所有可用函数的详细说明。\n\n")
        f.write(f"**生成时间**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
        f.write("## 目录\n\n")
        
        # 生成目录
        categories = {}
        for func in functions:
            cat = func['category']
            if cat not in categories:
                categories[cat] = []
            categories[cat].append(func['name'])
        
        for cat in sorted(categories.keys()):
            cat_link = cat.lower().replace(' ', '-').replace('函数', '-函数')
            f.write(f"- [{cat}](#{cat_link})\n")
        
        f.write("\n---\n\n")
        
        # 按类别生成文档
        for cat in sorted(categories.keys()):
            f.write(f"## {cat}\n\n")
            
            # 该类别下的所有函数
            cat_functions = [f for f in functions if f['category'] == cat]
            
            for func in cat_functions:
                f.write(f"### {func['name']}\n\n")
                
                if func['description']:
                    f.write(f"{func['description']}\n\n")
                
                if func['usage']:
                    f.write("**用法**:\n\n")
                    f.write("```bash\n")
                    f.write(f"{func['usage']}\n")
                    f.write("```\n\n")
                
                if func['params']:
                    f.write("**参数**:\n\n")
                    f.write("| 参数 | 说明 |\n")
                    f.write("|------|------|\n")
                    for param in func['params']:
                        f.write(f"| `{param['name']}` | {param['desc']} |\n")
                    f.write("\n")
                
                if func['returns']:
                    f.write(f"**返回值**: {func['returns']}\n\n")
                
                if func['env_vars']:
                    f.write("**环境变量**:\n\n")
                    f.write("| 环境变量 | 说明 |\n")
                    f.write("|----------|------|\n")
                    for env in func['env_vars']:
                        if env['name']:
                            f.write(f"| `{env['name']}` | {env['desc']} |\n")
                        else:
                            f.write(f"| - | {env['desc']} |\n")
                    f.write("\n")
                
                if func['examples']:
                    f.write("**示例**:\n\n")
                    f.write("```bash\n")
                    for example in func['examples']:
                        f.write(f"{example}\n")
                    f.write("```\n\n")
                
                if func['notes']:
                    f.write(f"**注意**: {func['notes']}\n\n")
                
                f.write("---\n\n")
        
        # 写入尾部
        f.write("## 使用方法\n\n")
        f.write("在脚本中使用这些函数，需要先 source function.bash：\n\n")
        f.write("```bash\n")
        f.write('source "$(dirname "$0")/../scripts/function.bash"\n')
        f.write("```\n\n")
        f.write("或者使用工作空间路径：\n\n")
        f.write("```bash\n")
        f.write('source "${WS_DIR}/scripts/function.bash"\n')
        f.write("```\n\n")
        f.write("## 环境变量\n\n")
        f.write("所有函数都支持通过环境变量 `AUTO_CONFIRM` 统一控制交互式确认：\n\n")
        f.write("- `AUTO_CONFIRM=y` 或 `AUTO_CONFIRM=yes`: 所有确认自动选择\"是\"\n")
        f.write("- `AUTO_CONFIRM=n` 或 `AUTO_CONFIRM=no`: 所有确认自动选择\"否\"\n")
        f.write("- 未设置或空值: 正常交互式询问\n\n")
        f.write("---\n\n")
        f.write("*本文档由 scripts/generate_docs.sh 自动生成*\n")

# 主程序
if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("错误: 需要两个参数: function_file 和 output_file", file=sys.stderr)
        sys.exit(1)
    functions = parse_function_file(sys.argv[1])
    generate_markdown(functions, sys.argv[2])
    print(f"✅ 文档已生成: {sys.argv[2]}")
    print(f"📄 函数总数: {len(functions)}")
PYEOF

# 执行 Python 脚本
python3 "$PYTHON_SCRIPT" "$FUNCTION_FILE" "$OUTPUT_FILE"
