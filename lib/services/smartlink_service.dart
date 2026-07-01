import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SmartlinkService {
  static const String _smartlinkUrl = 'https://omg10.com/4/11224550';

  static Future<void> openSmartlink() async {
    try {
      final uri = Uri.parse(_smartlinkUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('[Smartlink] Error opening: $e');
    }
  }

  static void showSmartlinkBeforeAction(BuildContext context, {VoidCallback? onDone}) {
    _showSmartlinkDialog(context, onDone: onDone);
  }

  static void _showSmartlinkDialog(BuildContext context, {VoidCallback? onDone}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Ưu đãi đặc biệt',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Xem ngay ưu đãi hot!',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDone?.call();
            },
            child: const Text('Bỏ qua', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF5921E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await openSmartlink();
              onDone?.call();
            },
            child: const Text('Xem ngay'),
          ),
        ],
      ),
    ).then((_) {
      // Dialog dismissed without button tap
    });
  }
}
