import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:field_survey/routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<Offset> _slideAnimation;

  static const Color primaryColor = Color(0xFF800020); // Burgundy utama
  static const Color darkBurgundy = Color(0xFF4A0E12); // Burgundy tua
  static const Color lightBurgundy = Color(0xFFC67B7B); // Burgundy muda

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _scaleAnimation = Tween<double>(begin: 0.75, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      context.go(AppRoutes.login);
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFE9E9), Color(0xFFFFF5F5), Color(0xFFFFD6D6)],
          ),
        ),
        child: Stack(
          children: [
            // Dekorasi lingkaran atas
            Positioned(
              top: -100,
              right: -80,
              child: _decorationCircle(
                size: 260,
                color: Color(0xFFECB4B4).withOpacity(0.45),
              ),
            ),

            // Dekorasi lingkaran bawah
            Positioned(
              bottom: -120,
              left: -90,
              child: _decorationCircle(
                size: 300,
                color: Color(0xFFD18F8F).withOpacity(0.30),
              ),
            ),

            SafeArea(
              child: Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // LOGO
                          ScaleTransition(
                            scale: _scaleAnimation,
                            child: Container(
                              width: 145,
                              height: 145,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFB02A37),
                                    Color(0xFF800020),
                                    Color(0xFF4A0E12),
                                  ],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryColor.withOpacity(0.25),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                    offset: Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Container(
                                margin: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.65),
                                    width: 1.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.assignment_rounded,
                                  color: Colors.white,
                                  size: 68,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 35),

                          // JUDUL
                          const Text(
                            'FIELD SURVEY',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                              color: darkBurgundy,
                            ),
                          ),

                          const SizedBox(height: 10),

                          // GARIS DEKORASI
                          Container(
                            width: 65,
                            height: 4,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [lightBurgundy, primaryColor],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),

                          const SizedBox(height: 18),

                          // SUBTITLE
                          const Text(
                            'Survey lebih mudah dan cepat',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF7F5255),
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          const SizedBox(height: 45),

                          // LOADING
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: Color(0xFFF0D0D0)),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.06),
                                  blurRadius: 15,
                                  offset: Offset(0, 5),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 21,
                                  height: 21,
                                  child: CircularProgressIndicator(
                                    color: primaryColor,
                                    strokeWidth: 2.5,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Menyiapkan aplikasi...',
                                  style: TextStyle(
                                    color: darkBurgundy,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 55),

                          // FOOTER
                          const Text(
                            'FIELD SURVEY APP',
                            style: TextStyle(
                              color: Color(0xFFAE7D80),
                              fontSize: 11,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _decorationCircle({required double size, required Color color}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
