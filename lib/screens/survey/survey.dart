import 'dart:convert';
import 'package:field_survey/screens/survey/SurveyFormPage.dart';
import 'package:field_survey/screens/survey/survey_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:field_survey/routes/app_routes.dart';
import 'package:field_survey/screens/auth/login.dart';

class SurveyPage extends StatefulWidget {
  const SurveyPage({super.key});
  @override
  State<SurveyPage> createState() => _SurveyPageState();
}

class _SurveyPageState extends State<SurveyPage> {
  // THEME BURGUNDY
  static const primaryColor = Color(0xFF800020);
  static const darkBurgundy = Color(0xFF4A0E12);
  static const lightBurgundy = Color(0xFFFDF2F4);
  static const backgroundColor = Color(0xFFFFF4F5);
  static const borderColor = Color(0xFFE8D0D5);
  static const textColor = Color(0xFF2D1215);
  static const greyColor = Color(0xFF8A6A6D);
  static const errorColor = Color(0xFFC62828);

  List<Map<String, dynamic>> surveys = [];
  bool isLoading = true;
  String? errorMessage;
  final String apiUrl = 'https://sijala.biz.id/api/v1/surveys';

  @override
  void initState() {
    super.initState();
    fetchSurveys();
  }

  Future<void> fetchSurveys() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) {
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
        return;
      }
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 401) {
        await prefs.remove('token');
        await prefs.remove('user');
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
        return;
      }
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['status'] == true && data['data'] is List) {
          final List<dynamic> listData = data['data'];
          if (!mounted) return;
          setState(() {
            surveys = listData
                .map<Map<String, dynamic>>(
                  (item) => Map<String, dynamic>.from(item),
                )
                .toList();
            isLoading = false;
          });
          return;
        }
        if (!mounted) return;
        setState(() {
          surveys = [];
          isLoading = false;
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = 'Gagal mengambil data survey.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = 'Tidak dapat terhubung ke server. Periksa koneksi Anda.';
      });
    }
  }

  Future<void> openSurveyDetail(Map<String, dynamic> survey) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SurveyDetailPage(surveyId: survey['id']),
      ),
    );
    if (result == true && mounted) fetchSurveys();
  }

  Future<void> openSurveyForm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SurveyFormPage()),
    );
    if (result == true && mounted) fetchSurveys();
  }

  String getSurveyCategory(Map<String, dynamic> survey) {
    if (survey['category'] != null && survey['category'].toString().isNotEmpty)
      return survey['category'].toString();
    if (survey['survey'] is Map && survey['survey']['category'] != null)
      return survey['survey']['category'].toString();
    return 'Tipe Survey';
  }

  String formatDate(dynamic date) {
    if (date == null || date.toString().isEmpty) return '-';
    try {
      final parsed = DateTime.parse(date.toString());
      return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
    } catch (e) {
      return date.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          tooltip: 'Kembali ke Dashboard',
          onPressed: () => context.go(AppRoutes.dashboard),
        ),
        title: const Text(
          'Survey',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        color: primaryColor,
        backgroundColor: Colors.white,
        onRefresh: fetchSurveys,
        child: _buildBody(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: openSurveyForm,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add),
        label: const Text(
          'Tambah Survey',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 220),
          Center(child: CircularProgressIndicator(color: primaryColor)),
          SizedBox(height: 14),
          Center(
            child: Text(
              'Memuat data survey...',
              style: TextStyle(color: greyColor, fontSize: 13),
            ),
          ),
        ],
      );
    }
    if (errorMessage != null) return _buildErrorState();
    if (surveys.isEmpty) return _buildEmptyState();
    return _buildSurveyList();
  }

  Widget _buildSurveyList() {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: surveys.length,
      itemBuilder: (context, index) {
        final survey = surveys[index];
        final String title =
            survey['title']?.toString() ??
            survey['name']?.toString() ??
            'Survey';
        final String description = survey['description']?.toString() ?? '';
        final String category = getSurveyCategory(survey);
        final String date = formatDate(
          survey['created_at'] ?? survey['createdAt'],
        );
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: InkWell(
            onTap: () => openSurveyDetail(survey),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: lightBurgundy,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.assignment_outlined,
                          color: primaryColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: darkBurgundy,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: greyColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: lightBurgundy,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    child: Text(
                      category,
                      style: const TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Divider(height: 1, color: Colors.grey.shade200),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: lightBurgundy,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Icon(
                          Icons.calendar_today_outlined,
                          size: 13,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Dibuat pada',
                        style: TextStyle(fontSize: 11, color: greyColor),
                      ),
                      const Spacer(),
                      Text(
                        date,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 120),
        Center(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: lightBurgundy,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor),
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              size: 40,
              color: primaryColor,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'Gagal Memuat Data',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: darkBurgundy,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          errorMessage ?? 'Terjadi kesalahan.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: greyColor, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 10),
        const Text(
          'Tarik layar ke bawah untuk mencoba kembali.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: primaryColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 90),
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: lightBurgundy,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor),
            ),
            child: const Icon(
              Icons.assignment_outlined,
              size: 44,
              color: primaryColor,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'Belum Ada Data Survey',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: darkBurgundy,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Belum ada survey yang tersedia saat ini. Silakan tambahkan survey baru.',
          textAlign: TextAlign.center,
          style: TextStyle(color: greyColor, fontSize: 12.5, height: 1.4),
        ),
        const SizedBox(height: 20),
        Center(
          child: ElevatedButton.icon(
            onPressed: openSurveyForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text(
              'Tambah Survey',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
