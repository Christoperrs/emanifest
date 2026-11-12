import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ShippingPrepCycle extends StatefulWidget {
  const ShippingPrepCycle({super.key});

  @override
  State<ShippingPrepCycle> createState() => _ShippingPrepCycleState();
}

class _ShippingPrepCycleState extends State<ShippingPrepCycle> {
  String? selectedCustomer;
  DateTime? selectedDate;
  String? selectedCycle;
  bool _isLoading = false;
  bool _hasSearched = false;

  final TextEditingController _dateController = TextEditingController();
  List<dynamic> _apiData = [];

  final Color primaryDark = const Color(0xFF1565C0);
  final Color primaryLight = const Color(0xFF1E88E5);
  final Color bgColor = const Color(0xFFF5F7FA);

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  // LOGIKA TANGGAL SESUAI CONTOH YANG BENAR
  Future<void> _pickDate() async {
    // 1. Tutup keyboard/fokus agar tidak mengganggu pemilih tanggal
    FocusScope.of(context).unfocus();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      // Opsional: Tema agar sesuai dengan warna primer Anda
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: primaryDark),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
        // 2. Format YYYY-MM-DD menggunakan split('T') seperti contoh pertama
        _dateController.text = picked.toIso8601String().split('T').first;
      });
    }
  }

  void _onCustomerChanged(String? value) {
    setState(() {
      selectedCustomer = value;
      selectedCycle = null;
    });
  }

  Future<void> _handleSearch() async {
    if (selectedCustomer == null || _dateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Customer dan tanggal wajib diisi")),
      );
      return;
    }

    if (selectedCustomer == "MMKI" && selectedCycle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cycle MMKI wajib dipilih")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      String endpoint;
      if (selectedCustomer == "DN4" || selectedCustomer == "DN5") {
        endpoint = "adm_list_shipping";
      } else {
        endpoint = "mieruka_shipping_customer";
      }

      // Mengambil string dari controller yang sudah terformat
      String dateString = _dateController.text;

      final response = await http.post(
        Uri.parse('http://192.168.10.55/sto/combin-kanban/$endpoint'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $token',
        },
        body: {
          'customer': selectedCustomer,
          'cycle': selectedCycle ?? '',
          'start_date': dateString,
          'end_date': dateString,
          'date': dateString,
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        setState(() {
          _apiData = responseData['data'] ?? [];
          _hasSearched = true;
        });
      } else {
        throw Exception("Server error: ${response.statusCode}");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          "Shipping Preparation",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: primaryDark,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: primaryDark))
                : _hasSearched
                ? (_apiData.isEmpty ? _buildEmptyResult() : _buildResultGrid())
                : _buildInitialState(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildDropdownField(
                  label: "Customer (Plant)",
                  hint: "Pilih",
                  value: selectedCustomer,
                  items: ["DN4", "DN5", "MKM", "TMMIN", "MMKI", "HMMI"],
                  onChanged: _onCustomerChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdownField(
                  label: "Cycle",
                  hint: "Cycle",
                  value: selectedCycle,
                  items: selectedCustomer == "MMKI"
                      ? ["1", "5"]
                      : (selectedCustomer == "MKM" ||
                      selectedCustomer == "TMMIN" ||
                      selectedCustomer == "HMMI")
                      ? []
                      : ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"],
                  onChanged: (val) {
                    if (selectedCustomer == "MKM" ||
                        selectedCustomer == "TMMIN" ||
                        selectedCustomer == "HMMI") return;
                    setState(() => selectedCycle = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),

          // TEXTFORMFIELD TANGGAL - DIBUAT SAMA DENGAN JOB LIST
          const Text("Delivery Date",
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          TextFormField(
            controller: _dateController,
            readOnly: true, // WAJIB: Agar user tidak mengetik
            onTap: _pickDate, // Fungsi yang sudah diperbaiki
            decoration: InputDecoration(
              hintText: "Klik untuk pilih tanggal",
              prefixIcon: Icon(Icons.calendar_month, color: primaryDark),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _handleSearch,
              icon: const Icon(Icons.search, color: Colors.white),
              label: const Text("CARI DATA",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryDark,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget pendukung lainnya tetap sama ...
  Widget _buildResultGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: _apiData.length,
      itemBuilder: (context, index) {
        final item = _apiData[index];
        bool isOk = item['FINISH'].toString() == "1";
        return Container(
          decoration: BoxDecoration(
            color: isOk ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isOk ? Colors.green : Colors.red),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isOk ? Icons.check_circle : Icons.pending_actions_rounded,
                  color: isOk ? Colors.green : Colors.red),
              const SizedBox(height: 8),
              Text("JOB: ${item['job_number']}",
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              Text("${item['scanned']}/${item['total']}",
                  style: const TextStyle(fontSize: 10)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyResult() => const Center(child: Text("Data tidak ditemukan"));
  Widget _buildInitialState() => const Center(child: Text("Gunakan filter untuk menampilkan data"));

  Widget _buildDropdownField({
    required String label,
    required String hint,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        DropdownButton<String>(
          value: value,
          hint: Text(hint, style: const TextStyle(fontSize: 14)),
          isExpanded: true,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: items.isEmpty ? null : onChanged,
        ),
      ],
    );
  }
}
