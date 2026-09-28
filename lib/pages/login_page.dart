// lib/pages/login_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../providers/app_state.dart';
import 'register_page.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main_layout.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _accController = TextEditingController();
  final _passController = TextEditingController();
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _accController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final state = context.read<AppStateManager>();
    if (_accController.text.isEmpty || _passController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.t('請輸入帳號與密碼'))));
      return;
    }

    try {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.t('登入中...'))));

      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: _accController.text,
            password: _passController.text,
          );

      final userDoc =
          await FirebaseFirestore.instance
              .collection('Users')
              .doc(userCredential.user!.uid)
              .get();

      if (!userDoc.exists) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.t('找不到您的帳號資料，為您跳轉至註冊頁！'))));
        await FirebaseAuth.instance.signOut();

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RegisterPage()),
          );
        }
        return;
      }

      await userDoc.reference.update({
        "Last_Login": FieldValue.serverTimestamp(),
        "Language_Pref": state.currentLang,
      });

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.t('登入成功！'))));

      state.forceLogin(_accController.text, _passController.text);
      // 🌟 關鍵：每次登入都重新從 Firestore 載入 isAdmin 等使用者資料
      await state.loadUserDataFromFirestore(
        userCredential.user!.uid,
        _accController.text,
      );
      state.setPageIndex(0);

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainLayout()),
          (Route<dynamic> route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      final state = context.read<AppStateManager>();
      ScaffoldMessenger.of(context).clearSnackBars();

      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.t('查無此帳號或密碼錯誤，將跳轉至註冊頁面...'))),
        );

        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const RegisterPage()),
            );
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${state.t('登入失敗: ')}${e.message}')),
        );
      }
    }
  }

  Future<void> _googleLogin() async {
    final state = context.read<AppStateManager>();
    try {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.t('正在連線至 Google...'))));

      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize();
      await googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await googleSignIn.authenticate();

      if (googleUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.t('已取消 Google 登入'))));
        }
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

      if (userCredential.user != null) {
        final userDoc =
            await FirebaseFirestore.instance
                .collection('Users')
                .doc(userCredential.user!.uid)
                .get();

        if (!userDoc.exists) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.t('您尚未建立帳號，請先完成註冊！'))));
          await FirebaseAuth.instance.signOut();
          await googleSignIn.signOut();
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const RegisterPage()),
            );
          }
          return;
        }

        await userDoc.reference.update({
          "Last_Login": FieldValue.serverTimestamp(),
          "Language_Pref": state.currentLang,
        });

        final userEmail = userCredential.user!.email ?? "";
        final storedNickname = userDoc.data()?['Nickname']?.toString().trim();
        final userName =
            storedNickname != null && storedNickname.isNotEmpty
                ? storedNickname
                : (userCredential.user!.displayName?.trim().isNotEmpty == true
                    ? userCredential.user!.displayName!.trim()
                    : userEmail.split('@').first);

        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${state.t('歡迎回來, ')}$userName!')),
        );

        state.forceLogin(userEmail, 'google_sso_login');
        // 🌟 關鍵：Google 登入也重新載入 isAdmin
        await state.loadUserDataFromFirestore(
          userCredential.user!.uid,
          userEmail,
        );
        state.updateProfile(userName, '', null);
        state.setPageIndex(0);

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const MainLayout()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      debugPrint('Google 登入錯誤: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.t('登入已取消或發生錯誤'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateManager>();
    final palette = state.activePalette;
    final themeColor = palette[0];
    final secondaryColor = palette[5];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // 返回按鈕回到 SplashPage
        leading:
            Navigator.canPop(context)
                ? IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(context),
                )
                : null,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('繁中'),
                  selected: state.currentLang == 'zh',
                  selectedColor: Colors.white,
                  backgroundColor: Colors.white.withOpacity(0.5),
                  onSelected: (val) {
                    if (val) state.setLanguage('zh');
                  },
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color:
                        state.currentLang == 'zh' ? themeColor : Colors.black54,
                  ),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('EN'),
                  selected: state.currentLang == 'en',
                  selectedColor: Colors.white,
                  backgroundColor: Colors.white.withOpacity(0.5),
                  onSelected: (val) {
                    if (val) state.setLanguage('en');
                  },
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color:
                        state.currentLang == 'en' ? themeColor : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [themeColor, secondaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 10,
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        Text(
                          state.t("歡迎回到諸羅探索"),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: themeColor,
                          ),
                        ),
                        const SizedBox(height: 30),

                        TextField(
                          controller: _accController,
                          decoration: InputDecoration(
                            labelText: state.t("帳號"),
                            prefixIcon: Icon(Icons.person, color: themeColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: state.t("密碼"),
                            prefixIcon: Icon(Icons.lock, color: themeColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeColor,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _login,
                          child: Text(
                            state.t("登入"),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: Colors.grey[300],
                                thickness: 1,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                state.t("或"),
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: Colors.grey[300],
                                thickness: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1.5,
                            ),
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _googleLogin,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'G',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'serif',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                state.t("使用 Google 帳號登入"),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[800],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              state.t("還沒有帳號嗎？"),
                              style: const TextStyle(color: Colors.grey),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const RegisterPage(),
                                  ),
                                );
                              },
                              child: Text(
                                state.t("立即註冊"),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: themeColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
