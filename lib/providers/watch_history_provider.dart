import 'package:flutter/foundation.dart';
import '../models/movie.dart';

class WatchHistoryProvider extends ChangeNotifier {
  Movie? _lastViewedMovie;

  Movie? get lastViewedMovie => _lastViewedMovie;

  void setLastViewed(Movie movie) {
    _lastViewedMovie = movie;
    notifyListeners();
  }

  void clear() {
    _lastViewedMovie = null;
    notifyListeners();
  }
}
