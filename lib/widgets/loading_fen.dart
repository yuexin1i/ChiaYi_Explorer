import 'package:flutter/material.dart';
import 'dart:async';

// ── 改良版：小芬載入畫面 (防 Overflow) ──
class LoadingFenWidget extends StatelessWidget {
  final String text;

  const LoadingFenWidget({
    super.key,
    this.text = '"小芬"玩命加載中...'
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      // 🌟 加上 SingleChildScrollView 徹底解決 RenderFlex overflow
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min, // 🌟 讓 Column 只佔用需要的空間，不強制撐滿
          children: [
            Image.asset(
              'assets/loading_fen.gif',
              width: 110, // 稍微縮小一點 (原本 150)
              height: 110,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 8), // 字離圖近一點 (原本 16)
            Text(
              text,
              style: const TextStyle(
                fontSize: 14, // 字體稍微縮小一點
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 新增：TDX 限流專用倒數計時畫面 ──
class TdxRateLimitWidget extends StatefulWidget {
  final VoidCallback onRetry;
  final Color themeColor;

  const TdxRateLimitWidget({
    super.key,
    required this.onRetry,
    required this.themeColor,
  });

  @override
  State<TdxRateLimitWidget> createState() => _TdxRateLimitWidgetState();
}

class _TdxRateLimitWidgetState extends State<TdxRateLimitWidget> {
  int _secondsLeft = 60; // TDX 通常限流懲罰為 1 分鐘
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool canRetry = _secondsLeft == 0;

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_empty, color: Colors.orange[400], size: 48),
            const SizedBox(height: 12),
            Text('TDX 伺服器忙碌中', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              canRetry ? '您可以再次嘗試更新了！' : 'API 請求過於頻繁，請稍候 $_secondsLeft 秒',
              style: TextStyle(color: canRetry ? Colors.green[600] : Colors.red[400], fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: canRetry ? widget.onRetry : null,
              icon: const Icon(Icons.refresh),
              label: Text(canRetry ? '重新載入' : '冷卻中...'),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.themeColor.withOpacity(0.1),
                foregroundColor: widget.themeColor,
                elevation: 0,
                disabledForegroundColor: Colors.grey,
                disabledBackgroundColor: Colors.grey[200],
              ),
            ),
          ],
        ),
      ),
    );
  }
}