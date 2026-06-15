import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:phimhay_app/config/theme.dart';

class Header extends StatefulWidget {
  final VoidCallback? onSearchTap;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onAccountTap;
  final VoidCallback? onWatchPartyTap;

  const Header({
    super.key,
    this.onSearchTap,
    this.onNotificationTap,
    this.onAccountTap,
    this.onWatchPartyTap,
  });

  @override
  State<Header> createState() => _HeaderState();
}

class _HeaderState extends State<Header> {
  double _topPadding = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _topPadding = MediaQuery.of(context).padding.top;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: _topPadding),
      decoration: const BoxDecoration(
        color: Color(0xEB0D0F14),
        border: Border(
          bottom: BorderSide(color: Color(0x1AFFFFFF), width: 0.5),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/logo2.png',
                    height: 28,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Text('Xiao Phim', style: TextStyle(color: AppTheme.gold, fontSize: 22, fontWeight: FontWeight.bold)),
                  ),
                  const Spacer(),
                  _HeaderIcon(
                    icon: Icons.search,
                    onTap: widget.onSearchTap ?? () {},
                  ),
                  const SizedBox(width: 4),
                  _HeaderIcon(
                    icon: Icons.people_outline,
                    onTap: widget.onWatchPartyTap ?? () {},
                  ),
                  const SizedBox(width: 4),
                  _HeaderIcon(
                    icon: Icons.notifications_outlined,
                    onTap: widget.onNotificationTap ?? () {},
                  ),
                  const SizedBox(width: 4),
                  _HeaderIcon(
                    icon: Icons.person_outline,
                    onTap: widget.onAccountTap ?? () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: AppTheme.textPrimary, size: 22),
        ),
      ),
    );
  }
}
