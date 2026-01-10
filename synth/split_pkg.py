import re
import os
import math

pkg_file = "../pkg/types.sv"
output_dir = "work/pkg_headers"

os.makedirs(output_dir, exist_ok=True)

with open(pkg_file, 'r') as f:
    content = f.read()

lines = content.splitlines()

current_package_name = None
current_package_lines = []

# Dictionary to store resolved parameter values
param_map = {}

def clog2(x):
    try:
        x = int(x)
        if x <= 0: return 0
        return int(math.ceil(math.log2(x)))
    except:
        return 0

for line in lines:
    m_start = re.match(r'^\s*package\s+(\w+);', line)
    if m_start:
        current_package_name = m_start.group(1)
        current_package_lines = []
        continue

    m_end = re.search(r'^\s*endpackage', line)
    
    if current_package_name:
        if m_end:
            filename = f"{current_package_name}.vh"
            guard = f"{current_package_name.upper()}_VH"
            with open(os.path.join(output_dir, filename), 'w') as out_f:
                out_f.write(f"`ifndef {guard}\n")
                out_f.write(f"`define {guard}\n")
                
                for l in current_package_lines:
                    # Replace import with include
                    l = re.sub(r'^\s*import\s+(\w+)::\*(\s*);', r'`include "\1.vh"', l)
                    
                    # Replace localparam with define
                    m_param = re.match(r'^\s*localparam\s+(?:unsigned\s+|logic\s+|int\s+)?(\w+)\s*(?:\[[^\]]+\])?\s*=\s*(.+);', l)
                    if m_param:
                         name = m_param.group(1)
                         original_val = m_param.group(2).strip()
                         
                         # Remove comments
                         val_clean = original_val
                         if '//' in val_clean:
                            val_clean = val_clean.split('//')[0].strip()
                        
                         # Try to resolve expression
                         val_expr = val_clean.replace('$clog2', 'clog2')
                         
                         # Replace recognized params with their values
                         for k, v in param_map.items():
                             pattern = r'\b' + re.escape(k) + r'\b'
                             val_expr = re.sub(pattern, str(v), val_expr)

                         resolved_val = val_clean 
                         try:
                             res = eval(val_expr, {"__builtins__": None, "clog2": clog2, "int": int})
                             resolved_val = str(res)
                             param_map[name] = res
                         except Exception as e:
                             pass

                         out_f.write(f"`define {name} {resolved_val}\n")
                    else:
                         out_f.write(l + '\n')

                out_f.write(f"`endif // {guard}\n")
            print(f"Created {filename}")
            current_package_name = None
            current_package_lines = []
        else:
            current_package_lines.append(line)
