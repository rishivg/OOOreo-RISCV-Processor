import os
import re

search_dir = "work/src/hdl"

for root, dirs, files in os.walk(search_dir):
    for file in files:
        if file.endswith(".sv"):
            path = os.path.join(root, file)
            with open(path, 'r') as f:
                lines = f.readlines()
            
            new_lines = []
            includes = []
            
            for line in lines:
                # regex for import X::*; or import X::*; // comment
                m = re.match(r'^\s*import\s+(\w+)::\*(\s*);', line)
                if m:
                    pkg = m.group(1)
                    includes.append(f'`include "{pkg}.vh"\n')
                elif "parameter int subset_indices" in line and "backend_top.sv" in file:
                     new_lines.append("// " + line)
                elif "subset_indices[i]" in line and "backend_top.sv" in file:
                     new_lines.append(line.replace("subset_indices[i]", "(i==0 ? 0 : 4)"))
                else:
                    new_lines.append(line)
            
            # Prepend includes
            final_content = includes + new_lines
            
            with open(path, 'w') as f:
                f.writelines(final_content)
            
            if includes:
                print(f"Updated {file} with {len(includes)} includes")
