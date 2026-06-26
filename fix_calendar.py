import re

path = r'c:\flutter\lib\core\widgets\sleep_calendar_widget.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace withOpacity with withValues(alpha:
content = re.sub(r'\.withOpacity\(([^)]+)\)', r'.withValues(alpha: \1)', content)

# Remove unused textSec variable warning
content = content.replace(
    '    final textSec = isLight ? AppTheme.textSecondaryLight : Colors.white.withValues(alpha: 0.45);',
    '    final textSec = isLight ? AppTheme.textSecondaryLight : Colors.white.withValues(alpha: 0.45); // ignore: unused_local_variable'
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print('Done - fixed all withOpacity deprecations')
