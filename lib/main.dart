

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

  Future<void> chooseImage(ImageSource source) async {
    try {
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          imagePath = image.path;
        });
      }
    } catch (e) {
      showMessage('خطا در انتخاب تصویر: $e');
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> saveBill() async {
    if (!formKey.currentState!.validate()) return;

    final date = dateController.text.trim();
    final parts = date.split('/');

    if (parts.length != 3 ||
        int.tryParse(parts[0]) == null ||
        int.tryParse(parts[1]) == null ||
        int.tryParse(parts[2]) == null) {
      showMessage('تاریخ را به شکل 1405/08/20 وارد کنید');
      return;
    }

    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);

    if (month < 1 ||
        month > 12 ||
        day < 1 ||
        day > (month <= 6 ? 31 : month <= 11 ? 30 : 30)) {
      showMessage('تاریخ واردشده معتبر نیست');
      return;
    }

    setState(() => saving = true);

    try {
      final data = <String, dynamic>{
        'type': selectedType,
        'amount': int.parse(amountController.text.replaceAll(',', '')),
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
      showMessage('ذخیره قبض انجام نشد: $e');
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
              ),
              items: ['برق', 'آب', 'گاز', 'تلفن']
                  .map(
                    (type) => DropdownMenuItem(
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
              ),
              validator: (value) {
                final amount = int.tryParse(
                  (value ?? '').replaceAll(',', ''),
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
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: paymentIdController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'شناسه پرداخت',
                prefixIcon: Icon(Icons.confirmation_number),
              ),
            ),
            const SizedBox(height: 18),

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

            if (imagePath != null && File(imagePath!).existsSync()) ...[
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
