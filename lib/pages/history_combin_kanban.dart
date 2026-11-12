import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:ui';

class HistoryCombinKanban extends StatefulWidget {
  final String sourcePage;
  const HistoryCombinKanban({super.key, required this.sourcePage});

  @override
  State<HistoryCombinKanban> createState() => _HistoryCombinKanbanState();
}

class _HistoryCombinKanbanState extends State<HistoryCombinKanban> {
  DateTimeRange? _selectedDateRange;
  List<dynamic> _historyData = [];
  bool _isLoading = false;

  // Theme Colors
  final Color primaryDark = const Color(0xFF0D47A1);
  final Color primaryLight = const Color(0xFF1976D2);
  final Color accentColor = const Color(0xFF00B0FF);
  final Color bgColor = const Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    // Load current data on start
    _callFilterApi(null, null);
  }

  void _pickDateRange() async {
    final now = DateTime.now();
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2022),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: primaryDark),
          ),
          child: child!,
        );
      },
      initialDateRange: _selectedDateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          ),
    );

    if (picked != null) {
      setState(() => _selectedDateRange = picked);
    }
  }

  Future<void> _callFilterApi(DateTime? start, DateTime? end) async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null) return;

      final url = Uri.parse('http://192.168.10.55/sto/combin-kanban/history-kanban');
      final Map<String, String> body = {'customer': widget.sourcePage};
      if (start != null) body['start_date'] = start.toString();
      if (end != null) body['end_date'] = end.toString();

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        setState(() {
          _historyData = (decoded['status'] == true) ? decoded['data'] : [];
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          // Elegant Sliver AppBar with Gradient
          SliverAppBar(
            expandedHeight: 120.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                "Riwayat ${widget.sourcePage}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryDark, primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),

          // Filter Section
          SliverToBoxAdapter(
            child: _buildFilterSection(),
          ),

          // Data List Section
          _isLoading
              ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
              : _historyData.isEmpty
              ? SliverFillRemaining(child: _buildEmptyState())
              : SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildHistoryCard(_historyData[index]),
                childCount: _historyData.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    String rangeText = _selectedDateRange == null
        ? "Tentukan Tanggal"
        : "${_selectedDateRange!.start.toString().split(' ')[0]} - ${_selectedDateRange!.end.toString().split(' ')[0]}";

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: _pickDateRange,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.date_range_rounded, color: primaryDark),
                  const SizedBox(width: 12),
                  Text(rangeText, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const Spacer(),
                  const Icon(Icons.arrow_drop_down, color: Colors.grey),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  "FILTER",
                  Icons.search_rounded,
                  accentColor,
                      () {
                    if (_selectedDateRange != null) {
                      _callFilterApi(_selectedDateRange!.start, _selectedDateRange!.end);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  "RESET",
                  Icons.refresh_rounded,
                  primaryDark,
                      () => _callFilterApi(null, null),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
    );
  }

  Widget _buildHistoryCard(dynamic item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white), // Untuk efek elevasi lembut
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Left Indicator Accent
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: primaryLight,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), bottomLeft: Radius.circular(15)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item['id_label'] ?? '-',
                          style: TextStyle(fontWeight: FontWeight.bold, color: primaryDark, fontSize: 14),
                        ),
                        Text(
                          item['created_at']?.toString().split(' ')[0] ?? '-',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    _buildInfoRow(Icons.settings_suggest_outlined, "Part No", item['part']),
                    const SizedBox(height: 4),
                    _buildInfoRow(Icons.tag_rounded, "ID Kanban", item['id_kanban']),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 14, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(
                          item['created_at']?.toString().split(' ')[1] ?? '-',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String? value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.blueGrey),
        const SizedBox(width: 8),
        Text("$label: ", style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
        Expanded(
          child: Text(
            value ?? '-',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off_rounded, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "Belum ada data riwayat",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            "Gunakan filter untuk mencari data spesifik",
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
