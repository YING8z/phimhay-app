import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:media_kit/media_kit.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_client.dart';
import 'config/theme.dart';
import 'providers/home_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/favorite_provider.dart';
import 'providers/watch_history_provider.dart';
import 'providers/reminder_provider.dart';
import 'screens/home/home_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'services/push_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khóa portrait cho toàn app (chỉ mở trong watch screen)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Initialize media_kit for HLS playback
  MediaKit.ensureInitialized();

  // Initialize API client with persistent cookies
  await ApiClient.init();

  // Xóa image cache cũ 1 lần (fix ảnh poster_url/thumb_url sai)
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('cache_cleared_v2') != true) {
      await DefaultCacheManager().emptyCache();
      await prefs.setBool('cache_cleared_v2', true);
    }
  } catch (_) {}

  // Initialize Firebase for FCM
  await Firebase.initializeApp();

  // Initialize Push Service (không await để tránh treo splash screen trên iOS)
  PushService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FavoriteProvider()),
        ChangeNotifierProvider(create: (_) => WatchHistoryProvider()),
        ChangeNotifierProvider(create: (_) => ReminderProvider()),
      ],
      child: const XiaoPhimApp(),
    ),
  );
}

class XiaoPhimApp extends StatelessWidget {
  const XiaoPhimApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Xiao Phim',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: SplashScreen(child: const HomeScreen()),
    );
  }
}