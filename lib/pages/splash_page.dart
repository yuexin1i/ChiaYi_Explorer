// lib/pages/splash_page.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_state.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';


class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _cloudController;
  late AnimationController _trainController;
  late AnimationController _floatController;
  late AnimationController _pulseController;
  late AnimationController _titleController;

  late Animation<double> _fadeAnim;
  late Animation<double> _titleFadeAnim;
  late Animation<Offset> _titleSlideAnim;
  late Animation<double> _subtitleFadeAnim;
  late Animation<double> _buttonsFadeAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _floatAnim;

  final String _youtubeUrl = 'https://youtu.be/dQw4w9WgXcQ?si=sHDeUkqLaLt2-fNL';

  // 🌟 存放載入好的去背人物圖片
  List<ui.Image?> _charImages = [];

  @override
  void initState() {
    super.initState();

    // 🌟 啟動時立刻載入人物圖片
    _loadCharacterImages();

    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _cloudController = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat();
    _trainController = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
    _floatController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))..repeat(reverse: true);
    _titleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _titleFadeAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _titleController, curve: const Interval(0.0, 0.45, curve: Curves.easeOut)));
    _titleSlideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _titleController, curve: const Interval(0.0, 0.45, curve: Curves.easeOut)));
    _subtitleFadeAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _titleController, curve: const Interval(0.3, 0.65, curve: Curves.easeOut)));
    _buttonsFadeAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _titleController, curve: const Interval(0.55, 1.0, curve: Curves.easeOut)));
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _floatAnim = Tween<double>(begin: -8, end: 8).animate(CurvedAnimation(parent: _floatController, curve: Curves.easeInOut));

    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 400), () => _titleController.forward());
  }

  // 🌟 載入去背圖片的邏輯
  Future<void> _loadCharacterImages() async {
    List<String> imagePaths = [
      'assets/char1.png',
      'assets/char2.png',
      'assets/char3.png',
      'assets/char4.png',
      'assets/char5.png',
      'assets/char6.png',
      'assets/char7.png',
    ];

    for (String path in imagePaths) {
      try {
        final ByteData data = await rootBundle.load(path);
        final ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final ui.FrameInfo fi = await codec.getNextFrame();
        if (mounted) {
          setState(() { _charImages.add(fi.image); });
        }
      } catch (e) {
        debugPrint('找不到圖片 $path');
        _charImages.add(null);
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _cloudController.dispose();
    _trainController.dispose();
    _floatController.dispose();
    _pulseController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _launchYoutube() async {
    final uri = Uri.parse(_youtubeUrl);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateManager>();
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2), Color(0xFFFFCC80), Color(0xFFFFAB91)],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [0.0, 0.4, 0.7, 1.0],
                ),
              ),
            ),
            Center(
              child: AnimatedBuilder(
                animation: _pulseAnim,
                builder: (context, child) => Transform.scale(
                  scale: _pulseAnim.value,
                  child: Container(
                    width: 320, height: 320,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [Colors.white.withOpacity(0.4), const Color(0xFFFFD54F).withOpacity(0.15), Colors.transparent],
                        stops: const [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: Listenable.merge([_cloudController, _trainController]),
              builder: (context, _) {
                return CustomPaint(
                  size: size,
                  painter: _AlishanScenePainter(
                    cloudProgress: _cloudController.value,
                    trainProgress: _trainController.value,
                    charImages: _charImages,
                  ),
                );
              },
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 20,
              child: FadeTransition(
                opacity: _buttonsFadeAnim,
                child: Row(
                  children: [
                    _LangChip(label: '繁中', selected: state.currentLang == 'zh', onTap: () => state.setLanguage('zh')),
                    const SizedBox(width: 8),
                    _LangChip(label: 'EN', selected: state.currentLang == 'en', onTap: () => state.setLanguage('en')),
                  ],
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 20,
              child: FadeTransition(
                opacity: _buttonsFadeAnim,
                child: GestureDetector(
                  onTap: _launchYoutube,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.play_circle_fill, color: Color(0xFFE64A19), size: 18), const SizedBox(width: 6), Text(state.t('介紹影片'), style: const TextStyle(color: Color(0xFF4E342E), fontSize: 13, fontWeight: FontWeight.bold))]),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  AnimatedBuilder(
                    animation: _floatAnim,
                    builder: (context, child) => Transform.translate(offset: Offset(0, _floatAnim.value), child: child),
                    child: FadeTransition(
                      opacity: _titleFadeAnim,
                      child: Container(
                        width: 90, height: 90,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: [BoxShadow(color: const Color(0xFFFF8F00).withOpacity(0.3), blurRadius: 30, spreadRadius: 8, offset: const Offset(0, 8))]),
                        child: const Center(child: Icon(Icons.explore, color: Color(0xFFE64A19), size: 48)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SlideTransition(
                    position: _titleSlideAnim,
                    child: FadeTransition(
                      opacity: _titleFadeAnim,
                      child: Column(
                        children: [
                          Text(state.t('霸道諸羅帶你回嘉'), style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Color(0xFF3E2723), letterSpacing: 4)),
                          const SizedBox(height: 6),
                          const Text('CHIAYI EXPLORER', style: TextStyle(fontSize: 14, letterSpacing: 6, color: Color(0xFFD84315), fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeTransition(
                    opacity: _subtitleFadeAnim,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(state.t('探索嘉義的每一個角落\n讓旅程成為你的故事'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: Color(0xFF5D4037), fontWeight: FontWeight.w600, height: 1.6, letterSpacing: 0.5)),
                    ),
                  ),
                  const Spacer(),
                  FadeTransition(
                    opacity: _buttonsFadeAnim,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: [
                          _GlowButton(
                            label: state.t('開始探索'), icon: Icons.login_rounded, isPrimary: true,
                            onTap: () {
                              Navigator.push(context, PageRouteBuilder(pageBuilder: (_, anim, __) => const LoginPage(), transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child), transitionDuration: const Duration(milliseconds: 500)));
                            },
                          ),
                          const SizedBox(height: 16),
                          _GlowButton(
                            label: state.t('註冊'), icon: Icons.person_add_alt_1_rounded, isPrimary: false,
                            onTap: () {
                              Navigator.push(context, PageRouteBuilder(pageBuilder: (_, anim, __) => const RegisterPage(), transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child), transitionDuration: const Duration(milliseconds: 500)));
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LangChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE64A19) : Colors.white.withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? Colors.transparent : Colors.white),
          boxShadow: selected ? [BoxShadow(color: const Color(0xFFE64A19).withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))] : [],
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: selected ? Colors.white : const Color(0xFF5D4037))),
      ),
    );
  }
}

class _GlowButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;

  const _GlowButton({required this.label, required this.icon, required this.isPrimary, required this.onTap});

  @override
  State<_GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<_GlowButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: double.infinity, height: 56,
          decoration: BoxDecoration(
            color: widget.isPrimary ? const Color(0xFFE64A19) : Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(28),
            border: widget.isPrimary ? null : Border.all(color: const Color(0xFFE64A19).withOpacity(0.5), width: 1.5),
            boxShadow: widget.isPrimary ? [BoxShadow(color: const Color(0xFFE64A19).withOpacity(0.4), blurRadius: 15, spreadRadius: 1, offset: const Offset(0, 5))] : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 22, color: widget.isPrimary ? Colors.white : const Color(0xFFD84315)),
              const SizedBox(width: 10),
              Text(widget.label, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: widget.isPrimary ? Colors.white : const Color(0xFFD84315))),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
// 🌟 阿里山全景繪製 (修復版 2.5D 火車與人物渲染)
// ══════════════════════════════════════════════
class _AlishanScenePainter extends CustomPainter {
  final double cloudProgress;
  final double trainProgress;
  final List<ui.Image?> charImages;

  const _AlishanScenePainter({
    required this.cloudProgress,
    required this.trainProgress,
    required this.charImages,
  });

  double _norm(double a) {
    while (a < 0) a += 2 * pi;
    while (a >= 2 * pi) a -= 2 * pi;
    return a;
  }

  void _drawMist(Canvas canvas, Size size, List<_CloudData> clouds) {
    for (final c in clouds) {
      double rawX = (c.dx + cloudProgress * c.speed) % 1.2 - 0.1;
      final cx = rawX * size.width;
      final cy = c.dy * size.height;
      final cw = c.w * size.width;
      final ch = c.h * size.height;
      final rect = Rect.fromCenter(center: Offset(cx, cy), width: cw, height: ch);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            c.color.withOpacity(c.opacity),
            c.color.withOpacity(c.opacity * 0.45),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(rect)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, c.blur);
      canvas.drawOval(rect, paint);
    }
  }

  void _drawMountain(Canvas canvas, Path path, Color base, Color highlight, Color shadow) {
    canvas.drawPath(path, Paint()..color = base);
    final bounds = path.getBounds();
    canvas.drawPath(path, Paint()..shader = LinearGradient(colors: [highlight.withOpacity(0.35), Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter).createShader(bounds));
    canvas.drawPath(path, Paint()..shader = LinearGradient(colors: [shadow.withOpacity(0.25), Colors.transparent], begin: Alignment.centerLeft, end: Alignment.centerRight).createShader(bounds));
  }

  List<Offset> _buildTrackCenterline(double w, double h) {
    return [
      Offset(w * 0.02, h * 0.655), Offset(w * 0.12, h * 0.640), Offset(w * 0.22, h * 0.622),
      Offset(w * 0.33, h * 0.608), Offset(w * 0.44, h * 0.600), Offset(w * 0.50, h * 0.598),
      Offset(w * 0.56, h * 0.600), Offset(w * 0.67, h * 0.608), Offset(w * 0.78, h * 0.622),
      Offset(w * 0.88, h * 0.640), Offset(w * 0.98, h * 0.655), Offset(w * 0.92, h * 0.530),
      Offset(w * 0.80, h * 0.490), Offset(w * 0.68, h * 0.465), Offset(w * 0.56, h * 0.452),
      Offset(w * 0.50, h * 0.448), Offset(w * 0.44, h * 0.452), Offset(w * 0.32, h * 0.465),
      Offset(w * 0.20, h * 0.490), Offset(w * 0.08, h * 0.530), Offset(w * 0.02, h * 0.655),
    ];
  }

  (Offset, double) _sampleTrack(List<Offset> pts, double t) {
    final totalPts = pts.length - 1;
    final raw = t * totalPts;
    final i = raw.floor() % totalPts;
    final frac = raw - raw.floor();
    final p0 = pts[i];
    final p1 = pts[(i + 1) % totalPts];
    return (Offset.lerp(p0, p1, frac)!, atan2(p1.dy - p0.dy, p1.dx - p0.dx));
  }

  void _drawTrackSegment(Canvas canvas, List<Offset> pts, {required bool isFront, double railGap = 7.5}) {
    final segPts = isFront ? pts.sublist(0, 11) : pts.sublist(10, 20);
    List<Offset> offsetPath(List<Offset> src, double d) {
      return List.generate(src.length, (i) {
        final prev = src[i == 0 ? 0 : i - 1];
        final next = src[i == src.length - 1 ? src.length - 1 : i + 1];
        final dx = next.dx - prev.dx;
        final dy = next.dy - prev.dy;
        final len = sqrt(dx * dx + dy * dy);
        if (len == 0) return src[i];
        return Offset(src[i].dx - (dy / len) * d, src[i].dy + (dx / len) * d);
      });
    }

    final outer = offsetPath(segPts, railGap);
    final inner = offsetPath(segPts, -railGap);
    final trackPaint = Paint()
      ..color = const Color(0xFF90A4AE).withOpacity(isFront ? 0.85 : 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isFront ? 2.2 : 1.5;

    for (final rail in [outer, inner]) {
      final path = Path()..moveTo(rail[0].dx, rail[0].dy);
      for (int i = 1; i < rail.length; i++) path.lineTo(rail[i].dx, rail[i].dy);
      canvas.drawPath(path, trackPaint);
    }

    final tiePaint = Paint()..color = const Color(0xFF6D4C41).withOpacity(isFront ? 0.70 : 0.35)..strokeWidth = isFront ? 2.0 : 1.2;
    final step = max(1, (segPts.length / 18).round());
    for (int i = 0; i < segPts.length - 1; i += step) canvas.drawLine(outer[i], inner[i], tiePaint);
  }

  // 🌟 火車車廂與人物渲染
  void _drawCarriage(Canvas canvas, Offset pos, double heading, bool isEngine, double trainProg, bool isFront, int carIndex) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);

    // 核心技術：2.5D 立體傾角算法
    bool isMovingLeft = cos(heading) < 0;
    double tilt = atan(sin(heading) / cos(heading));
    canvas.rotate(tilt);

    // 如果往左開，直接水平翻轉，確保人物與車廂依然保持正向！
    if (isMovingLeft) {
      canvas.scale(-1.0, 1.0);
    }
// 🌟 魔法步驟 1：在這裡加入「畫布縮放」！
    // 1.0 是原大小，1.5 就是放大 1.5 倍 (你可以自己微調，例如 1.3 或 2.0)
    canvas.scale(1.5, 1.5);
    const double cw = 15.0;
    const double ch = 7.5;
    final double opacity = isFront ? 1.0 : 0.55;

    // 底板
    canvas.drawRect(Rect.fromLTRB(-cw, ch - 2, cw, ch + 1), Paint()..color = const Color(0xFF4E342E).withOpacity(opacity));

    // 主體
    final bodyRect = Rect.fromLTRB(-cw, -ch, cw, ch);
    canvas.drawRRect(RRect.fromRectAndRadius(bodyRect, const Radius.circular(3)), Paint()..shader = LinearGradient(colors: [const Color(0xFFEF5350).withOpacity(opacity), const Color(0xFFC62828).withOpacity(opacity)], begin: Alignment.topCenter, end: Alignment.bottomCenter).createShader(bodyRect));

    // 車頂
    final roofRect = Rect.fromLTRB(-cw, -ch - 4, cw, -ch + 1);
    canvas.drawRRect(RRect.fromRectAndRadius(roofRect, const Radius.circular(2)), Paint()..shader = LinearGradient(colors: [const Color(0xFF424242).withOpacity(opacity), const Color(0xFF212121).withOpacity(opacity)], begin: Alignment.topCenter, end: Alignment.bottomCenter).createShader(roofRect));

    // 金色腰線
    canvas.drawRect(Rect.fromLTRB(-cw, -ch + 2, cw, -ch + 4), Paint()..color = const Color(0xFFFFD54F).withOpacity(opacity));

    // 🌟 人物繪製邏輯
    if (charImages.isNotEmpty && carIndex < charImages.length) {
      final ui.Image? charImg = charImages[carIndex];
      if (charImg != null) {
        canvas.save();
        canvas.translate(0, -ch - 4);
        if (isMovingLeft) canvas.scale(-1.0, 1.0);
        double imgHeight = 28.0;
        double imgWidth = (charImg.width / charImg.height) * imgHeight;
        canvas.translate(0, -imgHeight / 2);
        canvas.drawImageRect(
          charImg,
          Rect.fromLTWH(0, 0, charImg.width.toDouble(), charImg.height.toDouble()),
          Rect.fromCenter(center: Offset.zero, width: imgWidth, height: imgHeight),
          Paint()..color = Colors.white.withOpacity(opacity),
        );
        canvas.restore();
      }
    }

    // 車窗
    if (isFront) {
      final winPaint = Paint()..color = const Color(0xFFFFF9C4).withOpacity(0.9);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(-10, -4.5, -3, 0.5), const Radius.circular(1.5)), winPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(3, -4.5, 10, 0.5), const Radius.circular(1.5)), winPaint);
    }

    // 車輪
    final wheelPaint = Paint()..color = const Color(0xFF212121).withOpacity(opacity);
    for (final wx in [-8.0, 0.0, 8.0]) {
      canvas.drawCircle(Offset(wx, ch + 1), 2.8, wheelPaint);
      canvas.drawCircle(Offset(wx, ch + 1), 1.1, Paint()..color = const Color(0xFF757575).withOpacity(opacity));
    }

    if (isEngine) {
      final nosePaint = Paint()..shader = LinearGradient(colors: [const Color(0xFFEF5350).withOpacity(opacity), const Color(0xFFB71C1C).withOpacity(opacity)], begin: Alignment.topCenter, end: Alignment.bottomCenter).createShader(Rect.fromLTRB(cw, -ch, cw + 10, ch));
      canvas.drawRRect(RRect.fromRectAndCorners(Rect.fromLTRB(cw, -ch + 1, cw + 8, ch - 1), topRight: const Radius.circular(7), bottomRight: const Radius.circular(7)), nosePaint);

      if (isFront) {
        canvas.drawCircle(Offset(cw + 7, -2), 2.2, Paint()..color = Colors.white.withOpacity(0.9));
        canvas.drawCircle(Offset(cw + 7, -2), 1.0, Paint()..color = const Color(0xFFFFF9C4));
      }

      canvas.drawRect(Rect.fromLTRB(cw - 6, -ch - 8, cw - 2, -ch), Paint()..color = const Color(0xFF212121).withOpacity(opacity));
      canvas.drawRect(Rect.fromLTRB(cw - 8, -ch - 9, cw, -ch - 7), Paint()..color = const Color(0xFF424242).withOpacity(opacity));

      if (isFront) {
        for (int j = 0; j < 4; j++) {
          double phase = (trainProg * 3.0 + j * 0.28) % 1.0;
          canvas.drawCircle(
            Offset(cw - 4, -ch - 9 - phase * 40),
            3.5 + phase * 9,
            Paint()..color = Colors.white.withOpacity(0.75 * (1 - phase))..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
          );
        }
      }
    }

    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final trackPts = _buildTrackCenterline(w, h);
    final t = trainProgress;
    const int carriages = 7;
    const double spacing = 0.075;

    // 層 1：遠山
    final bgRange = Path()
      ..moveTo(-10, h * 0.60)..cubicTo(w * 0.10, h * 0.36, w * 0.18, h * 0.38, w * 0.25, h * 0.40)
      ..cubicTo(w * 0.33, h * 0.26, w * 0.42, h * 0.27, w * 0.50, h * 0.30)..cubicTo(w * 0.58, h * 0.27, w * 0.67, h * 0.26, w * 0.75, h * 0.40)
      ..cubicTo(w * 0.82, h * 0.38, w * 0.90, h * 0.36, w + 10, h * 0.52)..lineTo(w + 10, h)..lineTo(-10, h)..close();
    _drawMountain(canvas, bgRange, const Color(0xFF7BB05E), const Color(0xFFAED581), const Color(0xFF4E7D35));

    // 層 2：遠山霧
    _drawMist(canvas, size, [
      _CloudData(dx: 0.0,  dy: 0.40, w: 0.65, h: 0.13, opacity: 0.26, blur: 28, speed: 0.07, color: Colors.white),
      _CloudData(dx: 0.55, dy: 0.43, w: 0.55, h: 0.11, opacity: 0.20, blur: 22, speed: 0.05, color: const Color(0xFFF1F8E9)),
    ]);

    // 層 3：中景左右山
    final midLeft = Path()..moveTo(-10, h * 0.70)..cubicTo(w * 0.02, h * 0.62, w * 0.10, h * 0.55, w * 0.18, h * 0.47)..cubicTo(w * 0.24, h * 0.38, w * 0.34, h * 0.37, w * 0.44, h * 0.52)..cubicTo(w * 0.48, h * 0.58, w * 0.50, h * 0.62, w * 0.50, h * 0.68)..lineTo(w * 0.50, h)..lineTo(-10, h)..close();
    _drawMountain(canvas, midLeft, const Color(0xFF43A047), const Color(0xFF76C442), const Color(0xFF1B5E20));

    final midRight = Path()..moveTo(w + 10, h * 0.70)..cubicTo(w * 0.98, h * 0.62, w * 0.90, h * 0.55, w * 0.82, h * 0.47)..cubicTo(w * 0.76, h * 0.38, w * 0.66, h * 0.37, w * 0.56, h * 0.52)..cubicTo(w * 0.52, h * 0.58, w * 0.50, h * 0.62, w * 0.50, h * 0.68)..lineTo(w * 0.50, h)..lineTo(w + 10, h)..close();
    _drawMountain(canvas, midRight, const Color(0xFF4CAF50), const Color(0xFF81C784), const Color(0xFF2E7D32));

    // 層 4：後景火車 (在主峰背後)
    for (int i = carriages - 1; i >= 0; i--) {
      final ct = _norm(t - i * spacing) % 1.0;
      if (ct > 0.50 && ct <= 1.0) {
        final (pos, heading) = _sampleTrack(trackPts, ct);
        _drawCarriage(canvas, pos, heading, i == 0, trainProgress, false, i);
      }
    }

    // 層 5：阿里山主峰
    final mainPeak = Path()
      ..moveTo(-10, h)..lineTo(-10, h * 0.76)..cubicTo(w * 0.08, h * 0.64, w * 0.18, h * 0.56, w * 0.28, h * 0.52)
      ..cubicTo(w * 0.36, h * 0.40, w * 0.44, h * 0.30, w * 0.50, h * 0.27)..cubicTo(w * 0.56, h * 0.30, w * 0.64, h * 0.40, w * 0.72, h * 0.52)
      ..cubicTo(w * 0.82, h * 0.56, w * 0.92, h * 0.64, w + 10, h * 0.76)..lineTo(w + 10, h)..close();
    _drawMountain(canvas, mainPeak, const Color(0xFF2E7D32), const Color(0xFF5CB85C), const Color(0xFF1A4D1A));

    // 層 6：中層雲海
    _drawMist(canvas, size, [
      _CloudData(dx: -0.05, dy: 0.55, w: 0.95, h: 0.19, opacity: 0.42, blur: 38, speed: 0.06, color: Colors.white),
      _CloudData(dx: 0.42,  dy: 0.59, w: 0.80, h: 0.17, opacity: 0.36, blur: 33, speed: -0.05, color: const Color(0xFFF9FBE7)),
    ]);

    // 層 7：前景鐵軌
    _drawTrackSegment(canvas, trackPts, isFront: true);

    // 層 8：前景火車 (主峰前方)
    for (int i = carriages - 1; i >= 0; i--) {
      final ct = _norm(t - i * spacing) % 1.0;
      if (ct >= 0.0 && ct <= 0.50) {
        final (pos, heading) = _sampleTrack(trackPts, ct);
        _drawCarriage(canvas, pos, heading, i == 0, trainProgress, true, i);
      }
    }

    // 層 9：前景山丘
    final fgLeft = Path()..moveTo(-10, h)..cubicTo(w * 0.02, h * 0.84, w * 0.10, h * 0.80, w * 0.20, h * 0.78)..cubicTo(w * 0.28, h * 0.75, w * 0.36, h * 0.76, w * 0.44, h * 0.82)..lineTo(w * 0.44, h)..close();
    _drawMountain(canvas, fgLeft, const Color(0xFF1B5E20), const Color(0xFF2E7D32), const Color(0xFF0A3D0A));
    final fgRight = Path()..moveTo(w + 10, h)..cubicTo(w * 0.98, h * 0.84, w * 0.90, h * 0.80, w * 0.80, h * 0.78)..cubicTo(w * 0.72, h * 0.75, w * 0.64, h * 0.76, w * 0.56, h * 0.82)..lineTo(w * 0.56, h)..close();
    _drawMountain(canvas, fgRight, const Color(0xFF2E7D32), const Color(0xFF43A047), const Color(0xFF1A4D1A));

    // 層 10：前景濃霧
    _drawMist(canvas, size, [
      _CloudData(dx: -0.10, dy: 0.83, w: 1.15, h: 0.27, opacity: 0.60, blur: 45, speed: 0.05, color: Colors.white),
      _CloudData(dx: 0.36,  dy: 0.89, w: 0.95, h: 0.23, opacity: 0.55, blur: 38, speed: -0.04, color: const Color(0xFFF1F8E9)),
    ]);
  }

  @override
  bool shouldRepaint(covariant _AlishanScenePainter old) => old.cloudProgress != cloudProgress || old.trainProgress != trainProgress;
}

class _CloudData {
  final double dx, dy, w, h, opacity, blur, speed;
  final Color color;
  const _CloudData({required this.dx, required this.dy, required this.w, required this.h, required this.opacity, required this.blur, required this.speed, required this.color});
}