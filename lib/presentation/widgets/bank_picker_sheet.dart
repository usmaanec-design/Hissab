import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hissab/core/constants/bank_catalog.dart';
import 'package:hissab/core/localization/app_localizations.dart';
import 'package:hissab/core/theme/app_colors.dart';
import 'package:hissab/domain/models/bank_logo_model.dart';
import 'package:hissab/presentation/widgets/book_avatar_widget.dart';

/// Modal bottom sheet or dialog to pick a Bank Logo, upload custom logo, or remove logo.
class BankPickerSheet extends StatefulWidget {
  final String currentLogo;
  final String bookName;
  final int bookColor;

  const BankPickerSheet({
    super.key,
    required this.currentLogo,
    required this.bookName,
    required this.bookColor,
  });

  /// Helper to open the picker as a bottom sheet or dialog
  static Future<String?> show(
    BuildContext context, {
    required String? currentLogo,
    required String bookName,
    required int bookColor,
  }) {
    final isWide = MediaQuery.of(context).size.width > 600;
    if (isWide) {
      return showDialog<String>(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
            child: BankPickerSheet(
              currentLogo: currentLogo ?? '',
              bookName: bookName,
              bookColor: bookColor,
            ),
          ),
        ),
      );
    } else {
      return showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => FractionallySizedBox(
          heightFactor: 0.88,
          child: BankPickerSheet(
            currentLogo: currentLogo ?? '',
            bookName: bookName,
            bookColor: bookColor,
          ),
        ),
      );
    }
  }

  @override
  State<BankPickerSheet> createState() => _BankPickerSheetState();
}

class _BankPickerSheetState extends State<BankPickerSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _selectedLogo = '';
  String _searchQuery = '';
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedLogo = widget.currentLogo;

    // Auto-select tab if current logo is a known bank
    if (_selectedLogo.startsWith('bank:') || _selectedLogo.startsWith('assets/banks/')) {
      final id = _selectedLogo.replaceFirst('bank:', '').replaceFirst('assets/banks/', '').replaceFirst('.png', '');
      final bank = BankCatalog.findById(id);
      if (bank != null) {
        _tabController.index = bank.country == 'pk' ? 1 : 0;
      }
    } else if (_selectedLogo.isNotEmpty) {
      _tabController.index = 2; // Custom
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _importCustomLogo() async {
    setState(() => _isImporting = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          // File size validation: max 5 MB
          if (file.bytes!.lengthInBytes > 5 * 1024 * 1024) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Image file too large. Please select an image under 5MB.')),
              );
            }
            return;
          }

          final ext = file.extension?.toLowerCase() ?? 'png';
          final b64 = base64Encode(file.bytes!);
          final dataUri = 'data:image/$ext;base64,$b64';

          setState(() {
            _selectedLogo = dataUri;
          });
          _tabController.animateTo(2);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import logo: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = loc.locale.languageCode;

    return Column(
      children: [
        // Top handle
        Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.only(top: 12, bottom: 8),
          decoration: BoxDecoration(
            color: Colors.grey.withAlpha(100),
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                loc.translate('bank.choose_logo'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        // Live Preview Section
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Row(
            children: [
              BookAvatarWidget(
                bookName: widget.bookName.isEmpty ? 'Hissab' : widget.bookName,
                bookColor: widget.bookColor,
                logo: _selectedLogo.isEmpty ? null : _selectedLogo,
                size: 50,
                borderRadius: 12,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.translate('bank.preview'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.bookName.isEmpty ? 'Book Preview' : widget.bookName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _selectedLogo.isEmpty
                          ? loc.translate('bank.hissab_avatar')
                          : _selectedLogo.startsWith('data:image')
                              ? loc.translate('bank.custom_imported')
                              : _getBankNamePreview(lang),
                      style: const TextStyle(fontSize: 12, color: AppColors.primaryLight),
                    ),
                  ],
                ),
              ),
              if (_selectedLogo.isNotEmpty)
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.moneyOut),
                  label: Text(
                    loc.translate('bank.remove_logo'),
                    style: const TextStyle(color: AppColors.moneyOut, fontSize: 12),
                  ),
                  onPressed: () {
                    setState(() => _selectedLogo = '');
                  },
                ),
            ],
          ),
        ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: loc.translate('bank.search_bank'),
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),

        // Tabs
        TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryLight,
          unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
          indicatorColor: AppColors.primaryLight,
          indicatorWeight: 3,
          tabs: [
            Tab(text: '🇸🇦 ${loc.translate('bank.saudi_arabia')}'),
            Tab(text: '🇵🇰 ${loc.translate('bank.pakistan')}'),
            Tab(text: '📁 ${loc.translate('bank.custom_logo')}'),
          ],
        ),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildBankGrid(BankCatalog.saudiBanks, lang, isDark),
              _buildBankGrid(BankCatalog.pakistanBanks, lang, isDark),
              _buildCustomLogoTab(loc, isDark),
            ],
          ),
        ),

        // Bottom Action Bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(loc.translate('common.cancel')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, _selectedLogo);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(loc.translate('common.save')),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getBankNamePreview(String lang) {
    final id = _selectedLogo.replaceFirst('bank:', '').replaceFirst('assets/banks/', '').replaceFirst('.png', '');
    final bank = BankCatalog.findById(id);
    if (bank != null) {
      return bank.getLocalizedName(lang);
    }
    return 'Bank Logo';
  }

  Widget _buildBankGrid(List<BankLogo> banks, String lang, bool isDark) {
    final filtered = _searchQuery.isEmpty
        ? banks
        : banks.where((b) {
            final q = _searchQuery.toLowerCase();
            return b.name.toLowerCase().contains(q) ||
                b.nameAr.toLowerCase().contains(q) ||
                b.nameUr.toLowerCase().contains(q) ||
                b.shortCode.toLowerCase().contains(q);
          }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'No banks found.',
          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final bank = filtered[i];
        final isSelected = _selectedLogo == 'bank:${bank.id}' ||
            _selectedLogo == bank.assetPath ||
            _selectedLogo == bank.id;

        return InkWell(
          onTap: () {
            setState(() {
              _selectedLogo = 'bank:${bank.id}';
            });
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryLight.withAlpha(25)
                  : isDark
                      ? AppColors.darkCard
                      : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? AppColors.primaryLight
                    : isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                width: isSelected ? 1.8 : 1,
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    bank.assetPath,
                    width: 44,
                    height: 44,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      width: 44,
                      height: 44,
                      color: Color(bank.brandColor),
                      alignment: Alignment.center,
                      child: Text(
                        bank.shortCode,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bank.getLocalizedName(lang),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        bank.name,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(bank.brandColor).withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    bank.shortCode,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(bank.brandColor),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                  color: isSelected ? AppColors.primaryLight : Colors.grey[400],
                  size: 22,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomLogoTab(AppLocalizations loc, bool isDark) {
    final hasCustom = _selectedLogo.startsWith('data:image') ||
        _selectedLogo.startsWith('file:') ||
        (!_selectedLogo.startsWith('bank:') && !_selectedLogo.startsWith('assets/') && _selectedLogo.isNotEmpty);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Column(
              children: [
                if (hasCustom)
                  Column(
                    children: [
                      BookAvatarWidget(
                        bookName: widget.bookName,
                        bookColor: widget.bookColor,
                        logo: _selectedLogo,
                        size: 80,
                        borderRadius: 20,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Custom Logo Loaded',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Saved locally for offline use.',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                    ],
                  )
                else
                  Column(
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, size: 54, color: AppColors.primaryLight.withAlpha(200)),
                      const SizedBox(height: 12),
                      Text(
                        loc.translate('bank.import_logo'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Import any bank or business logo from your gallery or files (PNG, JPG, WEBP).',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                    ],
                  ),
                ElevatedButton.icon(
                  onPressed: _isImporting ? null : _importCustomLogo,
                  icon: _isImporting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.file_upload_outlined),
                  label: Text(hasCustom ? 'Replace Custom Logo' : loc.translate('bank.import_logo')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    minimumSize: const Size(double.infinity, 46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withAlpha(15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline, size: 20, color: AppColors.primaryLight),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tip: You can search and download any official bank or business logo image in your browser, then tap "Import Logo" above to add it to your Book.',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[300] : Colors.grey[700], height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
