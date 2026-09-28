// lib/pages/register_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import '../providers/app_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_page.dart';
import 'main_layout.dart';
import 'package:firebase_storage/firebase_storage.dart'; // 🌟 加入這行

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nickController = TextEditingController();
  final _accController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController();
  File? _image;

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) setState(() => _image = File(pickedFile.path));
  }

  Future<void> _googleSignUp() async {
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
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.t('已取消 Google 註冊'))));
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
        final userEmail = userCredential.user!.email ?? "";
        final googleName = userCredential.user!.displayName?.trim();
        final userName =
            googleName != null && googleName.isNotEmpty
                ? googleName
                : userEmail.split('@').first;

        await _saveUserToFirestore(userCredential.user!, userName);

        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${state.t('✅ Google 帳號綁定成功, 歡迎 ')}$userName!'),
          ),
        );

        state.forceLogin(userEmail, 'google_sso_login');
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
      debugPrint('Google 註冊發生錯誤: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${state.t('註冊失敗，請稍後再試 (')}$e)')),
        );
      }
    }
  }

  Future<void> _normalSignUp() async {
    final state = context.read<AppStateManager>();
    try {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.t('正在建立帳號...'))));

      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _accController.text,
            password: _passController.text,
          );

      if (userCredential.user != null) {
        await userCredential.user!.updateDisplayName(
          _nickController.text.trim(),
        );

        // 🌟 新增：如果註冊時有選大頭貼，先上傳到 Storage
        String? uploadedAvatarUrl;
        if (_image != null) {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('user_avatars')
              .child('${userCredential.user!.uid}.jpg');
          await storageRef.putFile(_image!);
          uploadedAvatarUrl = await storageRef.getDownloadURL();
        }

        // 把上傳後的網址傳給 _saveUserToFirestore
        await _saveUserToFirestore(
          userCredential.user!,
          _nickController.text,
          avatarUrl: uploadedAvatarUrl,
        );

        ScaffoldMessenger.of(context).clearSnackBars();
        // 後面維持原樣...
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.t('✅ 註冊成功，請登入您的帳號！'))));
        state.register(
          _nickController.text,
          _accController.text,
          _passController.text,
          _image,
        );
        state.setPageIndex(0);
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const MainLayout()),
            (route) => false,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).clearSnackBars();
      String errorMsg = state.t('註冊失敗');
      if (e.code == 'email-already-in-use') {
        errorMsg = state.t('這個信箱已經被註冊過了！請換一個。');
      } else if (e.code == 'weak-password') {
        errorMsg = state.t('密碼太弱，請至少輸入 6 個字元！');
      } else if (e.code == 'invalid-email') {
        errorMsg = state.t('信箱格式不正確！');
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMsg)));
    } catch (e) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${state.t('發生錯誤: ')}$e')));
    }
  }

  // 🌟 新增可選參數 [avatarUrl]
  Future<void> _saveUserToFirestore(
    User user,
    String fallbackNickname, {
    String? avatarUrl,
  }) async {
    final userDoc = FirebaseFirestore.instance
        .collection('Users')
        .doc(user.uid);
    final docSnapshot = await userDoc.get();

    if (!docSnapshot.exists) {
      await userDoc.set({
        "User_Id": user.uid,
        "Nickname": user.displayName ?? fallbackNickname,
        // 🌟 優先使用剛剛上傳的 Storage 網址，沒有才用 Google 的，再沒有才用預設的
        "Avatar_Url":
            avatarUrl ?? user.photoURL ?? "assets/images/default_avatar.png",
        "Created_At": FieldValue.serverTimestamp(),
        "Last_Login": FieldValue.serverTimestamp(),
        "Language_Pref": context.read<AppStateManager>().currentLang,
        "Push_Enabled": true,
        "Voice_Speed": 1,
      });
      debugPrint("✅ 新用戶資料已建立至 Firestore");
    } else {
      await userDoc.update({
        "Last_Login": FieldValue.serverTimestamp(),
        "Nickname": user.displayName ?? fallbackNickname,
        if (user.photoURL != null) "Avatar_Url": user.photoURL,
        "Language_Pref": context.read<AppStateManager>().currentLang,
      });
      debugPrint("🔄 舊用戶資料已更新最後登入時間與語言");
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateManager>();
    final palette = state.activePalette;
    final themeColor = palette[0];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          state.t('註冊新帳號'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('繁中'), // 🌟 名稱統一為 繁中
                  selected: state.currentLang == 'zh',
                  selectedColor: Colors.white,
                  backgroundColor: Colors.white.withOpacity(0.4),
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
                  backgroundColor: Colors.white.withOpacity(0.4),
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
            colors: [themeColor, palette[5]],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 10,
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Text(
                        state.t("加入諸羅探索"),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: themeColor,
                        ),
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: _pickImage,
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: themeColor.withOpacity(0.1),
                          backgroundImage:
                              _image != null ? FileImage(_image!) : null,
                          child:
                              _image == null
                                  ? Icon(
                                    Icons.add_a_photo,
                                    size: 30,
                                    color: themeColor,
                                  )
                                  : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        state.t("點擊上傳頭像 (選填)"),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 20),

                      _buildTextField(
                        _nickController,
                        state.t("暱稱"),
                        Icons.face,
                        false,
                        themeColor,
                        state,
                      ),
                      _buildTextField(
                        _accController,
                        state.t("帳號"),
                        Icons.person,
                        false,
                        themeColor,
                        state,
                      ),
                      _buildTextField(
                        _passController,
                        state.t("密碼"),
                        Icons.lock,
                        true,
                        themeColor,
                        state,
                      ),
                      _buildTextField(
                        _confirmPassController,
                        state.t("再次輸入密碼"),
                        Icons.lock_outline,
                        true,
                        themeColor,
                        state,
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
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            if (_passController.text !=
                                _confirmPassController.text) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(state.t("兩次輸入的密碼不一致！"))),
                              );
                              return;
                            }
                            _normalSignUp();
                          }
                        },
                        child: Text(
                          state.t("完成註冊"),
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
                            padding: const EdgeInsets.symmetric(horizontal: 12),
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
                        onPressed: _googleSignUp,
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
                              state.t("使用 Google 帳號註冊"),
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon,
    bool isPass,
    Color themeColor,
    AppStateManager state,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        obscureText: isPass,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: themeColor),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return state.t("此欄位為必填");
          }

          if (label == state.t("帳號") && !value.contains('@')) {
            return state.t("帳號必須是有效的 Email 格式 (例如: a@b.com)");
          }

          if (isPass && value.length < 6) {
            return state.t("密碼長度至少需要 6 個字元");
          }

          return null;
        },
      ),
    );
  }
}
