import 'package:field_survey/screens/profile/profil.dart';
import 'package:field_survey/screens/survey/survey.dart';
import 'package:flutter/material.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF7B1E3A);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),

      // =====================================================
      // BODY
      // =====================================================

      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [

              // =================================================
              // HEADER
              // =================================================

              Container(
                width: double.infinity,

                padding: const EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  35,
                ),

                decoration: const BoxDecoration(
                  color: primaryColor,
                ),

                child: Column(
                  children: [

                    Row(
                      children: [

                        // FOTO PROFILE
                        const CircleAvatar(
                          radius: 28,

                          backgroundColor: Colors.white,

                          child: Icon(
                            Icons.person,
                            color: primaryColor,
                            size: 30,
                          ),
                        ),

                        const SizedBox(width: 15),

                        // NAMA
                        const Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,

                            children: [

                              Text(
                                "Welcome 👋",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 15,
                                ),
                              ),

                              SizedBox(height: 4),

                              Text(
                                "Farisa",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              SizedBox(height: 4),

                              Text(
                                "Survey Officer",
                                style: TextStyle(
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // NOTIFICATION
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius:
                                BorderRadius.circular(15),
                          ),

                          child: IconButton(
                            onPressed: () {},

                            icon: const Icon(
                              Icons.notifications_none,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    const Align(
                      alignment: Alignment.centerLeft,

                      child: Text(
                        "Wednesday, 29 July 2026",

                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // =================================================
              // TODAY'S SURVEY
              // =================================================

              Padding(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 20,
                ),

                child: Card(
                  elevation: 6,

                  shadowColor: Colors.black26,

                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(22),
                  ),

                  child: Padding(
                    padding:
                        const EdgeInsets.all(22),

                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,

                      children: [

                        const Row(
                          children: [

                            CircleAvatar(
                              radius: 20,

                              backgroundColor:
                                  Color(0xFFF7E7EB),

                              child: Icon(
                                Icons.assignment_outlined,
                                color: primaryColor,
                              ),
                            ),

                            SizedBox(width: 12),

                            Text(
                              "Today's Survey",

                              style: TextStyle(
                                fontSize: 18,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 25),

                        const Text(
                          "12 Survey Completed",

                          style: TextStyle(
                            fontSize: 26,
                            fontWeight:
                                FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),

                        const SizedBox(height: 20),

                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(20),

                          child:
                              const LinearProgressIndicator(
                            value: 0.85,
                            minHeight: 10,
                            color: primaryColor,
                            backgroundColor:
                                Color(0xFFE9D7DD),
                          ),
                        ),

                        const SizedBox(height: 10),

                        const Align(
                          alignment:
                              Alignment.centerRight,

                          child: Text(
                            "85%",

                            style: TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // =================================================
              // STATISTIK
              // =================================================

              Padding(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 20,
                ),

                child: Row(
                  children: [

                    Expanded(
                      child: statCard(
                        "Survey Hari Ini",
                        "12",
                        Icons.assignment_outlined,
                      ),
                    ),

                    const SizedBox(width: 15),

                    Expanded(
                      child: statCard(
                        "Total Survey",
                        "48",
                        Icons.analytics_outlined,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // =================================================
              // MENU UTAMA
              // =================================================

              const Padding(
                padding:
                    EdgeInsets.symmetric(
                  horizontal: 20,
                ),

                child: Align(
                  alignment: Alignment.centerLeft,

                  child: Text(
                    "Menu Utama",

                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              Padding(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 20,
                ),

                child: GridView.count(
                  shrinkWrap: true,

                  physics:
                      const NeverScrollableScrollPhysics(),

                  crossAxisCount: 3,

                  crossAxisSpacing: 15,

                  mainAxisSpacing: 15,

                  childAspectRatio: 0.9,

                  children: [

                    // SURVEY
                    menuCard(
                      context,
                      Icons.assignment_outlined,
                      "Survey",
                      const SurveyPage(),
                    ),

                    // LOKASI
                    menuCard(
                      context,
                      Icons.location_on_outlined,
                      "Lokasi",
                      null,
                    ),

                    // LAPORAN
                    menuCard(
                      context,
                      Icons.bar_chart_outlined,
                      "Laporan",
                      null,
                    ),

                    // PROFIL
                    menuCard(
                      context,
                      Icons.person_outline,
                      "Profil",
                      const ProfilePage(),
                    ),

                    // RIWAYAT
                    menuCard(
                      context,
                      Icons.history,
                      "Riwayat",
                      null,
                    ),

                  ],
                ),
              ),

              const SizedBox(height: 30),

              // =================================================
              // AKTIVITAS TERBARU
              // =================================================

              const Padding(
                padding:
                    EdgeInsets.symmetric(
                  horizontal: 20,
                ),

                child: Align(
                  alignment: Alignment.centerLeft,

                  child: Text(
                    "Aktivitas Terbaru",

                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              activityCard(
                Icons.check_circle,
                Colors.green,
                "Survey berhasil dikirim",
                "Hari ini • 09.30 WIB",
              ),

              activityCard(
                Icons.description_outlined,
                Colors.orange,
                "Laporan bulan Juli tersedia",
                "Hari ini • 13.00 WIB",
              ),

              const SizedBox(height: 25),
            ],
          ),
        ),
      ),

      // =====================================================
      // BOTTOM NAVIGATION
      // =====================================================

      bottomNavigationBar:
          BottomNavigationBar(
        currentIndex: 0,

        selectedItemColor:
            primaryColor,

        unselectedItemColor:
            Colors.grey,

        type:
            BottomNavigationBarType.fixed,

        elevation: 8,

        onTap: (index) {

          // ================= HOME =================

          if (index == 0) {
            return;
          }

          // ================= SURVEY =================

          if (index == 1) {
            Navigator.push(
              context,

              MaterialPageRoute(
                builder: (context) =>
                    const SurveyPage(),
              ),
            );
          }

          // ================= PROFIL =================

          if (index == 2) {
            Navigator.push(
              context,

              MaterialPageRoute(
                builder: (context) =>
                    const ProfilePage(),
              ),
            );
          }
        },

        items: const [

          BottomNavigationBarItem(
            icon: Icon(
              Icons.home_outlined,
            ),

            activeIcon: Icon(
              Icons.home,
            ),

            label: "Home",
          ),

          BottomNavigationBarItem(
            icon: Icon(
              Icons.assignment_outlined,
            ),

            activeIcon: Icon(
              Icons.assignment,
            ),

            label: "Survey",
          ),

          BottomNavigationBarItem(
            icon: Icon(
              Icons.person_outline,
            ),

            activeIcon: Icon(
              Icons.person,
            ),

            label: "Profil",
          ),
        ],
      ),
    );
  }
}

// =========================================================
// STAT CARD
// =========================================================

Widget statCard(
  String title,
  String value,
  IconData icon,
) {
  const Color primaryColor =
      Color(0xFF7B1E3A);

  return Card(
    elevation: 4,

    shadowColor: Colors.black12,

    shape: RoundedRectangleBorder(
      borderRadius:
          BorderRadius.circular(18),
    ),

    child: Padding(
      padding:
          const EdgeInsets.all(18),

      child: Column(
        children: [

          CircleAvatar(
            radius: 20,

            backgroundColor:
                const Color(0xFFF7E7EB),

            child: Icon(
              icon,
              color: primaryColor,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            value,

            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            title,

            textAlign:
                TextAlign.center,

            style: const TextStyle(
              color: Colors.grey,
              fontSize: 13,
            ),
          ),
        ],
      ),
    ),
  );
}

// =========================================================
// MENU CARD
// =========================================================

Widget menuCard(
  BuildContext context,
  IconData icon,
  String title,
  Widget? page,
) {
  const Color primaryColor =
      Color(0xFF7B1E3A);

  return Card(
    elevation: 4,

    shadowColor: Colors.black12,

    shape: RoundedRectangleBorder(
      borderRadius:
          BorderRadius.circular(18),
    ),

    child: InkWell(
      borderRadius:
          BorderRadius.circular(18),

      onTap: () {

        // Kalau belum ada halaman
        if (page == null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
            SnackBar(
              content: Text(
                "$title belum tersedia",
              ),
            ),
          );

          return;
        }

        Navigator.push(
          context,

          MaterialPageRoute(
            builder: (context) => page,
          ),
        );
      },

      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,

        children: [

          CircleAvatar(
            radius: 22,

            backgroundColor:
                const Color(0xFFF7E7EB),

            child: Icon(
              icon,
              color: primaryColor,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            title,

            style: const TextStyle(
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

// =========================================================
// ACTIVITY CARD
// =========================================================

Widget activityCard(
  IconData icon,
  Color color,
  String title,
  String subtitle,
) {
  return Card(
    margin:
        const EdgeInsets.symmetric(
      horizontal: 20,
      vertical: 6,
    ),

    elevation: 3,

    shadowColor:
        Colors.black12,

    shape:
        RoundedRectangleBorder(
      borderRadius:
          BorderRadius.circular(18),
    ),

    child: ListTile(
      leading: CircleAvatar(
        backgroundColor:
            color.withValues(
          alpha: 0.15,
        ),

        child: Icon(
          icon,
          color: color,
        ),
      ),

      title: Text(
        title,

        style: const TextStyle(
          fontWeight:
              FontWeight.w600,
        ),
      ),

      subtitle: Text(
        subtitle,
      ),

      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
      ),
    ),
  );
}