import 'package:flutter/material.dart';
import 'package:phimhay_app/services/smartlink_service.dart';

class SmartLinkBannerWidget extends StatefulWidget {
  const SmartLinkBannerWidget({super.key});

  @override
  State<SmartLinkBannerWidget> createState() => _SmartLinkBannerWidgetState();
}

class _SmartLinkBannerWidgetState extends State<SmartLinkBannerWidget> {
  bool _hidden = false;

  void _onTap() {
    if (_hidden) return;
    SmartLinkService.openSmartLink(context);
    setState(() {
      _hidden = true;
    });
    Future.delayed(const Duration(seconds: 180), () {
      if (mounted) setState(() => _hidden = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();
    return GestureDetector(
      onTap: _onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.amber.shade700, Colors.orange.shade600]),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_offer, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Ưu đãi đặc biệt hôm nay',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 14),
          ],
        ),
      ),
    );
  }
}
