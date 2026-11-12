import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum TagOkPrefixFilter { all, maj, majwld }

class TagOkAutocomplete extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback onScan;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? customer;
  final Color primaryDark;
  final Color primaryLight;

  const TagOkAutocomplete({
    super.key,
    required this.controller,
    required this.hint,
    required this.onScan,
    this.onChanged,
    this.onSubmitted,
    this.customer,
    this.primaryDark = const Color(0xFF1565C0),
    this.primaryLight = const Color(0xFF1E88E5),
  });

  @override
  State<TagOkAutocomplete> createState() => _TagOkAutocompleteState();
}

class _TagOkAutocompleteState extends State<TagOkAutocomplete> {
  Timer? _debounce;
  bool _isLoading = false;
  List<Map<String, String>> _suggestions = [];
  String? _errorMessage;
  TagOkPrefixFilter _selectedFilter = TagOkPrefixFilter.all;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onTextChanged(String text) {
    widget.onChanged?.call(text);

    _debounce?.cancel();
    if (text.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _errorMessage = null;
        _isLoading = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () {
      _fetchSuggestions(text.trim());
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final url = Uri.parse('http://192.168.10.55/sto/combin-kanban/search-tag-ok');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: {
          'query': query,
          'customer': widget.customer ?? '',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true && data['data'] is List) {
          final List rawList = data['data'];
          final List<Map<String, String>> parsed = [];
          final Set<String> seenIds = {};

          for (var item in rawList) {
            if (item is String && item.trim().isNotEmpty) {
              final id = item.trim();
              if (!seenIds.contains(id)) {
                seenIds.add(id);
                parsed.add({'id_tag_ok': id, 'part_number': ''});
              }
            } else if (item is Map) {
              final id = (item['id_tag_ok'] ??
                      item['id_kanban'] ??
                      item['id_label'] ??
                      item['prod_order'] ??
                      '')
                  .toString()
                  .trim();
              final part = (item['part_number'] ?? item['part'] ?? '').toString().trim();
              if (id.isNotEmpty && !seenIds.contains(id)) {
                seenIds.add(id);
                parsed.add({'id_tag_ok': id, 'part_number': part});
              }
            }
          }

          if (mounted) {
            setState(() {
              _suggestions = parsed;
              _isLoading = false;
              if (parsed.isEmpty) {
                _errorMessage = 'Tidak ada Tag OK yang cocok';
              }
            });
          }
          return;
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Server error (${response.statusCode})';
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching Tag OK suggestions: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal terhubung ke backend';
        });
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, String>> get _filteredSuggestions {
    if (_selectedFilter == TagOkPrefixFilter.maj) {
      return _suggestions.where((item) {
        final upper = (item['id_tag_ok'] ?? '').toUpperCase();
        return upper.startsWith('MAJ') && !upper.startsWith('MAJWLD');
      }).toList();
    } else if (_selectedFilter == TagOkPrefixFilter.majwld) {
      return _suggestions.where((item) {
        final upper = (item['id_tag_ok'] ?? '').toUpperCase();
        return upper.startsWith('MAJWLD');
      }).toList();
    }
    return _suggestions;
  }

  void _selectSuggestion(String tagId) {
    widget.controller.text = tagId;
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: tagId.length),
    );
    setState(() {
      _suggestions = [];
      _errorMessage = null;
    });
    widget.onChanged?.call(tagId);
    widget.onSubmitted?.call(tagId);
  }

  @override
  Widget build(BuildContext context) {
    final activeSuggestions = _filteredSuggestions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Input Field
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: activeSuggestions.isNotEmpty ? widget.primaryDark : Colors.grey.shade200,
              width: activeSuggestions.isNotEmpty ? 1.5 : 1.0,
            ),
          ),
          child: TextField(
            controller: widget.controller,
            onChanged: _onTextChanged,
            onSubmitted: widget.onSubmitted,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLoading)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: widget.primaryDark,
                        ),
                      ),
                    ),
                  GestureDetector(
                    onTap: widget.onScan,
                    child: Container(
                      margin: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: widget.primaryLight.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(Icons.qr_code_scanner, color: widget.primaryDark, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Radio Filter Bar (Tepat setelah Tag OK Input)
        const SizedBox(height: 8),
        Row(
          children: [
            const Text("Filter Prefix:", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.black54)),
            const SizedBox(width: 8),
            _buildFilterRadio("Semua", TagOkPrefixFilter.all),
            const SizedBox(width: 4),
            _buildFilterRadio("MAJ", TagOkPrefixFilter.maj),
            const SizedBox(width: 4),
            _buildFilterRadio("MAJWLD", TagOkPrefixFilter.majwld),
          ],
        ),

        // Dropdown List Rekomendasi (Dengan Subtitle Part Number)
        if (activeSuggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: widget.primaryLight.withOpacity(0.4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: activeSuggestions.length,
                separatorBuilder: (ctx, i) => Divider(height: 1, color: Colors.grey.shade200),
                itemBuilder: (ctx, index) {
                  final item = activeSuggestions[index];
                  final tagId = item['id_tag_ok'] ?? '';
                  final partNo = item['part_number'] ?? '';

                  return Material(
                    color: Colors.transparent,
                    child: ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      leading: Icon(Icons.style, size: 18, color: widget.primaryDark),
                      title: Text(
                        tagId,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      subtitle: partNo.isNotEmpty
                          ? Text(
                              'Part: $partNo',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            )
                          : null,
                      trailing: Icon(Icons.north_west, size: 14, color: Colors.grey.shade400),
                      onTap: () => _selectSuggestion(tagId),
                    ),
                  );
                },
              ),
            ),
          ),

        // Message jika kosong / error
        if (_errorMessage != null && widget.controller.text.trim().isNotEmpty && !_isLoading && activeSuggestions.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.orange.shade800, fontSize: 11.5, fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }

  Widget _buildFilterRadio(String label, TagOkPrefixFilter filterValue) {
    final isSelected = _selectedFilter == filterValue;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = filterValue;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? widget.primaryDark : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 13,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

