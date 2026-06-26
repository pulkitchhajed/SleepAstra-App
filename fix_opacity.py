import os
import re

def fix_opacity(directory):
    pattern = re.compile(r'\.withOpacity\(([^)]+)\)')
    count = 0
    for root, _, files in os.walk(directory):
        for file in files:
            if file.endswith('.dart'):
                path = os.path.join(root, file)
                with open(path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                new_content, num_subs = pattern.subn(r'.withValues(alpha: \1)', content)
                if num_subs > 0:
                    with open(path, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    count += num_subs
    print(f'Replaced {count} occurrences of withOpacity.')

if __name__ == '__main__':
    fix_opacity(r'c:\flutter\lib')
