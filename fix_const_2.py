import re
file_path = r'c:\flutter\lib\modules\sleep_analysis\screens\sleep_analysis_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("colorScheme: const ColorScheme.dark(", "colorScheme: ColorScheme.dark(")

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
