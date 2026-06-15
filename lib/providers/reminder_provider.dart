import 'package:flutter/foundation.dart';
import 'package:phimhay_app/services/api_client.dart';

class ReminderProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _reminders = [];
  bool _isLoading = false;
  bool _initialized = false;

  List<Map<String, dynamic>> get reminders => _reminders;
  bool get isLoading => _isLoading;

  bool hasReminderBySlug(String slug) {
    return _reminders.any((r) => r['slug'] == slug);
  }

  Future<void> fetchReminders() async {
    if (_isLoading) return;
    _isLoading = true;
    try {
      final res = await ApiClient.get(
        '/notifications.php',
        params: {'tab': 'all'},
      );
      if (res.data['success'] == true) {
        _reminders = (res.data['reminders'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ?? [];
      }
    } catch (_) {
      // ignore
    } finally {
      _isLoading = false;
      _initialized = true;
      notifyListeners();
    }
  }

  Future<bool> toggleReminder(
    int movieId,
    String movieSlug,
    String movieName,
    String thumbUrl,
  ) async {
    try {
      final res = await ApiClient.post(
        '/Reminder.php',
        data: {'movie_slug': movieSlug},
      );
      final data = res.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final action = data['action'] as String? ?? '';
        if (action == 'added') {
          _reminders.add({
            'movie_id': movieId,
            'slug': movieSlug,
            'name': movieName,
            'thumb_url': thumbUrl,
            'note': 'Nhắc khi có tập mới',
          });
        } else {
          _reminders.removeWhere((r) => r['slug'] == movieSlug);
        }
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }
}