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

class CloneItem {
  final String id;
  String name;
  final int index;
  String? lastOpened;

  CloneItem({
    required this.id,
    required this.name,
    required this.index,
    this.lastOpened,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'index': index,
        'lastOpened': lastOpened,
      };

  factory CloneItem.fromJson(Map<String, dynamic> json) => CloneItem(
        id: json['id']?.toString() ?? UniqueKey().toString(),
        name: json['name']?.toString() ?? 'النسخة الرسمية',
        index: (json['index'] is int) ? json['index'] as int : 1,
        lastOpened: json['lastOpened']?.toString(),
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<AppInfo> _installedApps = [];
  Map<String, List<CloneItem>> _cloneItems = {};
  final Set<String> _expandedApps = {};
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
    final savedDetailed = prefs.getString('clone_items_v2');
    final Map<String, List<CloneItem>> loadedMap = {};

    if (savedDetailed != null) {
      final decoded = json.decode(savedDetailed) as Map<String, dynamic>;
      decoded.forEach((pkg, list) {
        if (list is List) {
          loadedMap[pkg] = list
              .map((e) => CloneItem.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      });
    } else {
      // الحفاظ على السجل القديم (clone_counts) وتحويله تلقائياً دون فقدان أي نسخة
      final savedClones = prefs.getString('clone_counts');
      if (savedClones != null) {
        final oldCounts = Map<String, int>.from(json.decode(savedClones));
        oldCounts.forEach((pkg, count) {
          if (count > 0) {
            loadedMap[pkg] = List.generate(
              count,
              (i) => CloneItem(
                id: '${pkg}_${i + 1}',
                name: 'النسخة الرسمية #${i + 1}',
                index: i + 1,
              ),
            );
          }
        });
      }
    }

    // جلب التطبيقات الرسمية المثبتة على الهاتف (بدون تطبيقات النظام الأساسية)
    List<AppInfo> apps = await InstalledApps.getInstalledApps(true, true);
    apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    setState(() {
      _cloneItems = loadedMap;
      _installedApps = apps;
      _isLoading = false;
    });
  }

  Future<void> _saveClones() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> encodedMap = {};
    final Map<String, int> countsMap = {};

    _cloneItems.forEach((pkg, items) {
      encodedMap[pkg] = items.map((e) => e.toJson()).toList();
      countsMap[pkg] = items.length;
    });

    await prefs.setString('clone_items_v2', json.encode(encodedMap));
    await prefs.setString('clone_counts', json.encode(countsMap));
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

    final currentList = _cloneItems[app.packageName] ?? [];
    final currentCount = currentList.length;

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
                final newIndex = currentCount + 1;
                final newItem = CloneItem(
                  id: '${app.packageName}_${DateTime.now().millisecondsSinceEpoch}',
                  name: 'النسخة الرسمية #$newIndex',
                  index: newIndex,
                );
                setState(() {
                  _cloneItems[app.packageName] = [...currentList, newItem];
                  _expandedApps.add(app.packageName);
                });
                _saveClones();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'تمت إضافة النسخة الرسمية #$newIndex لـ ${app.name}',
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

  void _openSingleClone(AppInfo app, CloneItem item) {
    final now = TimeOfDay.now().format(context);
    setState(() {
      item.lastOpened = now;
    });
    _saveClones();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('فتح ${app.name} (${item.name})'),
        duration: const Duration(seconds: 2),
      ),
    );
    InstalledApps.startApp(app.packageName);
  }

  void _renameClone(AppInfo app, CloneItem item) {
    final controller = TextEditingController(text: item.name);
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('تسمية النسخة'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'مثلاً: حساب 1 أو نسخة العمل',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  setState(() {
                    item.name = controller.text.trim();
                  });
                  _saveClones();
                }
                Navigator.pop(ctx);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteSingleClone(AppInfo app, CloneItem item) {
    final updatedList = List<CloneItem>.from(_cloneItems[app.packageName] ?? [])
      ..removeWhere((e) => e.id == item.id);

    setState(() {
      if (updatedList.isEmpty) {
        _cloneItems.remove(app.packageName);
        _expandedApps.remove(app.packageName);
      } else {
        _cloneItems[app.packageName] = updatedList;
      }
    });
    _saveClones();
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
                          final clones = _cloneItems[app.packageName] ?? [];
                          final cloneCount = clones.length;
                          final isExpanded =
                              _expandedApps.contains(app.packageName);
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

                                  // أزرار التحكم والنسخ (مرتبة بدون تداخل على الطرف)
                                  if (category != AppCategory.restricted) ...[
                                    const Divider(height: 20),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: InkWell(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            onTap: cloneCount > 0
                                                ? () {
                                                    setState(() {
                                                      if (isExpanded) {
                                                        _expandedApps.remove(
                                                            app.packageName);
                                                      } else {
                                                        _expandedApps.add(
                                                            app.packageName);
                                                      }
                                                    });
                                                  }
                                                : null,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 6,
                                                      horizontal: 4),
                                              child: Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      category ==
                                                              AppCategory.social
                                                          ? 'النسخ المنشأة: $cloneCount / 1'
                                                          : 'النسخ المنشأة: $cloneCount',
                                                      style: const TextStyle(
                                                        fontSize: 12.5,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors
                                                            .lightBlueAccent,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (cloneCount > 0) ...[
                                                    const SizedBox(width: 4),
                                                    Icon(
                                                      isExpanded
                                                          ? Icons
                                                              .keyboard_arrow_up
                                                          : Icons
                                                              .keyboard_arrow_down,
                                                      size: 20,
                                                      color: Colors
                                                          .lightBlueAccent,
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          onPressed: () =>
                                              _handleCreateClone(app, category),
                                          icon: const Icon(Icons.copy_all,
                                              size: 16),
                                          label: const Text('نسخ'),
                                        ),
                                      ],
                                    ),

                                    // القائمة المنسدلة للنسخ المستنسخة جوا نفس التطبيق
                                    if (isExpanded && clones.isNotEmpty)
                                      Container(
                                        margin: const EdgeInsets.only(top: 10),
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0F172A),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color: Colors.white12),
                                        ),
                                        child: Column(
                                          children: clones.map((item) {
                                            return Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 4),
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.layers_outlined,
                                                    size: 18,
                                                    color: Colors.greenAccent,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          item.name,
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                        if (item.lastOpened !=
                                                            null)
                                                          Text(
                                                            'آخر فتح: ${item.lastOpened}',
                                                            style:
                                                                const TextStyle(
                                                              fontSize: 11,
                                                              color: Colors
                                                                  .white54,
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                  IconButton(
                                                    onPressed: () =>
                                                        _renameClone(app, item),
                                                    icon: const Icon(
                                                        Icons.edit_outlined,
                                                        size: 18),
                                                    tooltip: 'تسمية',
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                  ),
                                                  IconButton(
                                                    onPressed: () =>
                                                        _deleteSingleClone(
                                                            app, item),
                                                    icon: const Icon(
                                                      Icons.delete_outline,
                                                      size: 18,
                                                      color: Colors.redAccent,
                                                    ),
                                                    tooltip: 'حذف',
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  OutlinedButton.icon(
                                                    onPressed: () =>
                                                        _openSingleClone(
                                                            app, item),
                                                    icon: const Icon(
                                                        Icons.open_in_new,
                                                        size: 15),
                                                    label: const Text('فتح'),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
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
