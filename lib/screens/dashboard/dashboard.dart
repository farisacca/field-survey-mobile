import 'dart:convert';
import 'package:field_survey/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DashboardPage extends StatefulWidget {
  final String? token;
  const DashboardPage({super.key, this.token});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with WidgetsBindingObserver {
  // THEME BURGUNDY
  static const primary = Color(0xFF800020);
  static const darkBurgundy = Color(0xFF4A0E12);
  static const lightBurgundy = Color(0xFFFDF2F4);
  static const background = Color(0xFFFFF4F5);
  static const successColor = Color(0xFF2E7D32);
  static const errorColor = Color(0xFFC62828);

  static const String baseUrl = 'https://sijala.biz.id/api/v1';

  int _selectedIndex = 0;
  bool _isLoading = true;
  bool _isRequesting = false;
  bool _hasError = false;
  int _totalSurvey = 0;
  int _totalKategori = 0;
  String _userName = 'Pengguna';
  List<dynamic> _recentSurveys = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDynamicData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadDynamicData();
  }

  Future<void> _loadUserName(String token) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/profile'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return;
      final result = jsonDecode(response.body);
      dynamic user = result;
      if (result is Map && result['data'] != null) user = result['data'];
      if (user is Map && user['user'] is Map) user = user['user'];
      if (user is Map) {
        final name = user['name'] ?? user['nama'] ?? user['username'];
        if (name != null && name.toString().trim().isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_name', name.toString().trim());
          if (!mounted) return;
          setState(() => _userName = name.toString().trim());
        }
      }
    } catch (e) {
      debugPrint('Gagal profil: $e');
    }
  }

  List<dynamic> _parseSurveys(dynamic body) {
    if (body is List) return body;
    if (body is Map) {
      if (body['data'] is List) return body['data'] as List;
      if (body['data'] is Map && body['data']['data'] is List)
        return body['data']['data'] as List;
    }
    throw const FormatException('Format respons survei tidak sesuai');
  }

  int _countUniqueCategories(List<dynamic> surveys) {
    final Set<String> categories = {};
    for (final survey in surveys) {
      if (survey is! Map) continue;
      final categoryId = survey['category_id'];
      if (categoryId != null && categoryId.toString().trim().isNotEmpty) {
        categories.add(categoryId.toString());
        continue;
      }
      final category = survey['category'];
      if (category is Map && category['id'] != null)
        categories.add(category['id'].toString());
      else if (category is String && category.trim().isNotEmpty)
        categories.add(category.trim().toLowerCase());
    }
    return categories.length;
  }

  Future<void> _loadDynamicData() async {
    if (!mounted || _isRequesting) return;
    _isRequesting = true;
    setState(() {
      _isLoading = _totalSurvey == 0 && _recentSurveys.isEmpty && !_hasError;
      _hasError = false;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = widget.token ?? prefs.getString('token') ?? '';
      final savedName = prefs.getString('user_name');
      if (savedName != null && savedName.trim().isNotEmpty)
        _userName = savedName.trim();
      if (token.isEmpty) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
        return;
      }
      await _loadUserName(token);
      final surveyResponse = await http
          .get(
            Uri.parse('$baseUrl/surveys'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15));
      if (surveyResponse.statusCode != 200) throw Exception('Gagal survey');
      final surveys = _parseSurveys(jsonDecode(surveyResponse.body));
      if (!mounted) return;
      setState(() {
        _totalSurvey = surveys.length;
        _totalKategori = _countUniqueCategories(surveys);
        _recentSurveys = surveys.reversed.take(4).toList();
        _isLoading = false;
        _hasError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    } finally {
      _isRequesting = false;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshDashboard() async => await _loadDynamicData();

  Future<void> _openPage(String route) async {
    await context.push(route);
    if (!mounted) return;
    setState(() => _selectedIndex = 0);
    await _loadDynamicData();
  }

  Future<void> _onBottomTap(int index) async {
    if (index == 0) {
      setState(() => _selectedIndex = 0);
      await _loadDynamicData();
    } else if (index == 1) {
      setState(() => _selectedIndex = 1);
      await _openPage(AppRoutes.survey);
    } else if (index == 2) {
      setState(() => _selectedIndex = 2);
      await context.push(AppRoutes.profil);
      if (!mounted) return;
      setState(() => _selectedIndex = 0);
      await _loadDynamicData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text(
          'Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshDashboard,
        color: primary,
        backgroundColor: Colors.white,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.all(20),
          children: [
            _buildWelcomeCard(),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ringkasan Data',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: darkBurgundy,
                  ),
                ),
                if (!_isLoading)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _hasError
                          ? errorColor.withOpacity(0.1)
                          : successColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _hasError ? 'Gagal memuat' : 'Data terbaru',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _hasError ? errorColor : successColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 25),
                child: Center(child: CircularProgressIndicator(color: primary)),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'Total Survei',
                      value: '$_totalSurvey',
                      subtitle: 'Data survei',
                      icon: Icons.assignment_outlined,
                      color: primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Kategori',
                      value: '$_totalKategori',
                      subtitle: 'Kategori aktif',
                      icon: Icons.category_outlined,
                      color: const Color(0xFF6D4C41),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 26),
            const Text(
              'Akses Cepat',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: darkBurgundy,
              ),
            ),
            const SizedBox(height: 12),

            // AKSES CEPAT BARU - GRID 2 KOLOM
            Row(
              children: [
                Expanded(
                  child: _buildQuickAccess(
                    icon: Icons.add_chart_rounded,
                    title: 'Mulai Survei',
                    subtitle: 'Kelola survei',
                    color: primary,
                    onTap: () => _openPage(AppRoutes.survey),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickAccess(
                    icon: Icons.person_outline_rounded,
                    title: 'Profil Saya',
                    subtitle: 'Info akun',
                    color: const Color(0xFF6D4C41),
                    onTap: () => _openPage(AppRoutes.profil),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 26),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Survei Terbaru',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: darkBurgundy,
                  ),
                ),
                TextButton(
                  onPressed: () => _openPage(AppRoutes.survey),
                  child: const Text(
                    'Lihat semua',
                    style: TextStyle(
                      color: primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (_hasError)
              _buildEmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'Data belum tersedia',
                subtitle: 'Tarik ke bawah untuk refresh',
              )
            else if (_recentSurveys.isEmpty && !_isLoading)
              _buildEmptyState(
                icon: Icons.assignment_outlined,
                title: 'Belum ada survei',
                subtitle: 'Data survei akan muncul di sini',
              )
            else
              ..._recentSurveys.map((survey) {
                final title = survey is Map
                    ? survey['title'] ?? survey['judul'] ?? 'Survei tanpa judul'
                    : 'Survei';
                final date = survey is Map
                    ? survey['created_at'] ?? 'Data survei'
                    : 'Data survei';
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: lightBurgundy,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.assignment_rounded,
                          color: primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title.toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              date.toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey,
                        size: 20,
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: primary,
        unselectedItemColor: Colors.grey.shade400,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
        onTap: _onBottomTap,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_rounded),
            label: 'Survey',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.25),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selamat Datang!',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  _userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Field Survey App',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: darkBurgundy,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: darkBurgundy,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // AKSES CEPAT MODEL BARU
  Widget _buildQuickAccess({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: darkBurgundy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}
