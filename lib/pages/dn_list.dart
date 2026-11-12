import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:ui';

class DnList extends StatefulWidget {
  final String source;
  const DnList({Key? key, required this.source}) : super(key: key);

  @override
  State<DnList> createState() => _DnListState();
}

class _DnListState extends State<DnList> {
  DateTimeRange? _selectedDateRange;
  List<dynamic> _historyData = [];
  bool _isLoading = false;
  String? _selectedCustomer;
  List<String> _customerOptions = [];

  // Theme Constants
  final Color primaryDark = const Color(0xFF0D47A1);
  final Color primaryLight = const Color(0xFF1976D2);
  final Color accentColor = const Color(0xFF00B0FF);
  final Color bgColor = const Color(0xFFF8F9FD);

  @override
  void initState() {
    super.initState();
    _initializeCustomerOptions();
  }

  void _initializeCustomerOptions() {
    if (widget.source == 'ADM') {
      _customerOptions = ['ADM PLANT 1', 'ADM PLANT 4', 'ADM PLANT 5'];
    } else if (widget.source == 'TMMIN') {
      _customerOptions = ['TMMIN'];
    } else {
      _customerOptions = ['HMMI', 'MKM', 'MMKI'];
    }
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
          DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
    );

    if (picked != null) setState(() => _selectedDateRange = picked);
  }

  Future<void> _callFilterApi(DateTime? start, DateTime? end, String? customer) async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return;

      final url = Uri.parse('http://192.168.10.55/sto/combin-kanban/dn-require');
      final Map<String, String> body = {};
      if (customer != null) body['customer'] = customer;
      if (start != null) body['start_date'] = start.toString();
      if (end != null) body['end_date'] = end.toString();

      final response = await http.post(url,
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Authorization': 'Bearer $token',
          },
          body: body);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        setState(() {
          _historyData = (decoded['status'] == true) ? decoded['data'] : [];
        });
      }
    } catch (e) {
      debugPrint('Exception: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("DN ${widget.source}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        backgroundColor: primaryDark,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: primaryDark))
                : _buildDataList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    String rangeText = _selectedDateRange == null
        ? "Pilih Tanggal"
        : "${_selectedDateRange!.start.toString().split(' ')[0]} - ${_selectedDateRange!.end.toString().split(' ')[0]}";

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: BoxDecoration(
        color: primaryDark,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Date Picker
                Expanded(
                  flex: 3,
                  child: InkWell(
                    onTap: _pickDateRange,
                    child: _buildFilterItem(Icons.calendar_month, "Rentang", rangeText),
                  ),
                ),
                const SizedBox(width: 10),
                // Customer Dropdown
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: const Text("Customer", style: TextStyle(fontSize: 12)),
                        value: _selectedCustomer,
                        items: _customerOptions.map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))
                        )).toList(),
                        onChanged: (v) => setState(() => _selectedCustomer = v),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  if (_selectedDateRange != null && _selectedCustomer != null) {
                    _callFilterApi(_selectedDateRange!.start, _selectedDateRange!.end, _selectedCustomer);
                  }
                },
                child: const Text("CARI PENGIRIMAN", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterItem(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: primaryDark),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataList() {
    if (_historyData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text("Tidak ada data ditemukan", style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _historyData.length,
      itemBuilder: (context, index) {
        final item = _historyData[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: InkWell(
            onTap: () => _showKanbanBottomSheet(context, item['BSTNK'], item['kanban'] ?? []),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: primaryLight.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.local_shipping_rounded, color: primaryDark),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['BSTNK'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.business, size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(item['CUSTOMER'] ?? '-', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(item['VDATU'] ?? '-', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryLight)),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showKanbanBottomSheet(BuildContext context, String bstnk, List kanbanList) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(backgroundColor: primaryDark, child: const Icon(Icons.qr_code_2, color: Colors.white)),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Detail Kanban", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        Text("BSTNK: $bstnk", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: kanbanList.length,
                  itemBuilder: (_, idx) {
                    final item = kanbanList[idx];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['barcode'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildMiniDetail("PART NO", item['part_number']),
                              _buildMiniDetail("JOB NO", item['job_number']),
                              _buildMiniDetail("QTY", item['qty'].toString()),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniDetail(String label, String? value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
        Text(value ?? '-', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
