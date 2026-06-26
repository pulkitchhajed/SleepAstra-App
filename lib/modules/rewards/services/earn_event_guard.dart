/// Client-side idempotency guard to prevent duplicate earn events
/// within a single app session. This is a first-line defence before
/// Firestore's own sourceRefId uniqueness check.
class EarnEventGuard {
  static final EarnEventGuard _instance = EarnEventGuard._();
  factory EarnEventGuard() => _instance;
  EarnEventGuard._();

  final Set<String> _earnedThisSession = {};
  DateTime _sessionDate = DateTime.now();

  /// Returns true if this sourceRefId has NOT been earned yet this session.
  /// Marks it as earned and returns true on first call; returns false on duplicates.
  bool tryEarn(String sourceRefId) {
    _resetIfNewDay();
    if (_earnedThisSession.contains(sourceRefId)) return false;
    _earnedThisSession.add(sourceRefId);
    return true;
  }

  /// Check without marking.
  bool hasEarned(String sourceRefId) {
    _resetIfNewDay();
    return _earnedThisSession.contains(sourceRefId);
  }

  void _resetIfNewDay() {
    final today = DateTime.now();
    if (today.day != _sessionDate.day ||
        today.month != _sessionDate.month ||
        today.year != _sessionDate.year) {
      _earnedThisSession.clear();
      _sessionDate = today;
    }
  }

  void clear() {
    _earnedThisSession.clear();
    _sessionDate = DateTime.now();
  }
}
