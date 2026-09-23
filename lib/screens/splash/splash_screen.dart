import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:field_survey/routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;

      // ===================================================
      // SETELAH SPLASH → LOGIN
      // ===================================================

      context.go(AppRoutes.login);
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF7B1E3A);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),

      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,

            children: [
              // =================================================
              // LOGO
              // =================================================
              Container(
                padding: const EdgeInsets.all(25),

                decoration: BoxDecoration(
                  color: primaryColor,

                  shape: BoxShape.circle,

                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 15,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),

                child: const Icon(
                  Icons.assignment_outlined,
                  color: Colors.white,
                  size: 70,
                ),
              ),

              const SizedBox(height: 30),

              // =================================================
              // TITLE
              // =================================================
              const Text(
                'FIELD SURVEY',

                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                  letterSpacing: 1,
                ),
              ),

              const SizedBox(height: 10),

              // =================================================
              // SUBTITLE
              // =================================================
              const Text(
                'Survey lebih mudah dan cepat',

                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),

              const SizedBox(height: 40),

              // =================================================
              // LOADING
              // =================================================
              const SizedBox(
                width: 35,
                height: 35,

                child: CircularProgressIndicator(
                  color: primaryColor,
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
