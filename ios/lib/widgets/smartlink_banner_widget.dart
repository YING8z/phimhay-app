import 'package:flutter/material.dart';
import 'package:phimhay_app/services/smartlink_service.dart';

class SmartLinkBannerWidget extends StatefulWidget {
  const SmartLinkBannerWidget({super.key});

  @override
  State<SmartLinkBannerWidget> createState() => _SmartLinkBannerWidgetState();
}

class _SmartLinkBannerWidgetState extends State<SmartLinkBannerWidget> {
  bool _clicked = false;
  bool _hidden = false;
  DateTime? _hiddenUntil;

  void _onTap() {
    if (_hidden) return;
    SmartLinkService.openSmartLink(context);
    setState(() {
      _clicked = true;
      _hidden = true;
      _hiddenUntil = DateTime.now().add(const Duration(seconds: 180));
    });
    Future.delayed(const Duration(seconds: 180), () {
      if (mounted) {
        setState(() {
          _hidden = false;
          _clicked = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();
    return GestureDetector(
      onTap: _onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.amber.shade700, Colors.orange.shade600],
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_offer, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(
              'Khám phá ưu đãi hôm nay →',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
