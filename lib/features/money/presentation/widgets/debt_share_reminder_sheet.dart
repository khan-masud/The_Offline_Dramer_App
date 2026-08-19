import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/money_provider.dart';

enum ReminderTemplate {
  urgent,
  friendly,
  formal,
  short,
  custom,
}

class DebtShareReminderSheet extends ConsumerStatefulWidget {
  final Debt debt;

  const DebtShareReminderSheet({
    super.key,
    required this.debt,
  });

  @override
  ConsumerState<DebtShareReminderSheet> createState() => _DebtShareReminderSheetState();
}

class _DebtShareReminderSheetState extends ConsumerState<DebtShareReminderSheet> {
  late TextEditingController _messageCtrl;
  late TextEditingController _phoneCtrl;
  ReminderTemplate _selectedTemplate = ReminderTemplate.urgent;

  @override
  void initState() {
    super.initState();
    _phoneCtrl = TextEditingController(text: widget.debt.phone ?? '');
    _messageCtrl = TextEditingController(text: _generateMessage(ReminderTemplate.urgent));
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  String _fmt(double v) => v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);

  String _generateMessage(ReminderTemplate template) {
    final debt = widget.debt;
    final isGiven = debt.type == 'given';
    final remaining = debt.amount - debt.paidAmount;
    final remainingStr = '$currencySymbol${_fmt(remaining)}';
    final totalStr = '$currencySymbol${_fmt(debt.amount)}';
    final paidStr = '$currencySymbol${_fmt(debt.paidAmount)}';
    final dueStr = debt.dueDate != null ? DateFormat('d MMMM yyyy').format(debt.dueDate!) : 'শীঘ্রই';

    switch (template) {
      case ReminderTemplate.urgent:
        return isGiven
            ? 'প্রিয় ${debt.personName}, আপনি আমার থেকে টাকা ধার নিয়েছিলেন $totalStr টাকা, পরিশোধ করেছেন $paidStr টাকা, এখনও বাকি $remainingStr টাকা। বর্তমানে আমি খুবই সমস্যার মধ্যে আছি, আমিসহ বউ-বাচ্চাদের খুবই কষ্ট হচ্ছে। আপনি দয়া করে টাকাটা $dueStr তারিখের মধ্যে দিয়ে আমাকে ও আমার বউ-বাচ্চাকে এই বিপদ থেকে উদ্ধার করবেন নাহলে পরকালে দাবী থাকবে, ধন্যবাদ!'
            : 'প্রিয় ${debt.personName}, আপনার থেকে নেওয়া $totalStr টাকার ঋণের মধ্যে $paidStr টাকা পরিশোধ করা হয়েছে, অবশিষ্ট $remainingStr টাকা ইনশাআল্লাহ্ $dueStr তারিখের মধ্যে পরিশোধ করে নিজেকে দায়মুক্ত করব। আমার জন্য দোয়া করবেন এবং সহযোগিতার জন্য কৃতজ্ঞতা।';
      case ReminderTemplate.friendly:
        return isGiven
            ? 'আসসালামু আলাইকুম ${debt.personName}, আশা করি ভালো আছেন। আপনার কাছে পাওনা অবশিষ্ট $remainingStr টাকার (মোট: $totalStr, পরিশোধ: $paidStr) বিষয়টি মনে করিয়ে দিচ্ছি। আমি বউ-বাচ্চা নিয়ে খুবই অশান্তিতে আছি। আপনি টাকাটা পেলে হয়তো একটু মুক্তির স্বাদ পেতে পারতাম। সম্ভব হলে নির্দিষ্ট সময়ের মধ্যে দিলে খুব উপকৃত হতাম, নির্ধারিত তারিখ: $dueStr, ধন্যবাদ!'
            : 'আসসালামু আলাইকুম ${debt.personName}, আপনার কাছে থাকা ঋণের বকেয়া $remainingStr টাকা (মোট: $totalStr, পরিশোধ: $paidStr) আগামী $dueStr তারিখের মধ্যে পরিশোধ করার বিষয়টি আমার স্মরণে আছে। ধন্যবাদ আপনার সহানুভূতির জন্য!';
      case ReminderTemplate.formal:
        return isGiven
            ? 'হিসাব বিবরণী (Debt Statement):\nপ্রাপক: ${debt.personName}\nমোট পাওনা: $totalStr\nপরিশোধিত: $paidStr\nঅবশিষ্ট বকেয়া: $remainingStr\nনির্ধারিত পরিশোধের তারিখ: $dueStr\n\nঅনুগ্রহপূর্বক নির্ধারিত সময়ের মধ্যে বকেয়া টাকা পরিশোধের বিনীত অনুরোধ করা হলো।'
            : 'ঋণ স্বীকৃতি ও পরিশোধ প্রতিশ্রুতি:\nপ্রাপক: ${debt.personName}\nমোট ঋণ: $totalStr\nপরিশোধিত: $paidStr\nঅবশিষ্ট বকেয়া: $remainingStr\nপরিশোধের শেষ তারিখ: $dueStr\n\nনির্দিষ্ট তারিখের মধ্যে বকেয়া সম্পূর্ণ পরিশোধ করা হবে।';
      case ReminderTemplate.short:
        return isGiven
            ? 'রিমাইন্ডার: ${debt.personName}, বকেয়া $remainingStr (মোট $totalStr, পরিশোধ $paidStr)। শেষ সময়: $dueStr। দয়া করে দ্রুত পরিশোধ করবেন।'
            : 'হিসাব স্বীকারোক্তি: ${debt.personName}, বকেয়া $remainingStr (Due: $dueStr)। ইনশাআল্লাহ্ শীঘ্রই পরিশোধ করা হবে।';
      case ReminderTemplate.custom:
        return _messageCtrl.text;
    }
  }

  void _onTemplateChanged(ReminderTemplate template) {
    setState(() {
      _selectedTemplate = template;
      if (template != ReminderTemplate.custom) {
        _messageCtrl.text = _generateMessage(template);
      }
    });
  }

  String _cleanPhoneNumber(String phone) {
    return phone.replaceAll(RegExp(r'[^\d+]'), '');
  }

  Future<void> _sendWhatsApp() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;

    final rawPhone = _phoneCtrl.text.trim();
    final cleanPhone = _cleanPhoneNumber(rawPhone);

    Uri uri;
    if (cleanPhone.isNotEmpty) {
      String targetPhone = cleanPhone;
      if (targetPhone.startsWith('0') && targetPhone.length == 11) {
        targetPhone = '88$targetPhone';
      }
      uri = Uri.parse('https://wa.me/$targetPhone?text=${Uri.encodeComponent(text)}');
    } else {
      uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    }

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await Share.share(text, subject: 'Payment Reminder — ${widget.debt.personName}');
      }
    } catch (_) {
      await Share.share(text, subject: 'Payment Reminder — ${widget.debt.personName}');
    }
  }

  Future<void> _sendSMS() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;

    final cleanPhone = _cleanPhoneNumber(_phoneCtrl.text.trim());
    final uri = Uri(
      scheme: 'sms',
      path: cleanPhone,
      queryParameters: {'body': text},
    );

    try {
      final launched = await launchUrl(uri);
      if (!launched) {
        await Share.share(text, subject: 'Payment Reminder — ${widget.debt.personName}');
      }
    } catch (_) {
      await Share.share(text, subject: 'Payment Reminder — ${widget.debt.personName}');
    }
  }

  Future<void> _shareAny() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;
    await Share.share(text, subject: 'Payment Reminder — ${widget.debt.personName}');
  }

  void _copyToClipboard() {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _pickContact() async {
    final db = ref.read(databaseProvider);
    final contacts = await db.select(db.contactEntries).get();

    if (!mounted) return;

    if (contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No saved contacts found')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.55,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Text('Select Contact', style: AppTypography.headingSmall),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: contacts.length,
                itemBuilder: (ctx, i) {
                  final c = contacts[i];
                  return ListTile(
                    leading: CircleAvatar(child: Text(c.displayName.isNotEmpty ? c.displayName[0].toUpperCase() : 'C')),
                    title: Text(c.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(c.phone),
                    onTap: () {
                      setState(() => _phoneCtrl.text = c.phone);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isGiven = widget.debt.type == 'given';
    final remaining = widget.debt.amount - widget.debt.paidAmount;
    final accentColor = isGiven ? AppColors.error : AppColors.warning;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accentColor.withValues(alpha: 0.25)),
                    ),
                    child: Icon(Icons.share_rounded, color: accentColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isGiven ? 'Payment Reminder' : 'Payment Acknowledgement',
                          style: AppTypography.headingSmall.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.debt.personName} • Due: $currencySymbol${_fmt(remaining)}',
                          style: AppTypography.bodySmall.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Template Selection Section
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 14, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Select Template',
                    style: AppTypography.labelMedium.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _templateChip('Urgent', ReminderTemplate.urgent),
                    _templateChip('Friendly', ReminderTemplate.friendly),
                    _templateChip('Statement', ReminderTemplate.formal),
                    _templateChip('Quick', ReminderTemplate.short),
                    _templateChip('Custom', ReminderTemplate.custom),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Editable Message Area
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.edit_note_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(
                        'Message Preview & Edit',
                        style: AppTypography.labelMedium.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: _copyToClipboard,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.copy_rounded, size: 13, color: theme.colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Copy',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _messageCtrl,
                maxLines: 4,
                style: AppTypography.bodyMedium.copyWith(
                  color: theme.colorScheme.onSurface,
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  hintText: 'Type reminder message...',
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: isDark
                      ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
                      : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.25)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.25)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
                onChanged: (_) {
                  if (_selectedTemplate != ReminderTemplate.custom) {
                    setState(() => _selectedTemplate = ReminderTemplate.custom);
                  }
                },
              ),
              const SizedBox(height: 14),

              // Recipient Phone Number
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Recipient Phone (Optional for Direct Apps)',
                  hintText: 'e.g. +8801700000000',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.contacts_rounded),
                    tooltip: 'Pick from Contacts',
                    onPressed: _pickContact,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.25)),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Direct Channel Action Buttons
              Row(
                children: [
                  // WhatsApp Direct
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _sendWhatsApp,
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17),
                      label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // SMS Direct
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _sendSMS,
                      icon: const Icon(Icons.sms_outlined, size: 17),
                      label: const Text('SMS', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Share to any app
                  IconButton.filledTonal(
                    onPressed: _shareAny,
                    icon: const Icon(Icons.share_outlined, size: 18),
                    tooltip: 'Share via Other Apps',
                    style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _templateChip(String label, ReminderTemplate template) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = _selectedTemplate == template;
    return GestureDetector(
      onTap: () => _onTemplateChanged(template),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? theme.colorScheme.primary.withValues(alpha: 0.22)
                  : theme.colorScheme.primary.withValues(alpha: 0.14))
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline.withValues(alpha: 0.25),
            width: isSelected ? 1.4 : 0.9,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
