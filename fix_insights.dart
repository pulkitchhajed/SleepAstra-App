
import 'dart:io';

void main() {
  final file = File('lib/modules/ai/screens/insights_screen.dart');
  var content = file.readAsStringSync();
  
  content = content.replaceAll(
    'AppTheme.textPrimary',
    '(Theme.of(context).brightness == Brightness.light ? AppTheme.textPrimaryLight : AppTheme.textPrimary)'
  );
  content = content.replaceAll(
    'AppTheme.textSecondary',
    '(Theme.of(context).brightness == Brightness.light ? AppTheme.textSecondaryLight : AppTheme.textSecondary)'
  );
  content = content.replaceAll(
    'AppTheme.cardBorder',
    '(Theme.of(context).brightness == Brightness.light ? AppTheme.cardBorderLight : AppTheme.cardBorder)'
  );
  
  content = content.replaceAll(
    'Colors.white.withValues',
    '(Theme.of(context).brightness == Brightness.light ? Colors.black.withValues : Colors.white.withValues)'
  );
  content = content.replaceAll(
    'Colors.white10',
    '(Theme.of(context).brightness == Brightness.light ? Colors.black12 : Colors.white10)'
  );
  content = content.replaceAll(
    'Colors.white38',
    '(Theme.of(context).brightness == Brightness.light ? Colors.black38 : Colors.white38)'
  );
  content = content.replaceAll(
    'Colors.white',
    '(Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white)'
  );
  
  content = content.replaceAll(
    '(Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white).withValues',
    '(Theme.of(context).brightness == Brightness.light ? Colors.black.withValues : Colors.white.withValues)'
  );
  content = content.replaceAll(
    '(Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white)10',
    '(Theme.of(context).brightness == Brightness.light ? Colors.black12 : Colors.white10)'
  );
  content = content.replaceAll(
    '(Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white)38',
    '(Theme.of(context).brightness == Brightness.light ? Colors.black38 : Colors.white38)'
  );
  
  content = content.replaceAllMapped(
    RegExp(r'AppTheme\.glassDecoration\((.*?)\)'),
    (Match m) => 'AppTheme.glassDecoration(\, isLightMode: Theme.of(context).brightness == Brightness.light)'
  );

  file.writeAsStringSync(content);
}

