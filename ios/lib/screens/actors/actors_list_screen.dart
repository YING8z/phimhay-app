import 'package:flutter/material.dart';
import 'package:phimhay_app/config/app_config.dart';
import 'package:phimhay_app/config/theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'dart:convert';

class ActorsListScreen extends StatefulWidget {
  const ActorsListScreen({super.key});

  @override
  State<ActorsListScreen> createState() => _ActorsListScreenState();
}

class _ActorsListScreenState extends State<ActorsListScreen> {
  final Dio _dio = Dio();
  List<dynamic> _actors = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchActors();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchActors() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res = await _dio.get('${AppConfig.apiUrl}/actor.php', queryParameters: {'list': '1'});
      final data = res.data is String ? jsonDecode(res.data) : res.data;
      if (data['success'] == true) {
        setState(() {
          _actors = data['actors'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() { _error = 'Không thể tải danh sách diễn viên'; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Lỗi kết nối'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _searchQuery.isEmpty
        ? _actors
        : _actors.where((a) {
            final name = (a['name'] ?? a['name_vi'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery.toLowerCase());
          }).toList();

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Diễn viên', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Tìm diễn viên...',
                hintStyle: TextStyle(color: AppTheme.textMuted),
                prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textMuted, size: 20),
                filled: true,
                fillColor: AppTheme.bgCard,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
                : _error != null
                    ? Center(child: Text(_error!, style: TextStyle(color: AppTheme.textMuted)))
                    : filtered.isEmpty
                        ? const Center(child: Text('Không tìm thấy diễn viên', style: TextStyle(color: AppTheme.textMuted)))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: filtered.length,
                            itemBuilder: (ctx, i) {
                              final actor = filtered[i];
                              final name = actor['name_vi'] ?? actor['name'] ?? '';
                              final photo = actor['photo_url'] ?? '';
                              final tmdbId = actor['tmdb_id'];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                                leading: ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: photo,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(width: 48, height: 48, color: AppTheme.bgCard),
                                    errorWidget: (_, __, ___) => Container(
                                      width: 48, height: 48, color: AppTheme.bgCard,
                                      child: Icon(Icons.person, color: AppTheme.textMuted),
                                    ),
                                  ),
                                ),
                                title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                                subtitle: Text(actor['name'] ?? '', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                                onTap: () {
                                  // TODO: navigate to actor detail
                                },
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
