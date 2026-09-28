// lib/pages/profile_page.dart
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:translator/translator.dart';
import '../widgets/app_drawer.dart';
import '../providers/app_state.dart';
import 'splash_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  final _passController = TextEditingController();

  bool _enableNotifications = true;
  bool _isEditing = false;
  File? _tempImage;
  bool _isTranslating = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppStateManager>();
    _nameController = TextEditingController(text: state.greetingName);
    _emailController = TextEditingController(text: state.account);
    _tempImage = state.avatar;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) setState(() => _tempImage = File(pickedFile.path));
  }

  Future<void> _saveProfile(AppStateManager state) async {
    try {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.t('資料同步中，請稍候...'))));

      if (_passController.text.isNotEmpty && _passController.text.length >= 6) {
        await FirebaseAuth.instance.currentUser?.updatePassword(
          _passController.text,
        );
      }

      await state.updateProfile(
        _nameController.text,
        _passController.text,
        _tempImage,
      );

      setState(() {
        _isEditing = false;
        _passController.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.t('✅ 設定已成功同步至雲端！'))));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${state.t('更新失敗: ')}$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateManager>();
    final themeColor = state.themeColor;
    final palette = state.activePalette;

    return Scaffold(
      appBar: AppBar(
        title: Text(state.t('使用者資訊與設定')),
        backgroundColor: themeColor,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit),
            onPressed: () {
              setState(() => _isEditing = !_isEditing);
            },
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: GestureDetector(
                onTap: _isEditing ? _pickImage : null,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: themeColor.withOpacity(0.2),
                      backgroundImage:
                          _tempImage != null
                              ? FileImage(_tempImage!) as ImageProvider
                              : (state.avatarUrl != null
                                  ? NetworkImage(state.avatarUrl!)
                                  : null),
                      child:
                          (_tempImage == null && state.avatarUrl == null)
                              ? Icon(Icons.person, size: 60, color: themeColor)
                              : null,
                    ),
                    if (_isEditing)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: palette[1],
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              state.t('基本資料'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: themeColor,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              enabled: _isEditing,
              decoration: InputDecoration(
                labelText: state.t('真實姓名 / 暱稱'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.badge),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              enabled: false,
              decoration: InputDecoration(
                labelText: state.t('登入帳號 (不可修改)'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.email),
              ),
            ),

            if (_isEditing) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _passController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: state.t('修改密碼 (若不修改請留白)'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                ),
              ),
            ],

            const SizedBox(height: 24),

            Text(
              state.t('系統設定'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: themeColor,
              ),
            ),
            const SizedBox(height: 12),

            Card(
              child: ListTile(
                leading: Icon(Icons.language, color: themeColor),
                title: Text(state.t('App 介面語言')),
                subtitle: Text(
                  state.currentLang == 'zh'
                      ? state.t('目前語系：繁體中文')
                      : state.t('目前語系：English'),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ChoiceChip(
                      label: const Text('繁中'),
                      selected: state.currentLang == 'zh',
                      selectedColor: themeColor.withOpacity(0.2),
                      onSelected: (selected) {
                        if (selected) state.setLanguage('zh');
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('EN'),
                      selected: state.currentLang == 'en',
                      selectedColor: themeColor.withOpacity(0.2),
                      onSelected: (selected) {
                        if (selected) state.setLanguage('en');
                      },
                    ),
                  ],
                ),
              ),
            ),

            Card(
              child: SwitchListTile(
                secondary: Icon(Icons.notifications, color: themeColor),
                title: Text(state.t('接收智慧推播通知')),
                subtitle: Text(state.t('活動提醒、天氣預報、景點異動')),
                value: _enableNotifications,
                activeThumbColor: themeColor,
                onChanged:
                    (bool value) =>
                        setState(() => _enableNotifications = value),
              ),
            ),

            if (_enableNotifications)
              Card(
                child: ListTile(
                  leading: Icon(Icons.do_not_disturb_on, color: palette[2]),
                  title: Text(state.t('智慧推播靜音時段')),
                  subtitle: Text(state.t('設定晚上或不便打擾的時間')),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {},
                ),
              ),

            const SizedBox(height: 32),

            if (_isEditing)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _saveProfile(state),
                  child: Text(
                    state.t('儲存修改'),
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[50],
                  foregroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  await state.logout();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const SplashPage()),
                      (route) => false,
                    );
                  }
                },
                child: Text(
                  state.t('退出登入'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
