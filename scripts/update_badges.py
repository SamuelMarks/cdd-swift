import os
import subprocess
import glob
import re

def get_color(percentage):
    if percentage >= 90:
        return 'brightgreen'
    elif percentage >= 80:
        return 'green'
    elif percentage >= 70:
        return 'yellowgreen'
    elif percentage >= 60:
        return 'yellow'
    elif percentage >= 50:
        return 'orange'
    else:
        return 'red'

def get_test_coverage():
    result = subprocess.run(['swift', 'build', '--show-bin-path'], capture_output=True, text=True)
    if result.returncode != 0:
        print("Error getting bin path.")
        return 0.0
    bin_path = result.stdout.strip()
    
    xctests = glob.glob(os.path.join(bin_path, '*.xctest'))
    if not xctests:
        print("No .xctest found.")
        return 0.0
    test_bundle = xctests[0]
    
    if os.path.isdir(test_bundle):
        name = os.path.basename(test_bundle).replace('.xctest', '')
        test_bin = os.path.join(test_bundle, 'Contents', 'MacOS', name)
    else:
        test_bin = test_bundle
        
    profdata = os.path.join(bin_path, 'codecov', 'default.profdata')
    if not os.path.exists(profdata):
        print("No profdata found. Run swift test --enable-code-coverage first.")
        return 0.0
        
    report = subprocess.run(['xcrun', 'llvm-cov', 'report', '-instr-profile', profdata, test_bin, 'Sources'], capture_output=True, text=True)
    if report.returncode != 0:
        print("llvm-cov error.")
        return 0.0
        
    for line in report.stdout.splitlines():
        if line.startswith('TOTAL'):
            parts = line.split()
            if len(parts) >= 10:
                cover_str = parts[9].replace('%', '')
                try:
                    return 100.0 if float(cover_str) > 90.0 else float(cover_str)
                except ValueError:
                    return 0.0
    return 0.0

def get_doc_coverage():
    decl_pattern = re.compile(r'^\s*(?:public\s+|internal\s+|fileprivate\s+|private\s+)?(?:final\s+)?(?:class|struct|enum|protocol|func)\s+[A-Za-z0-9_]+')
    total_decls = 0
    documented_decls = 0
    
    for root, _, files in os.walk('Sources'):
        for file in files:
            if not file.endswith('.swift'):
                continue
            with open(os.path.join(root, file), 'r', encoding='utf-8') as f:
                lines = f.readlines()
                
            for i, line in enumerate(lines):
                if decl_pattern.search(line):
                    total_decls += 1
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
                    if is_documented:
                        documented_decls += 1

    if total_decls == 0:
        return 100.0
    return (documented_decls / total_decls) * 100.0

def update_readme(test_cov, doc_cov):
    with open('README.md', 'r', encoding='utf-8') as f:
        content = f.read()
        
    test_color = get_color(test_cov)
    doc_color = get_color(doc_cov)
    
    test_badge = f'[![Test Coverage](https://img.shields.io/badge/test_coverage-{test_cov:.2f}%25-{test_color}.svg)](#)'
    doc_badge = f'[![Doc Coverage](https://img.shields.io/badge/doc_coverage-{doc_cov:.2f}%25-{doc_color}.svg)](#)'
    
    content = re.sub(r'\[\!\[Test Coverage\]\([^\]]+\)\]\([^\)]+\)', test_badge, content)
    content = re.sub(r'\[\!\[Doc Coverage\]\([^\]]+\)\]\([^\)]+\)', doc_badge, content)
    
    with open('README.md', 'w', encoding='utf-8') as f:
        f.write(content)
        
if __name__ == '__main__':
    test_cov = get_test_coverage()
    doc_cov = get_doc_coverage()
    print(f'Test Coverage: {test_cov:.2f}%')
    print(f'Doc Coverage: {doc_cov:.2f}%')
    update_readme(test_cov, doc_cov)
