import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TarikDataSapPage extends StatefulWidget {
  const TarikDataSapPage({super.key});

  @override
  State<TarikDataSapPage> createState() => _TarikDataSapPageState();
}

class _TarikDataSapPageState extends State<TarikDataSapPage> {
  final Color primaryDark = const Color(0xFF0D47A1);
  final Color primaryLight = const Color(0xFF1976D2);
  final Color bgColor = const Color(0xFFF8F9FD);

  String selectedCustomer = 'ADM';
  DateTime selectedDate = DateTime.now().add(const Duration(days: 1)); // Default: Besok
  bool isLoading = false;
  String? resultMessage;
  bool isSuccess = false;

  final TextEditingController _dateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _updateDateText();
  }

  void _updateDateText() {
    _dateController.text =
        "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: primaryDark),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        _updateDateText();
      });
    }
  }

  Future<void> _generateDataSap() async {
    final String formattedDate = _dateController.text.trim();
    if (formattedDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Silakan pilih tanggal terlebih dahulu.")),
      );
      return;
    }

    setState(() {
      isLoading = true;
      resultMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';

      Map<String, String> headers = {
        'Accept': 'application/json',
      };
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      late http.Response response;

      if (selectedCustomer == 'ADM') {
        // Endpoint ADM
        final url = Uri.parse(
          'http://192.168.10.67/majsf_rest_api/api/shipping/data?date=$formattedDate',
        );
        response = await http.get(url, headers: headers).timeout(
          const Duration(minutes: 5),
        );
      } else {
        // Endpoint TMMIN
        final url = Uri.parse(
          'http://192.168.10.67/majsf_rest_api/api/Report_delivery/delivery_detail_for_manifest?date=$formattedDate',
        );
        response = await http.get(url, headers: headers).timeout(
          const Duration(minutes: 5),
        );
      }

      final dynamic responseBody = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        String msg = "Data SAP $selectedCustomer berhasil ditarik!";
        if (selectedCustomer == 'ADM') {
          if (responseBody is Map && responseBody.containsKey('messages')) {
            msg = "${responseBody['messages']} (Total: ${responseBody['total_saved'] ?? responseBody['total_get'] ?? 0})";
          }
        } else {
          // TMMIN
          if (responseBody is List) {
            msg = "Data TMMIN tanggal $formattedDate berhasil disimpan (${responseBody.length} item).";
          } else if (responseBody is Map && responseBody.containsKey('messages')) {
            msg = responseBody['messages'].toString();
          }
        }

        setState(() {
          isLoading = false;
          isSuccess = true;
          resultMessage = msg;
        });

        _showResultDialog(
          title: "Berhasil",
          message: msg,
          success: true,
        );
      } else {
        String errorMsg = "Gagal generate data (HTTP ${response.statusCode})";
        if (responseBody is Map && responseBody.containsKey('messages')) {
          errorMsg = responseBody['messages'].toString();
        } else if (responseBody is Map && responseBody.containsKey('message')) {
          errorMsg = responseBody['message'].toString();
        }

        setState(() {
          isLoading = false;
          isSuccess = false;
          resultMessage = errorMsg;
        });

        _showResultDialog(
          title: "Gagal",
          message: errorMsg,
          success: false,
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        isSuccess = false;
        resultMessage = "Error: $e";
      });

      _showResultDialog(
        title: "Koneksi Error",
        message: "Terjadi kesalahan saat menghubungi server: $e",
        success: false,
      );
    }
  }

  void _showResultDialog({
    required String title,
    required String message,
    required bool success,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error,
              color: success ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: success ? Colors.green.shade800 : Colors.red.shade800,
              ),
            ),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: success ? primaryDark : Colors.grey.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("OK", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          "Tarik Data SAP",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryDark,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: primaryLight.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.cloud_download, color: primaryDark, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Sinkronisasi SAP ke DB",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                "Pilih customer dan tanggal untuk generate",
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 30),

                    // Dropdown Customer
                    const Text(
                      "Pilih Customer",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: selectedCustomer,
                          items: const [
                            DropdownMenuItem(
                              value: 'ADM',
                              child: Row(
                                children: [
                                  Icon(Icons.directions_car, color: Colors.indigo, size: 20),
                                  SizedBox(width: 10),
                                  Text("ADM (Daihatsu)"),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'TMMIN',
                              child: Row(
                                children: [
                                  Icon(Icons.local_shipping, color: Colors.red, size: 20),
                                  SizedBox(width: 10),
                                  Text("TMMIN (Toyota)"),
                                ],
                              ),
                            ),
                          ],
                          onChanged: isLoading
                              ? null
                              : (val) {
                                  if (val != null) {
                                    setState(() {
                                      selectedCustomer = val;
                                      resultMessage = null;
                                    });
                                  }
                                },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Pilih Tanggal
                    const Text(
                      "Pilih Tanggal Order/Delivery",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: isLoading ? null : _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_month, color: primaryDark, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _dateController.text,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),

                    // Tombol Generate
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _generateDataSap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryDark,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: isLoading
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    "Menghubungi SAP...",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.sync, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    "Generate Data SAP",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Tampilan Status Hasil
            if (resultMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                  border: Border.all(
                    color: isSuccess ? Colors.green.shade300 : Colors.red.shade300,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                      color: isSuccess ? Colors.green.shade700 : Colors.red.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        resultMessage!,
                        style: TextStyle(
                          color: isSuccess ? Colors.green.shade900 : Colors.red.shade900,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
