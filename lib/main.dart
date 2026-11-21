import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const OfficialCloneManagerApp());
}

class OfficialCloneManagerApp extends StatelessWidget {
  const OfficialCloneManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مدير النسخ الرسمية',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          secondary: Color(0xFF22C55E),
          surface: Color(0xFF1E293B),
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: HomeScreen(),
      ),
    );
  }
}

enum AppCategory {
  restricted, // محظور (بنوك، كي كارد، مالية، أمن الجهاز)
  social,     // تواصل اجتماعي (نسخة واحدة فقط)
  standard,   // بقية التطبيقات (نسخ لا نهائية)
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<AppInfo> _installedApps = [];
  Map<String, int> _cloneCounts = {};
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, social, standard, restricted

  // كلمات مفتاحية لتحديد التطبيقات المحظورة (أمن، مالية، بنوك، كي كارد)
  final List<String> _restrictedKeywords = [
    'bank', 'qi', 'qicard', 'pay', 'wallet', 'finance', 'card',
    'mastercard', 'visa', 'zaincash', 'asiapay', 'fastpay', 'nasswallet',
    'security', 'antivirus', 'knox', 'guard', 'authenticator', 'vpn',
    'مصرف', 'بنك', 'كي كارد', 'محفظة', 'مالية', 'حماية', 'أمان'
  ];

  // كلمات مفتاحية لتحديد مواقع التواصل الاجتماعي (نسخة واحدة فقط)
  final List<String> _socialKeywords = [
    'whatsapp', 'facebook', 'instagram', 'telegram', 'tiktok',
    'snapchat', 'twitter', 'x.android', 'viber', 'messenger',
    'threads', 'linkedin', 'discord', 'imo'
  ];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedClones = prefs.getString('clone_counts');
    if (savedClones != null) {
      setState(() {
        _cloneCounts = Map<String, int>.from(json.decode(savedClones));
      });
    }

    // جلب التطبيقات الرسمية المثبتة على الهاتف (بدون تطبيقات النظام الأساسية)
    List<AppInfo> apps = await InstalledApps.getInstalledApps(true, true);
    apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    setState(() {
      _installedApps = apps;
      _isLoading = false;
    });
  }

  Future<void> _saveClones() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('clone_counts', json.encode(_cloneCounts));
  }

  AppCategory _classifyApp(AppInfo app) {
    final pkg = app.packageName.toLowerCase();
    final name = app.name.toLowerCase();

    for (final word in _restrictedKeywords) {
      if (pkg.contains(word) || name.contains(word)) {
        return AppCategory.restricted;
      }
    }
    for (final word in _socialKeywords) {
      if (pkg.contains(word) || name.contains(word)) {
        return AppCategory.social;
      }
    }
    return AppCategory.standard;
  }

  bool _hasBanRisk(AppInfo app, AppCategory category) {
    final pkg = app.packageName.toLowerCase();
    // تنبيه الحظر للتطبيقات الحساسة للجلسات المتعددة أو الألعاب/التواصل
    if (category == AppCategory.social) return true;
    if (pkg.contains('pubg') || pkg.contains('tencent') || pkg.contains('game')) {
      return true;
    }
    return false;
  }

  void _handleCreateClone(AppInfo app, AppCategory category) {
    if (category == AppCategory.restricted) {
      _showAlert(
        title: 'ممنوع النسخ (حماية وأمان)',
        message:
            'تطبيق "${app.name}" مصنف ضمن البرامج المالية أو المصرفية (كي كارد) أو أمن الجهاز. يُمنع نسخه حفاظاً على بياناتك.',
        isError: true,
      );
      return;
    }

    final currentCount = _cloneCounts[app.packageName] ?? 0;

    if (category == AppCategory.social && currentCount >= 1) {
      _showAlert(
        title: 'الحد الأقصى: نسخة واحدة فقط',
        message:
            'تطبيقات التواصل الاجتماعي مسموح لها بنسخة واحدة فقط لتجنب تعارض الجلسات وحظر الحساب.',
        isError: true,
      );
      return;
    }

    final hasBanWarning = _hasBanRisk(app, category);

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Row(
            children: [
              Icon(
                hasBanWarning ? Icons.warning_amber_rounded : Icons.verified_user,
                color: hasBanWarning ? Colors.amber : Colors.greenAccent,
              ),
              const SizedBox(width: 8),
              const Expanded(child: Text('تأكيد إنشاء نسخة رسمية')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'سيتم تجهيز النسخة رقم (${currentCount + 1}) من "${app.name}" كنسخة رسمية طبق الأصل 100% بدون أي كراك أو باتش.',
                style: const TextStyle(fontSize: 14),
              ),
              if (hasBanWarning) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    border: Border.all(color: Colors.amber),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '⚠️ تحذير حظر: تشغيل أكثر من حساب أو جلسة لهذا التطبيق على نفس الجهاز أو الشبكة قد يعرض حسابك للتقييد أو الحظر من الشركة المطورة.',
                    style: TextStyle(color: Colors.amber, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _cloneCounts[app.packageName] = currentCount + 1;
                });
                _saveClones();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'تمت إضافة النسخة الرسمية #${currentCount + 1} لـ ${app.name}',
                    ),
                    backgroundColor: Colors.green.shade700,
                  ),
                );
              },
              child: const Text('إنشاء النسخة'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAlert({
    required String title,
    required String message,
    bool isError = false,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Row(
            children: [
              Icon(
                isError ? Icons.block : Icons.info_outline,
                color: isError ? Colors.redAccent : Colors.lightBlueAccent,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(title)),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('حسناً'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredApps = _installedApps.where((app) {
      final matchesSearch = app.name
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          app.packageName.toLowerCase().contains(_searchQuery.toLowerCase());
      if (!matchesSearch) return false;

      final cat = _classifyApp(app);
      if (_selectedFilter == 'social') return cat == AppCategory.social;
      if (_selectedFilter == 'standard') return cat == AppCategory.standard;
      if (_selectedFilter == 'restricted') return cat == AppCategory.restricted;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('مدير النسخ الرسمية'),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: Column(
        children: [
          // شريط القواعد السريع
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: const Color(0xFF162032),
            child: const Text(
              '• نسخ رسمية 100% بدون تعديل  |  • التواصل: نسخة واحدة  |  • المصارف والأمن: محجوب',
              style: TextStyle(fontSize: 11.5, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),

          // حقل البحث
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'ابحث باسم التطبيق المثبت...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // أزرار الفلترة
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _buildFilterChip('الكل', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('نسخ مفتوحة (غير محدودة)', 'standard'),
                const SizedBox(width: 8),
                _buildFilterChip('تواصل اجتماعي (1 فقط)', 'social'),
                const SizedBox(width: 8),
                _buildFilterChip('محجوب (أمن/مالية)', 'restricted'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // قائمة التطبيقات
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredApps.isEmpty
                    ? const Center(child: Text('لا توجد تطبيقات مطابقة'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filteredApps.length,
                        itemBuilder: (context, index) {
                          final app = filteredApps[index];
                          final category = _classifyApp(app);
                          final cloneCount = _cloneCounts[app.packageName] ?? 0;
                          final banRisk = _hasBanRisk(app, category);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (app.icon != null)
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: Image.memory(
                                            app.icon!,
                                            width: 46,
                                            height: 46,
                                          ),
                                        )
                                      else
                                        const Icon(Icons.android, size: 46),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              app.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'الإصدار الرسمي: ${app.versionName}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.white60,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      _buildStatusBadge(category, cloneCount),
                                    ],
                                  ),

                                  // تحذير الحظر في حال انطباقه
                                  if (banRisk &&
                                      category != AppCategory.restricted)
                                    Container(
                                      margin: const EdgeInsets.only(top: 10),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color:
                                                Colors.amber.withOpacity(0.5)),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.warning_amber_rounded,
                                              color: Colors.amber, size: 16),
                                          SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'تنبيه حظر: تعدد الحسابات في هذا التطبيق قد يؤدي لتقييد الحساب.',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.amber),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  // أزرار التحكم والنسخ
                                  if (category != AppCategory.restricted) ...[
                                    const Divider(height: 20),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          category == AppCategory.social
                                              ? 'النسخ المنشأة: $cloneCount / 1'
                                              : 'النسخ المنشأة: $cloneCount (مفتوح)',
                                          style: const TextStyle(
                                              fontSize: 12.5,
                                              color: Colors.lightBlueAccent),
                                        ),
                                        Row(
                                          children: [
                                            if (cloneCount > 0)
                                              OutlinedButton.icon(
                                                onPressed: () {
                                                  InstalledApps.startApp(
                                                      app.packageName);
                                                },
                                                icon: const Icon(
                                                    Icons.open_in_new,
                                                    size: 16),
                                                label: const Text('فتح الرسمي'),
                                              ),
                                            const SizedBox(width: 8),
                                            ElevatedButton.icon(
                                              onPressed: () =>
                                                  _handleCreateClone(
                                                      app, category),
                                              icon: const Icon(Icons.copy_all,
                                                  size: 16),
                                              label: const Text('نسخ'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = value),
      selectedColor: const Color(0xFF38BDF8).withOpacity(0.3),
    );
  }

  Widget _buildStatusBadge(AppCategory category, int count) {
    switch (category) {
      case AppCategory.restricted:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'محجوب أمنياً',
            style: TextStyle(color: Colors.redAccent, fontSize: 11),
          ),
        );
      case AppCategory.social:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'نسخة 1 فقط',
            style: TextStyle(color: Colors.orangeAccent, fontSize: 11),
          ),
        );
      case AppCategory.standard:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'نسخ متعددة',
            style: TextStyle(color: Colors.greenAccent, fontSize: 11),
          ),
        );
    }
  }
}
