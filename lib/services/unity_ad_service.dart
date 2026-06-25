import 'dart:async';
import 'dart:io';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

class UnityAdService {
  static bool _initialized = false;
  static bool _adReady = false;
  static bool _initializing = false;

  static String get _gameId => Platform.isAndroid ? '6141441' : '6141440';
  static String get _placementId => Platform.isAndroid ? 'Interstitial_Android' : 'Interstitial_IOS';

  static bool get isReady => _adReady;

  static Future<void> init() async {
    if (_initialized || _initializing) return;
    _initializing = true;

    print('[UnityAds] ========================================');
    print('[UnityAds] Initializing...');
    print('[UnityAds] Platform: ${Platform.operatingSystem}');
    print('[UnityAds] Game ID: $_gameId');
    print('[UnityAds] Placement ID: $_placementId');
    print('[UnityAds] Test Mode: true');

    try {
      await UnityAds.init(
        gameId: _gameId,
        testMode: true,
        onComplete: () {
          _initialized = true;
          _initializing = false;
          print('[UnityAds] Init SUCCESS');
          _loadAd();
        },
        onFailed: (error, message) {
          _initializing = false;
          print('[UnityAds] Init FAILED: $error');
          print('[UnityAds] Error message: $message');
        },
      );
    } catch (e) {
      _initializing = false;
      print('[UnityAds] Init EXCEPTION: $e');
    }
  }

  static void _loadAd() {
    print('[UnityAds] Loading ad for placement: $_placementId');

    try {
      UnityAds.load(
        placementId: _placementId,
        onComplete: (placementId) {
          _adReady = true;
          print('[UnityAds] Ad LOAD SUCCESS: $placementId');
        },
        onFailed: (placementId, error, message) {
          _adReady = false;
          print('[UnityAds] Ad LOAD FAILED: $error');
          print('[UnityAds] Placement: $placementId');
          print('[UnityAds] Message: $message');
        },
      );
    } catch (e) {
      print('[UnityAds] Ad LOAD EXCEPTION: $e');
    }
  }

  /// Show interstitial ad
  static void showAd({required Function onDone}) {
    print('[UnityAds] showAd called, initialized=$_initialized, ready=$_adReady');

    if (!_initialized) {
      print('[UnityAds] Not initialized yet, initializing...');
      init().then((_) {
        print('[UnityAds] Init done, waiting for ad...');
        _showWithWait(onDone: onDone);
      });
      return;
    }

    if (_adReady) {
      print('[UnityAds] Ad ready, showing...');
      _showAd(onDone: onDone);
      return;
    }

    print('[UnityAds] Ad not ready, loading and waiting...');
    _showWithWait(onDone: onDone);
  }

  static void _showWithWait({required Function onDone}) {
    _loadAd();

    int waited = 0;
    const maxWait = 8;
    print('[UnityAds] Waiting up to ${maxWait}s for ad to load...');

    Timer.periodic(const Duration(seconds: 1), (timer) {
      waited++;
      print('[UnityAds] Wait ${waited}/${maxWait}s - ready=$_adReady');

      if (_adReady || waited >= maxWait) {
        timer.cancel();
        if (_adReady) {
          print('[UnityAds] Ad ready after ${waited}s, showing...');
          _showAd(onDone: onDone);
        } else {
          print('[UnityAds] Ad NOT ready after ${maxWait}s, skipping ad');
          onDone();
        }
      }
    });
  }

  static void _showAd({required Function onDone}) {
    print('[UnityAds] Calling showVideoAd for: $_placementId');

    try {
      UnityAds.showVideoAd(
        placementId: _placementId,
        onStart: (placementId) {
          print('[UnityAds] Ad STARTED: $placementId');
        },
        onComplete: (placementId) {
          print('[UnityAds] Ad COMPLETED: $placementId');
          _adReady = false;
          _loadAd();
          onDone();
        },
        onSkipped: (placementId) {
          print('[UnityAds] Ad SKIPPED: $placementId');
          _adReady = false;
          _loadAd();
          onDone();
        },
        onFailed: (placementId, error, message) {
          print('[UnityAds] Ad SHOW FAILED: $error');
          print('[UnityAds] Placement: $placementId');
          print('[UnityAds] Message: $message');
          _adReady = false;
          _loadAd();
          onDone();
        },
      );
    } catch (e) {
      print('[UnityAds] Ad SHOW EXCEPTION: $e');
      onDone();
    }
  }
}
