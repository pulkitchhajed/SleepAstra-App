import re
import os

file_path = r'c:\flutter\lib\modules\sleep_analysis\screens\sleep_analysis_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace hardcoded dark theme colors with isLight conditionals where appropriate.

# 1. Colors that need Theme.of(ctx) context
replacements = [
    (r'color:\s*const Color\(0xFF151728\)', r'color: Theme.of(context).brightness == Brightness.light ? AppTheme.surfaceLight : const Color(0xFF151728)'),
    (r'backgroundColor:\s*const Color\(0xFF050510\)', r'backgroundColor: Theme.of(context).brightness == Brightness.light ? AppTheme.backgroundLight : const Color(0xFF050510)'),
    (r'backgroundColor:\s*AppTheme\.surfaceElevated', r'backgroundColor: Theme.of(context).brightness == Brightness.light ? AppTheme.surfaceLight : AppTheme.surfaceElevated'),
    (r'backgroundColor:\s*AppTheme\.surface,', r'backgroundColor: Theme.of(context).brightness == Brightness.light ? AppTheme.surfaceLight : AppTheme.surface,'),
    (r'(?<!\? )AppTheme\.surfaceElevated(?![a-zA-Z])', r'(Theme.of(context).brightness == Brightness.light ? AppTheme.surfaceLight : AppTheme.surfaceElevated)'),
    (r'(?<!\? )AppTheme\.textPrimary(?![a-zA-Z])', r'(Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : AppTheme.textPrimary)'),
    (r'(?<!\? )AppTheme\.textSecondary(?![a-zA-Z])', r'(Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary)'),
    (r'(?<!\? )AppTheme\.cardBorder(?![a-zA-Z])', r'(Theme.of(context).brightness == Brightness.light ? AppTheme.cardBorderLight : AppTheme.cardBorder)'),
]

# We must be careful not to replace things that are ALREADY using isLight.
# Because I'm using negative lookbehinds `(?<!\? )` it should skip `isLight ? AppTheme.textPrimary`.
# However, things like `color: AppTheme.textPrimary` will be matched.

new_content = content
for pattern, repl in replacements:
    new_content = re.sub(pattern, repl, new_content)

# Special cases:
# Lines 1611, 1735, 1804: color: Colors.white
new_content = re.sub(r'color:\s*Colors\.white,', r'color: Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : Colors.white,', new_content)

# Line 1622: color: Colors.white.withValues(alpha: 0.55)
new_content = new_content.replace('color: Colors.white.withValues(alpha: 0.55)', 'color: Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : Colors.white.withValues(alpha: 0.55)')

# Line 1668: foregroundColor: Colors.white70
new_content = new_content.replace('foregroundColor: Colors.white70', 'foregroundColor: Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : Colors.white70')

# Line 1670: color: Colors.white.withValues(alpha: 0.25)
new_content = new_content.replace('color: Colors.white.withValues(alpha: 0.25)', 'color: Theme.of(context).brightness == Brightness.light ? AppTheme.cardBorderLight : Colors.white.withValues(alpha: 0.25)')

# Line 1152: color: _wakeUpProgress > 0.5 ? Colors.white : AppTheme.textPrimary
new_content = new_content.replace('color: _wakeUpProgress > 0.5 ? Colors.white : AppTheme.textPrimary', 'color: _wakeUpProgress > 0.5 ? Colors.white : (Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : AppTheme.textPrimary)')

# Fix _buildRecordingView missing AppTheme.background
new_content = new_content.replace(
'''  Widget _buildRecordingView(SleepAnalysisProvider provider) {
    return Scaffold(
      backgroundColor: AppTheme.background,''',
'''  Widget _buildRecordingView(SleepAnalysisProvider provider) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Scaffold(
      backgroundColor: isLight ? AppTheme.backgroundLight : AppTheme.background,'''
)

# Fix _buildAnalysingView missing AppTheme.background
new_content = new_content.replace(
'''  Widget _buildAnalysingView() {
    return Scaffold(
      backgroundColor: AppTheme.background,''',
'''  Widget _buildAnalysingView() {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Scaffold(
      backgroundColor: isLight ? AppTheme.backgroundLight : AppTheme.background,'''
)


with open(file_path, 'w', encoding='utf-8') as f:
    f.write(new_content)

print("Done")
