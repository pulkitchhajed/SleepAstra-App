import re

file_path = r'c:\flutter\lib\modules\sleep_analysis\screens\sleep_analysis_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace 'const TextStyle(..., color: Theme.of' with 'TextStyle(..., color: Theme.of'
content = re.sub(r'const\s+TextStyle\(([^)]*Theme\.of)', r'TextStyle(\1', content)

# Replace 'const Text(..., style: TextStyle(..., Theme.of' with 'Text(..., style: TextStyle(..., Theme.of'
content = re.sub(r'const\s+Text\(([^)]*Theme\.of)', r'Text(\1', content)

# Replace 'const Icon(..., color: Theme.of' with 'Icon(..., color: Theme.of'
content = re.sub(r'const\s+Icon\(([^)]*Theme\.of)', r'Icon(\1', content)

# Replace 'const BoxDecoration(..., color: Theme.of'
content = re.sub(r'const\s+BoxDecoration\(([^)]*Theme\.of)', r'BoxDecoration(\1', content)

# Check for instances where 'const ' precedes something that contains 'Theme.of' inside its block
# Specifically look at the errors:
# sleep_analysis_screen.dart:1725: `const Text('Smart Alarm', style: TextStyle(..., color: Theme.of`
content = content.replace("const Text('Smart Alarm', style: TextStyle", "Text('Smart Alarm', style: TextStyle")

# sleep_analysis_screen.dart:1794: `style: const TextStyle(..., color: Theme.of`
content = content.replace("style: const TextStyle(fontSize: 40, color: Theme.of", "style: TextStyle(fontSize: 40, color: Theme.of")

# sleep_analysis_screen.dart:1830: `style: const TextStyle(color: (Theme.of`
content = content.replace("style: const TextStyle(color: (Theme.of", "style: TextStyle(color: (Theme.of")

# sleep_analysis_screen.dart:1831: `const Icon(Icons.play_circle_outline, color: (Theme.of`
content = content.replace("const Icon(Icons.play_circle_outline, color: (Theme.of", "Icon(Icons.play_circle_outline, color: (Theme.of")


with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Done")
