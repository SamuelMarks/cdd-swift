import os
import re

decl_pattern = re.compile(r'^\s*(?:public\s+|internal\s+|fileprivate\s+|private\s+)?(?:final\s+)?(?:class|struct|enum|protocol|func)\s+[A-Za-z0-9_]+')

for root, _, files in os.walk('Sources'):
    for file in files:
        if not file.endswith('.swift'):
            continue
        filepath = os.path.join(root, file)
        with open(filepath, 'r', encoding='utf-8') as f:
            lines = f.readlines()

        for i, line in enumerate(lines):
            if decl_pattern.search(line):
                j = i - 1
                is_documented = False
                while j >= 0:
                    prev_line = lines[j].strip()
                    if not prev_line or prev_line.startswith('@'):
                        j -= 1
                        continue
                    if prev_line.startswith('///') or prev_line.endswith('*/'):
                        is_documented = True
                    break
                if not is_documented:
                    print(f"{filepath}:{i+1}:{line.strip()}")
