import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:uuid/uuid.dart';
import 'package:hissab/data/database/app_database.dart';
import 'package:hissab/data/database/tables.dart';

class ContactItem {
  final String name;
  final String? phone;

  const ContactItem({
    required this.name,
    this.phone,
  });
}

/// Service providing device contact access, privacy protection, and book-specific contact history.
class ContactService {
  final AppDatabase _dbProvider = AppDatabase.instance;
  final Uuid _uuid = const Uuid();

  /// Records contact usage for the given book.
  Future<void> recordContactUsage({
    required String bookId,
    required String name,
    String? phone,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;

    final db = await _dbProvider.database;
    final now = DateTime.now().toIso8601String();

    final existing = await db.query(
      Tables.contactHistory,
      where: 'book_id = ? AND LOWER(name) = LOWER(?)',
      whereArgs: [bookId, cleanName],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final id = existing.first['id'] as String;
      final count = (existing.first['use_count'] as int? ?? 1) + 1;
      await db.update(
        Tables.contactHistory,
        {
          'use_count': count,
          'phone': phone ?? existing.first['phone'],
          'last_used_at': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      await db.insert(
        Tables.contactHistory,
        {
          'id': _uuid.v4(),
          'book_id': bookId,
          'name': cleanName,
          'phone': phone,
          'use_count': 1,
          'last_used_at': now,
        },
      );
    }
  }

  /// Retrieves frequently and recently used contacts for this book.
  Future<List<ContactItem>> getRecentContacts(String bookId, {int limit = 5}) async {
    final db = await _dbProvider.database;

    final rows = await db.query(
      Tables.contactHistory,
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'use_count DESC, last_used_at DESC',
      limit: limit,
    );

    return rows.map((r) => ContactItem(
      name: r['name'] as String,
      phone: r['phone'] as String?,
    )).toList();
  }

  /// Opens contact picker with search and privacy protection.
  /// Requests permission only when tapped on mobile devices.
  Future<ContactItem?> pickContact(BuildContext context, String bookId) async {
    final recents = await getRecentContacts(bookId);

    // If on Web or Desktop, device contact API is unavailable, show recents and manual entry modal
    final isMobile = !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

    List<Contact>? deviceContacts;

    if (isMobile) {
      try {
        final permission = await FlutterContacts.permissions.request(PermissionType.read);
        if (permission == PermissionStatus.granted) {
          deviceContacts = await FlutterContacts.getAll(
            properties: {ContactProperty.name, ContactProperty.phone},
          );
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Contacts permission denied. You can still enter the party name manually.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Error accessing contacts: $e');
      }
    }

    if (!context.mounted) return null;

    return await showModalBottomSheet<ContactItem>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ContactPickerSheet(
        deviceContacts: deviceContacts ?? [],
        recentContacts: recents,
      ),
    );
  }
}

class _ContactPickerSheet extends StatefulWidget {
  final List<Contact> deviceContacts;
  final List<ContactItem> recentContacts;

  const _ContactPickerSheet({
    required this.deviceContacts,
    required this.recentContacts,
  });

  @override
  State<_ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<_ContactPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchQuery.trim().toLowerCase();

    final filteredDevice = widget.deviceContacts.where((c) {
      if (query.isEmpty) return true;
      final name = (c.displayName ?? '').toLowerCase();
      final hasPhone = c.phones.any((p) => p.number.contains(query));
      return name.contains(query) || hasPhone;
    }).toList();

    final filteredRecents = widget.recentContacts.where((c) {
      if (query.isEmpty) return true;
      final name = c.name.toLowerCase();
      final phone = c.phone?.toLowerCase() ?? '';
      return name.contains(query) || phone.contains(query);
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(100),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Party / Contact',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search by name or phone...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    if (filteredRecents.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          'Recent Contacts',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      ...filteredRecents.map((item) => ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue.withAlpha(30),
                              child: Text(
                                item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                              ),
                            ),
                            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: item.phone != null ? Text(item.phone!) : null,
                            onTap: () => Navigator.pop(context, item),
                          )),
                      const Divider(height: 24),
                    ],

                    if (filteredDevice.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          'Device Contacts',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      ...filteredDevice.map((c) {
                        final phone = c.phones.isNotEmpty ? c.phones.first.number : null;
                        final name = c.displayName ?? 'Unknown';
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.indigo.withAlpha(30),
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                            ),
                          ),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: phone != null ? Text(phone) : null,
                          onTap: () => Navigator.pop(
                            context,
                            ContactItem(name: name, phone: phone),
                          ),
                        );
                      }),
                    ] else if (widget.deviceContacts.isEmpty && filteredRecents.isEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person_outline, size: 48, color: Colors.grey),
                              const SizedBox(height: 12),
                              const Text(
                                'No contacts found',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'You can enter the party name directly in the transaction form.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                              if (_searchQuery.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.check),
                                  label: Text('Use "$_searchQuery"'),
                                  onPressed: () => Navigator.pop(
                                    context,
                                    ContactItem(name: _searchQuery),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
