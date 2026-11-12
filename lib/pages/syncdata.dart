import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:emanifest/drawer/custom_drawer.dart';
import 'package:emanifest/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

// class _InfoText extends StatelessWidget {
//   final String label;
//   final String value;
//   final bool isBold;
//   final bool isHighlight;
//
//   const _InfoText({
//     required this.label,
//     required this.value,
//     this.isBold = false,
//     this.isHighlight = false,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 4),
//       child: RichText(
//         text: TextSpan(
//           style: const TextStyle(color: Colors.black),
//           children: [
//             TextSpan(text: "$label : "),
//             TextSpan(
//               text: value,
//               style: TextStyle(
//                 fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
//                 color: isHighlight ? Colors.blue : Colors.black,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }


class _DashboardPageState extends State<DashboardPage> {
  final TextEditingController _orderDateController = TextEditingController();
  final TextEditingController _pageNumberController = TextEditingController();
  String? _selectedPlantCode;
  String? _selectedOrderType;
  int _totalManifest = 0;
  int _totalKanban = 0;
  int _totalItem = 0;
  List<dynamic> _orderList = [];
  bool _isLoading = false;


  @override
  void dispose() {
    _orderDateController.dispose();
    super.dispose();
  }

  Future<void> _syncData() async {
    if (_orderDateController.text.isEmpty ||
        _selectedPlantCode == null ||
        _selectedOrderType == null ||
        _pageNumberController.text.isEmpty ||
        int.tryParse(_pageNumberController.text) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mohon lengkapi semua input')),
      );
      return;
    }

    String formattedDate = _orderDateController.text.replaceAll('-', '');
    String pageNumber = _pageNumberController.text;

    String supplierCode = 'T034';
    String supplierPlantCd = '1';
    String pageSize = '10';

    String url =
        'https://apihub.toyota.co.id/api/api/exec/tmmin.edcl/api/emanifest-api/0.1.0/api/v1/Order/daily-order'
        '?OrdDate=$formattedDate'
        '&SupplierCode=$supplierCode'
        '&SupplierPlantCd=$supplierPlantCd'
        '&RcvPlantCode=$_selectedPlantCode'
        '&OrderType=$_selectedOrderType'
        '&PageNumber=$pageNumber'
        '&PageSize=$pageSize';

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      setState(() {
        _isLoading = true;
      });

      final response = await AuthService().get(
        url
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        List<dynamic> dataList = jsonData['data'];

        for (var item in dataList) {
          item['formattedDate'] = formattedDate;
          item['order_type']  = _selectedOrderType;
          item['receiving_plant']  = _selectedPlantCode;
        }

        final insertResponse = await http.post(
          Uri.parse('http://192.168.10.55/sto/emanifest/get-daily-order'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: json.encode(dataList),
        );

        if (insertResponse.statusCode == 200) {
          final responseData = json.decode(insertResponse.body);

          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('Sync Berhasil'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Message: ${responseData['message']}'),
                    const SizedBox(height: 8),
                    Text('Inserted: ${responseData['inserted']}'),
                    Text('Failed: ${responseData['failed']}'),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Tutup'),
                  ),
                ],
              );
            },
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal insert ke server lokal: ${insertResponse.statusCode}')),
          );
        }

      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal sync data: ${response.statusCode}')),
        );
      }

    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi error saat sync: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  Future<void> _fetchDataFromAPI() async {
    if (_orderDateController.text.isEmpty ||
        _selectedPlantCode == null ||
        _selectedOrderType == null ||
        _pageNumberController.text.isEmpty ||
        int.tryParse(_pageNumberController.text) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mohon lengkapi semua input')),
      );
      return;
    }

    String formattedDate = _orderDateController.text.replaceAll('-', '');
    String pageNumber = _pageNumberController.text;

    String supplierCode = 'T034';
    String supplierPlantCd = '1';
    String pageSize = '10';

    String url =
        'https://apihub.toyota.co.id/api/api/exec/tmmin.edcl/api/emanifest-api/0.1.0/api/v1/Order/daily-order'
        '?OrdDate=$formattedDate'
        '&SupplierCode=$supplierCode'
        '&SupplierPlantCd=$supplierPlantCd'
        '&RcvPlantCode=$_selectedPlantCode'
        '&OrderType=$_selectedOrderType'
        '&PageNumber=$pageNumber'
        '&PageSize=$pageSize';

    try {
      setState(() {
        _isLoading = true;
      });

      final response = await AuthService().get(
        url
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _orderList = data['data'];
          _totalManifest = data['orderInfo']['totalManifest'];
          _totalKanban = data['orderInfo']['totalKanban'];
          _totalItem = data['paginationTotalInfo']['totalItem'];
          _isLoading = false;
        });

      } else {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal ambil data: ${response.statusCode}')),
        );
      }

    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi error: $e')),
      );
    }
  }

  Widget _buildInfoCard(String title, String value, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.symmetric(vertical: 6), // Spasi antar kartu
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildRowInfo(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label: ",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(value ?? '-'),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _buildInfoList() {
    return [
      {
        "title": "Total Manifest",
        "value": _totalManifest.toString(),
        "color": Colors.blue,
        "icon": Icons.local_shipping,
      },
      {
        "title": "Total Kanban",
        "value": _totalKanban.toString(),
        "color": Colors.green,
        "icon": Icons.qr_code,
      },
      {
        "title": "Total Item",
        "value": _totalItem.toString(),
        "color": Colors.orange,
        "icon": Icons.inventory,
      },
    ];
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text("Sync Database", style: TextStyle(
          fontWeight: FontWeight.bold,
        ),),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              final confirm = await showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('Konfirmasi Logout'),
                  content: Text('Apakah Anda yakin ingin logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text('Batal'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text('Logout'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                final success = await AuthService().logout();
                if (!context.mounted) return;
                if (success) {
                  Navigator.pushReplacementNamed(context, '/login');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Logout gagal")),
                  );
                }
              }
            },
          ),
        ],
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
      ),
      drawer: CustomDrawer(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFB2DFDB), Color(0xFFFFFFFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Container(
                    color: Colors.white,
                  ),
                ),
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Color(0xFF000099),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                ),
              ],
            ),
            SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Order Date
                        TextFormField(
                          controller: _orderDateController,
                          decoration: InputDecoration(
                            labelText: "Order Date",
                            labelStyle: TextStyle(color: Colors.blueAccent),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.blueAccent, width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.blueAccent, width: 2),
                            ),
                            prefixIcon: Icon(Icons.calendar_today, color: Colors.blueAccent),
                            contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                          ),
                          onTap: () async {
                            FocusScope.of(context).requestFocus(FocusNode());
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2101),
                            );
                            if (picked != null) {
                              _orderDateController.text = picked.toIso8601String().split('T').first;
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                decoration: InputDecoration(
                                  labelText: "Receiving Plant Code",
                                  labelStyle: TextStyle(color: Colors.blueAccent),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.blueAccent, width: 1),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.blueAccent, width: 2),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                                ),
                                items: ['1', '4', '5', '6']
                                    .map((code) => DropdownMenuItem(
                                  value: code,
                                  child: Text(code),
                                ))
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedPlantCode = value;
                                  });
                                },
                                value: _selectedPlantCode,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                decoration: InputDecoration(
                                  labelText: "Order Type",
                                  labelStyle: TextStyle(color: Colors.blueAccent),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.blueAccent, width: 1),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.blueAccent, width: 2),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                                ),
                                items: ['1', '2']
                                    .map((type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(type),
                                ))
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedOrderType = value;
                                  });
                                },
                                value: _selectedOrderType,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _pageNumberController,
                                decoration: InputDecoration(
                                  labelText: "Page Number",
                                  labelStyle: TextStyle(color: Colors.blueAccent),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.blueAccent, width: 1),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.blueAccent, width: 2),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.search),
                                label: const Text("Cari Data"),
                                onPressed: _fetchDataFromAPI,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF000099),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.sync),
                              label: const Text("Sync"),
                              onPressed: _syncData,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: _buildInfoList().length,
                    itemBuilder: (context, index) {
                      final item = _buildInfoList()[index];

                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(item['icon'], color: item['color'], size: 30),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['title'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(
                                      item['value'],
                                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: item['color']),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, size: 16),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            if (_isLoading)
              Opacity(
                opacity: 0.5,
                child: ModalBarrier(
                  dismissible: false,
                  color: Colors.black,
                ),
              ),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}

