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
  static const Color primary = Color(0xFF1976D2);
  static const Color lightBlue = Color(0xFFE3F0FF);
  static const Color background = Color(0xFFF5F9FF);

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
    if (state == AppLifecycleState.resumed) {
      _loadDynamicData();
    }
  }

  // MENGAMBIL NAMA PENGGUNA
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

      debugPrint('PROFILE STATUS: ${response.statusCode}');
      debugPrint('PROFILE BODY: ${response.body}');

      if (response.statusCode != 200) return;

      final result = jsonDecode(response.body);
      dynamic user = result;

      if (result is Map && result['data'] != null) {
        user = result['data'];
      }

      if (user is Map && user['user'] is Map) {
        user = user['user'];
      }

      if (user is Map) {
        final name = user['name'] ??
            user['nama'] ??
            user['nama_user'] ??
            user['nama_pengguna'] ??
            user['full_name'] ??
            user['username'];

        if (name != null && name.toString().trim().isNotEmpty) {
          final nameValue = name.toString().trim();

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_name', nameValue);

          if (!mounted) return;

          setState(() {
            _userName = nameValue;
          });
        }
      }
    } catch (e) {
      debugPrint('Gagal mengambil profil: $e');
    }
  }

  // MEMBACA DATA SURVEI DARI RESPONS API
  List<dynamic> _parseSurveys(dynamic body) {
    if (body is List) {
      return body;
    }

    if (body is Map) {
      if (body['data'] is List) {
        return body['data'] as List;
      }

      if (body['data'] is Map &&
          body['data']['data'] is List) {
        return body['data']['data'] as List;
      }
    }

    throw const FormatException(
      'Format respons survei tidak sesuai',
    );
  }

  // MENGHITUNG KATEGORI BERBEDA YANG DIGUNAKAN SURVEI
  int _countUniqueCategories(List<dynamic> surveys) {
    final Set<String> categories = {};

    for (final survey in surveys) {
      if (survey is! Map) continue;

      final categoryId = survey['category_id'];

      if (categoryId != null &&
          categoryId.toString().trim().isNotEmpty) {
        categories.add(categoryId.toString());
        continue;
      }

      final category = survey['category'];

      if (category is Map && category['id'] != null) {
        categories.add(category['id'].toString());
      } else if (category is Map &&
          category['name'] != null) {
        categories.add(
          category['name'].toString().trim().toLowerCase(),
        );
      } else if (category is String &&
          category.trim().isNotEmpty) {
        categories.add(category.trim().toLowerCase());
      }
    }

    return categories.length;
  }

  // MENGAMBIL DATA DASHBOARD
  Future<void> _loadDynamicData() async {
    if (!mounted || _isRequesting) return;

    _isRequesting = true;

    setState(() {
      _isLoading = _totalSurvey == 0 &&
          _recentSurveys.isEmpty &&
          !_hasError;
      _hasError = false;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      final token = widget.token ??
          prefs.getString('token') ??
          prefs.getString('access_token') ??
          '';

      
      final savedName = prefs.getString('user_name');

      if (savedName != null && savedName.trim().isNotEmpty) {
        _userName = savedName.trim();
      } else {
        final userJson = prefs.getString('user');

        if (userJson != null && userJson.isNotEmpty) {
          try {
            final user = jsonDecode(userJson);

            if (user is Map) {
              final name = user['name'] ??
                  user['nama'] ??
                  user['nama_user'] ??
                  user['nama_pengguna'] ??
                  user['username'];

              if (name != null &&
                  name.toString().trim().isNotEmpty) {
                _userName = name.toString().trim();
              }
            }
          } catch (e) {
            debugPrint('Gagal membaca data user: $e');
          }
        }
      }

      if (!mounted) return;

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

      debugPrint('SURVEY STATUS: ${surveyResponse.statusCode}');
      debugPrint('SURVEY BODY: ${surveyResponse.body}');

      if (surveyResponse.statusCode != 200) {
        throw Exception(
          'Gagal mengambil data survei: '
          '${surveyResponse.statusCode}',
        );
      }

      final surveyBody = jsonDecode(surveyResponse.body);
      final surveys = _parseSurveys(surveyBody);

    
      final totalKategori = _countUniqueCategories(surveys);

      if (!mounted) return;

      setState(() {
        _totalSurvey = surveys.length;
        _totalKategori = totalKategori;
        _recentSurveys = surveys.reversed.take(4).toList();
        _isLoading = false;
        _hasError = false;
      });
    } catch (e) {
      debugPrint('Gagal memuat dashboard: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    } finally {
      _isRequesting = false;

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshDashboard() async {
    await _loadDynamicData();
  }

  Future<void> _openPage(String route) async {
    await context.push(route);

    if (!mounted) return;

    setState(() {
      _selectedIndex = 0;
    });

    await _loadDynamicData();
  }

  Future<void> _onBottomTap(int index) async {
    if (index == 0) {
      setState(() {
        _selectedIndex = 0;
      });

      await _loadDynamicData();
    } else if (index == 1) {
      setState(() {
        _selectedIndex = 1;
      });

      await _openPage(AppRoutes.survey);
    } else if (index == 2) {
      setState(() {
        _selectedIndex = 2;
      });

      await context.push(AppRoutes.profil);

      if (!mounted) return;

      setState(() {
        _selectedIndex = 0;
      });

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
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshDashboard,
        color: primary,
        backgroundColor: Colors.white,
        displacement: 50,
        child: ListView(
          key: const PageStorageKey('dashboard_list'),
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.all(20),
          children: [
            _buildWelcomeCard(),

            const SizedBox(height: 26),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ringkasan Data',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!_isLoading)
                  Text(
                    _hasError ? 'Gagal memuat data' : 'Data terbaru',
                    style: TextStyle(
                      fontSize: 11,
                      color: _hasError ? Colors.red : Colors.green,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 15),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 25),
                child: Center(
                  child: CircularProgressIndicator(
                    color: primary,
                  ),
                ),
              )
            else ...[
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
                      title: 'Kategori Survei',
                      value: '$_totalKategori',
                      subtitle: 'Kategori ',
                      icon: Icons.category_outlined,
                      color: const Color(0xFF20A879),
                    ),
                  ),
                ],
              ),

              if (_hasError) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Sebagian data gagal dimuat. Periksa koneksi, '
                    'token login, dan alamat API.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ],

            const SizedBox(height: 28),

            const Text(
              'Akses Cepat',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 15),

            _buildActionCard(
              icon: Icons.add_chart_rounded,
              title: 'Mulai Survei',
              subtitle: 'Buka halaman pengelolaan survei',
              onTap: () => _openPage(AppRoutes.survey),
            ),

            const SizedBox(height: 12),

            _buildActionCard(
              icon: Icons.person_outline_rounded,
              title: 'Profil',
              subtitle: 'Lihat informasi akun',
              onTap: () => _openPage(AppRoutes.profil),
            ),

            const SizedBox(height: 28),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Survei Terbaru',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () => _openPage(AppRoutes.survey),
                  child: const Text(
                    'Lihat semua',
                    style: TextStyle(color: primary),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            if (_hasError)
              _buildEmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'Data belum tersedia',
                subtitle:
                    'Tarik layar ke bawah untuk mencoba kembali.',
              )
            else if (_recentSurveys.isEmpty && !_isLoading)
              _buildEmptyState(
                icon: Icons.assignment_outlined,
                title: 'Belum ada survei',
                subtitle: 'Data survei akan muncul di sini.',
              )
            else
              ..._recentSurveys.map((survey) {
                final title = survey is Map
                    ? survey['title'] ??
                        survey['judul'] ??
                        survey['nama_survey'] ??
                        survey['nama'] ??
                        'Survei tanpa judul'
                    : 'Survei';

                final date = survey is Map
                    ? survey['created_at'] ??
                        survey['tanggal'] ??
                        survey['tanggal_survey'] ??
                        'Data survei'
                    : 'Data survei';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: const Color(0xFFE2ECFA),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: lightBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.assignment_rounded,
                          color: primary,
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
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              date.toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey,
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
        unselectedItemColor: Colors.grey,
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
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1976D2),
            Color(0xFF64B5F6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.20),
            blurRadius: 18,
            offset: const Offset(0, 8),
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
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _userName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Aplikasi Field Survey',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white24,
            child: Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 38,
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 25,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            value,
            style: const TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: lightBlue,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: primary,
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: Colors.grey,
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 38,
            color: Colors.grey,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
