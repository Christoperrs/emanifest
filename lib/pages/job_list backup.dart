import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:emanifest/drawer/custom_drawer.dart';
import 'package:emanifest/pages/detail_manifest_page.dart';
import 'package:emanifest/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class JobList extends StatefulWidget {
  const JobList({super.key});

  @override
  State<JobList> createState() => _JobListState();
}

class _InfoText extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final bool isHighlight;

  const _InfoText({
    required this.label,
    required this.value,
    this.isBold = false,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black),
          children: [
            TextSpan(text: "$label : "),
            TextSpan(
              text: value,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: isHighlight ? Colors.blue : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _JobListState extends State<JobList> {
  final TextEditingController _orderDateController = TextEditingController();
  TextEditingController _searchController = TextEditingController();
  List<dynamic> _filteredOrderList = [];
  String? _selectedPlantCode;
  String? _selectedOrderType;
  List<dynamic> _orderList = [];
  bool _isLoading = false;


  @override
  void dispose() {
    _orderDateController.dispose();
    super.dispose();
  }

  Future<void> _fetchDataFromAPI() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (_orderDateController.text.isEmpty || _selectedPlantCode == null || _selectedOrderType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mohon lengkapi semua input')),
      );
      return;
    }

    print('Order Date yang terkirim: ${_orderDateController.text}');

    try {
      setState(() {
        _isLoading = true;
      });

      final response = await http.post(
        Uri.parse('http://192.168.10.55/sto/emanifest/get-data-internal'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $token',
        },
        body: {
          'date': _orderDateController.text,
          'orderType': _selectedOrderType,
          'receiving_plant': _selectedPlantCode,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'error') {
          setState(() {
            _orderList = [];
            _isLoading = false;
          });

          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Tidak ada data'),
              content: Text(data['message']),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('OK'),
                ),
              ],
            ),
          );
        } else {
          setState(() {
            _orderList = data['data'];
            _filteredOrderList = _orderList;
            _isLoading = false;
          });
        }

      } else {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal ambil data: ${response.statusCode}')),
        );
      }

    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi error: $e')),
      );
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda yakin ingin logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await AuthService().logout();
      if (!mounted) return;
      if (success) {
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Logout gagal")),
        );
      }
    }
  }

  Future<void> _selectOrderDate() async {
    FocusScope.of(context).unfocus();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (picked != null) {
      _orderDateController.text = picked.toIso8601String().split('T').first;
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      _filteredOrderList = _orderList.where((item) {
        final manifestNumber = item['manifest_number']?.toString().toLowerCase() ?? '';
        return manifestNumber.contains(value.toLowerCase());
      }).toList();
    });
  }

  void _navigateToDetail(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailPage(orderData: item),
      ),
    );
  }

  // Widget _buildInfoCard(String title, String value, Color color) {
  //   return Card(
  //     elevation: 2,
  //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  //     child: Container(
  //       width: 100,
  //       padding: const EdgeInsets.all(5),
  //       child: Column(
  //         mainAxisSize: MainAxisSize.min,
  //         children: [
  //           Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
  //           const SizedBox(height: 5),
  //           Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
  //         ],
  //       ),
  //     ),
  //   );
  // }
  //
  // Widget _buildRowInfo(String label, String? value) {
  //   return Padding(
  //     padding: const EdgeInsets.only(bottom: 8),
  //     child: Row(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Text(
  //           "$label: ",
  //           style: const TextStyle(fontWeight: FontWeight.bold),
  //         ),
  //         Expanded(
  //           child: Text(value ?? '-'),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  final Color primaryColor = Colors.teal;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text(
          "Job List",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        elevation: 0,
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
          ),
        ],
      ),
      drawer: CustomDrawer(),

      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ================== Section: FILTER DATA ==================
                Text(
                  "Filter Data",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      )
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Order Date Field
                      Text(
                        "Order Date",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _orderDateController,
                        readOnly: true,
                        onTap: _selectOrderDate,
                        decoration: _inputDecoration("Pilih Tanggal"),
                      ),

                      const SizedBox(height: 16),

                      // Dropdown Row
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedPlantCode,
                              decoration: _inputDecoration("Receiving Plant Code"),
                              items: [
                                DropdownMenuItem(value: '1', child: Text('RV-01')),
                                DropdownMenuItem(value: '5', child: Text('RD40')),
                              ],
                              onChanged: (value) {
                                setState(() => _selectedPlantCode = value);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedOrderType,
                              decoration: _inputDecoration("Order Type"),
                              items: [
                                DropdownMenuItem(value: '1', child: Text('Regular')),
                                DropdownMenuItem(value: '2', child: Text('Emergency')),
                              ],
                              onChanged: (value) {
                                setState(() => _selectedOrderType = value);
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.search),
                          label: const Text("Cari Data"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          onPressed: _fetchDataFromAPI,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ================== Section: HASIL DATA ==================
                Text(
                  "Hasil Data",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      )
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Search Field
                      TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration: _inputDecoration('Cari Manifest Number').copyWith(
                          prefixIcon: Icon(Icons.search, color: primaryColor),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // List Items
                      if (_filteredOrderList.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text(
                              "Tidak ada data ditemukan",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: _filteredOrderList.length,
                          itemBuilder: (context, index) {
                            final item = _filteredOrderList[index];
                            return GestureDetector(
                              onTap: () => _navigateToDetail(item),
                              child: Card(
                                elevation: 2,
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            _InfoText(label: "Manifest No.", value: item['manifest_number'] ?? '', isHighlight: true),
                                            _InfoText(label: "Sub Route", value: item['subRouteCd'] ?? '', isBold: true),
                                            _InfoText(label: "Supplier Code", value: item['supplier_code'].toString(), isBold: true),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        children: const [
                                          Icon(Icons.more_vert, size: 16),
                                          Icon(Icons.more_vert, size: 16),
                                          Icon(Icons.more_vert, size: 16),
                                        ],
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            _InfoText(label: "Cycle", value: item['subRouteSeq'].toString(), isBold: true),
                                            _InfoText(label: "Kanban Scan", value: item['total_scanned_kanban'].toString(), isBold: true),
                                            _InfoText(label: "Total Kanban", value: item['total_kanban'].toString(), isBold: true),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.arrow_forward_ios, size: 16),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),

          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            )
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      fillColor: Colors.grey.shade50,
      filled: true,
      prefixIconColor: primaryColor,
    );
  }
}

