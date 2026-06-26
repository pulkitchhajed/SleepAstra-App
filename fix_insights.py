
import os
import re

file_path = r'c:\flutter\lib\modules\ai\screens\insights_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    'AppTheme.textPrimary',
    '(Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : AppTheme.textPrimary)'
)
content = content.replace(
    'AppTheme.textSecondary',
    '(Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary)'
)
content = content.replace(
    'AppTheme.cardBorder',
    '(Theme.of(context).brightness == Brightness.light ? AppTheme.cardBorderLight : AppTheme.cardBorder)'
)

content = content.replace(
    'Colors.white.withValues',
    '(Theme.of(context).brightness == Brightness.light ? Colors.black.withValues : Colors.white.withValues)'
)
content = content.replace(
    'Colors.white10',
    '(Theme.of(context).brightness == Brightness.light ? Colors.black12 : Colors.white10)'
)
content = content.replace(
    'Colors.white38',
    '(Theme.of(context).brightness == Brightness.light ? Colors.black38 : Colors.white38)'
)
content = content.replace(
    'Colors.white',
    '(Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white)'
)

content = content.replace(
    '(Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white).withValues',
    '(Theme.of(context).brightness == Brightness.light ? Colors.black.withValues : Colors.white.withValues)'
)
content = content.replace(
    '(Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white)10',
    '(Theme.of(context).brightness == Brightness.light ? Colors.black12 : Colors.white10)'
)
content = content.replace(
    '(Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white)38',
    '(Theme.of(context).brightness == Brightness.light ? Colors.black38 : Colors.white38)'
)

content = re.sub(
    r'AppTheme\.glassDecoration\((.*?)\)',
    r'AppTheme.glassDecoration(\g<1>, isLightMode: Theme.of(context).brightness == Brightness.light)',
    content
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

