
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BillManagerApp());
}

class BillManagerApp extends StatelessWidget {
  const BillManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'مدیریت قبض‌ها',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F8F5),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: HomePage(),
      ),
    );
  }
}

// تاریخ امروز شمسی
String todayJalali() {
  final date = Jalali.now();
  return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
}

// جداکننده سه‌رقمی مبلغ
String formatMoney(dynamic value) {
  final number = int.tryParse(value.toString()) ?? 0;
  return number.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );
}

// پایگاه داده محلی
class BillDatabase {
  static final BillDatabase instance = BillDatabase._();
  static Database? _database;

  BillDatabase._();

  Future<Database> get database async {
    if (_database != null) return _database!;

    final dbPath = await getDatabasesPath();
    final dbFile = join(dbPath, 'bills.db');

    _database = await openDatabase(
      dbFile,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE bills (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            amount INTEGER NOT NULL,
            date TEXT NOT NULL,
            billId TEXT,
            paymentId TEXT,
            paid INTEGER NOT NULL DEFAULT 0,
            imagePath TEXT
          )
        ''');
      },
    );

    return _database!;
  }

  Future<List<Map<String, dynamic>>> getBills() async {
    final db = await database;
    return db.query('bills', orderBy: 'id DESC');
  }

  Future<void> saveBill(Map<String, dynamic> bill) async {
    final db = await database;

    if (bill['id'] == null) {
      await db.insert('bills', bill);
    } else {
      final id = bill['id'];
      final data = Map<String, dynamic>.from(bill)..remove('id');

      await db.update(
        'bills',
        data,
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> deleteBill(int id) async {
    final db = await database;
    await db.delete(
      'bills',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

// صفحه اصلی
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> bills = [];
  bool loading = true;
  String selectedFilter = 'همه';

  @override
  void initState() {
    super.initState();
    loadBills();
  }

  Future<void> loadBills() async {
    try {
      final result = await BillDatabase.instance.getBills();

      if (!mounted) return;

      setState(() {
        bills = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      showMessage('خطا در دریافت قبض‌ها: $e');
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> openForm([Map<String, dynamic>? bill]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BillFormPage(bill: bill),
      ),
    );

    loadBills();
  }

  Future<void> deleteBill(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف قبض'),
        content: const Text('آیا از حذف این قبض مطمئن هستید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await BillDatabase.instance.deleteBill(id);
      await loadBills();
      showMessage('قبض حذف شد');
    }
  }

  Future<void> togglePaid(Map<String, dynamic> bill) async {
    final updated = Map<String, dynamic>.from(bill);
    updated['paid'] = bill['paid'] == 1 ? 0 : 1;

    await BillDatabase.instance.saveBill(updated);
    await loadBills();
  }

  int get monthlyTotal {
    final now = Jalali.now();
    final prefix =
        '${now.year}/${now.month.toString().padLeft(2, '0')}/';

    return bills
        .where((bill) =>
            bill['paid'] == 1 &&
            bill['date'].toString().startsWith(prefix))
        .fold<int>(
          0,
          (sum, bill) => sum + (bill['amount'] as int),
        );
  }

  List<Map<String, dynamic>> get filteredBills {
    if (selectedFilter == 'پرداخت‌شده') {
      return bills.where((b) => b['paid'] == 1).toList();
    }

    if (selectedFilter == 'پرداخت‌نشده') {
      return bills.where((b) => b['paid'] == 0).toList();
    }

    if (['برق', 'آب', 'گاز', 'تلفن'].contains(selectedFilter)) {
      return bills.where((b) => b['type'] == selectedFilter).toList();
    }

    return bills;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'مدیریت قبض‌ها',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: loadBills,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openForm(),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('ثبت قبض جدید'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadBills,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _summaryCard(),
                  const SizedBox(height: 20),
                  const Text(
                    'فیلتر قبض‌ها',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 45,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        'همه',
                        'پرداخت‌شده',
                        'پرداخت‌نشده',
                        'برق',
                        'آب',
                        'گاز',
                        'تلفن',
                      ].map((filter) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ChoiceChip(
                            label: Text(filter),
                            selected: selectedFilter == filter,
                            onSelected: (_) {
                              setState(() {
                                selectedFilter = filter;
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'فهرست قبض‌ها (${filteredBills.length})',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (filteredBills.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(
                        child: Text('هنوز قبضی ثبت نشده است'),
                      ),
                    )
                  else
                    ...filteredBills.map(_billCard),
                  const SizedBox(height: 90),
                ],
              ),
            ),
    );
  }

  Widget _summaryCard() {
    return Card(
      color: Colors.green,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'مجموع پرداخت‌های ماه جاری',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${formatMoney(monthlyTotal)} تومان',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'تعداد کل قبض‌ها: ${bills.length}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _billCard(Map<String, dynamic> bill) {
    final paid = bill['paid'] == 1;
    final imagePath = bill['imagePath']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.green.shade50,
                  child: Icon(
                    _billIcon(bill['type']),
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'قبض ${bill['type']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text('تاریخ: ${bill['date']}'),
                    ],
                  ),
                ),
                Text(
                  paid ? 'پرداخت‌شده' : 'پرداخت‌نشده',
                  style: TextStyle(
                    color: paid ? Colors.green : Colors.orange,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Divider(height: 22),
            Row(
              children: [
                const Text('مبلغ: '),
                Expanded(
                  child: Text(
                    '${formatMoney(bill['amount'])} تومان',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (imagePath.isNotEmpty &&
                    File(imagePath).existsSync())
                  IconButton(
                    tooltip: 'مشاهده تصویر قبض',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          child: Image.file(File(imagePath)),
                        ),
                      );
                    },
                    icon: const Icon(Icons.image),
                  ),
              ],
            ),
            if ((bill['billId'] ?? '').toString().isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: Text('شناسه قبض: ${bill['billId']}'),
              ),
            if ((bill['paymentId'] ?? '').toString().isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: Text('شناسه پرداخت: ${bill['paymentId']}'),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Flexible(
                  child: TextButton.icon(
                    onPressed: () => togglePaid(bill),
                    icon: Icon(
                      paid ? Icons.undo : Icons.check_circle_outline,
                    ),
                    label: Text(
                      paid ? 'پرداخت‌نشده شود' : 'ثبت پرداخت',
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'ویرایش',
                  onPressed: () => openForm(bill),
                  icon: const Icon(Icons.edit, color: Colors.blue),
                ),
                IconButton(
                  tooltip: 'حذف',
                  onPressed: () => deleteBill(bill['id'] as int),
                  icon: const Icon(Icons.delete, color: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _billIcon(String type) {
    switch (type) {
      case 'برق':
        return Icons.electric_bolt;
      case 'آب':
        return Icons.water_drop;
      case 'گاز':
        return Icons.local_fire_department;
      default:
        return Icons.phone;
    }
  }
}

// صفحه ثبت و ویرایش قبض
class BillFormPage extends StatefulWidget {
  final Map<String, dynamic>? bill;

  const BillFormPage({super.key, this.bill});

  @override
  State<BillFormPage> createState() => _BillFormPageState();
}

class _BillFormPageState extends State<BillFormPage> {
  final formKey = GlobalKey<FormState>();

  final amountController = TextEditingController();
  final dateController = TextEditingController();
  final billIdController = TextEditingController();
  final paymentIdController = TextEditingController();

  final ImagePicker picker = ImagePicker();

  String selectedType = 'برق';
  String? imagePath;
  bool paid = false;
  bool saving = false;

  @override
  void initState() {
    super.initState();

    final bill = widget.bill;

    if (bill != null) {
      selectedType = bill['type'];
      amountController.text = bill['amount'].toString();
      dateController.text = bill['date'];
      billIdController.text = bill['billId'] ?? '';
      paymentIdController.text = bill['paymentId'] ?? '';
      paid = bill['paid'] == 1;
      imagePath = bill['imagePath'];
    } else {
      dateController.text = todayJalali();
    }
  }

  @override
  void dispose() {
    amountController.dispose();
    dateController.dispose();
    billIdController.dispose();
    paymentIdController.dispose();
    super.dispose();
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> chooseImage(ImageSource source) async {
    try {
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (image != null && mounted) {
        setState(() {
          imagePath = image.path;
        });
      }
    } catch (e) {
      if (mounted) {
        showMessage('خطا در انتخاب تصویر: $e');
      }
    }
  }

  Future<void> saveBill() async {
    if (!formKey.currentState!.validate()) return;

    final date = dateController.text.trim();
    final parts = date.split('/');

    if (parts.length != 3) {
      showMessage('تاریخ را مانند 1405/08/20 وارد کنید');
      return;
    }

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);

    if (year == null ||
        month == null ||
        day == null ||
        year < 1200 ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > (month <= 6 ? 31 : month <= 11 ? 30 : 30)) {
      showMessage('تاریخ واردشده معتبر نیست');
      return;
    }

    final amount = int.tryParse(
      amountController.text.replaceAll(',', '').trim(),
    );

    if (amount == null || amount <= 0) {
      showMessage('مبلغ معتبر وارد کنید');
      return;
    }

    setState(() => saving = true);

    try {
      final data = <String, dynamic>{
        'type': selectedType,
        'amount': amount,
        'date': date,
        'billId': billIdController.text.trim(),
        'paymentId': paymentIdController.text.trim(),
        'paid': paid ? 1 : 0,
        'imagePath': imagePath,
      };

      if (widget.bill != null) {
        data['id'] = widget.bill!['id'];
      }

      await BillDatabase.instance.saveBill(data);

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        showMessage('ذخیره قبض انجام نشد: $e');
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.bill == null ? 'ثبت قبض جدید' : 'ویرایش قبض',
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              value: selectedType,
              decoration: const InputDecoration(
                labelText: 'نوع قبض',
                prefixIcon: Icon(Icons.receipt_long),
                border: OutlineInputBorder(),
              ),
              items: ['برق', 'آب', 'گاز', 'تلفن']
                  .map(
                    (type) => DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => selectedType = value);
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'مبلغ قبض به تومان',
                prefixIcon: Icon(Icons.payments),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final amount = int.tryParse(
                  (value ?? '').replaceAll(',', '').trim(),
                );

                if (amount == null || amount <= 0) {
                  return 'مبلغ معتبر وارد کنید';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: dateController,
              keyboardType: TextInputType.datetime,
              decoration: const InputDecoration(
                labelText: 'تاریخ شمسی',
                hintText: '1405/08/20',
                prefixIcon: Icon(Icons.calendar_month),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'تاریخ را وارد کنید';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: billIdController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'شناسه قبض',
                prefixIcon: Icon(Icons.numbers),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: paymentIdController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'شناسه پرداخت',
                prefixIcon: Icon(Icons.confirmation_number),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('این قبض پرداخت شده است'),
              value: paid,
              activeColor: Colors.green,
              onChanged: (value) {
                setState(() => paid = value);
              },
            ),
            const Divider(height: 25),
            const Text(
              'تصویر قبض',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => chooseImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('دوربین'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => chooseImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('گالری'),
                  ),
                ),
              ],
            ),
            if (imagePath != null &&
                File(imagePath!).existsSync()) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(imagePath!),
                  height: 180,
                  fit: BoxFit.contain,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() => imagePath = null);
                },
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text('حذف تصویر'),
              ),
            ],
            const SizedBox(height: 25),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: saving ? null : saveBill,
                icon: const Icon(Icons.save),
                label: Text(
                  saving ? 'در حال ذخیره...' : 'ذخیره قبض',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
