import 'package:flutter/material.dart';
import 'package:emanifest/drawer/custom_drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:emanifest/services/auth_service.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'history_combin_kanban.dart';
import 'dn_list.dart';

class KanbanMmki extends StatefulWidget {
  @override
  _KanbanMmkiPageState createState() => _KanbanMmkiPageState();
}

class _KanbanMmkiPageState extends State<KanbanMmki> {
  bool isFlashOn = false;
  bool _isSubmitting = false;
  bool _isLoading = false;
  List<dynamic> _historyKanban = [];
  final TextEditingController _customerKanbanController = TextEditingController();
  final TextEditingController _tagOkController = TextEditingController();

  @override
  void dispose() {
    _customerKanbanController.dispose();
    _tagOkController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    fetchHistoryKanban();
    _customerKanbanController.addListener(_checkIfBothFieldsAreFilled);
    _tagOkController.addListener(_checkIfBothFieldsAreFilled);
  }

  Future<void> fetchHistoryKanban() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    try {
      final response = await http.post(
        Uri.parse('http://192.168.10.55/sto/combin-kanban/history-kanban'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $token',
        },
        body: {
          'customer': 'MMKI',
          'quick': 'true'
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];
        setState(() {
          _historyKanban = data;
          _isLoading = false;
        });
      }
    } catch (e) {}
  }

  void _checkIfBothFieldsAreFilled() {
    final idLabel = _customerKanbanController.text.trim();
    final idKanban = _tagOkController.text.trim();

    if (idKanban.isNotEmpty && idLabel.isNotEmpty && !_isSubmitting) {
      _isSubmitting = true;
      _submitToApi(idKanban, idLabel).whenComplete(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _submitToApi(String idKanban, String idLabel) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('http://192.168.10.55/sto/combin-kanban/mmki-kanban'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $token',
        },
        body: {
          'id_kanban': idKanban,
          'id_label': idLabel,
        },
      );

      final data = jsonDecode(response.body);

      String detail = "${data['message']}\n\n"
          "DN : ${data['dn'] ?? '-'}\n"
          "Total Kanban : ${data['scanned'] ?? '-'} / ${data['total'] ?? '-'}\n";

      _showDialog(data['status'] ? 'Sukses' : 'Gagal', detail, data['status']);

      await fetchHistoryKanban();
      _customerKanbanController.clear();
      _tagOkController.clear();
    } catch (e) {
      _showDialog('Error', 'Terjadi kesalahan: $e', false);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showDialog(String title, String message, bool isSuccess) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.noHeader,
      animType: AnimType.scale,
      headerAnimationLoop: false,
      customHeader: Icon(
        isSuccess ? Icons.check_circle : Icons.error,
        color: isSuccess ? Colors.green : Colors.red,
        size: 100,
      ),
      title: title,
      desc: message,
      btnOkOnPress: () {},
      btnOkColor: isSuccess ? Colors.green : Colors.red,
    ).show();
  }

  void _ScannerCustomerKanban(BuildContext context) {
    bool isProcessing = false;
    final cameraController = MobileScannerController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          contentPadding: EdgeInsets.zero,
          content: Stack(
            children: [
              Container(
                width: 300,
                height: 400,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: MobileScanner(
                    controller: cameraController,
                    fit: BoxFit.cover,
                    onDetect: (capture) async {
                      if (isProcessing) return;
                      final codes = capture.barcodes;
                      for (final barcode in codes) {
                        final String? code = barcode.rawValue;
                        if (code != null) {
                          isProcessing = true;
                          await cameraController.stop();
                          Navigator.of(context).pop(code);
                        }
                      }
                    },
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    cameraController.dispose();
                    Navigator.of(context).pop();
                  },
                ),
              ),
              Positioned(
                bottom: 10,
                left: 10,
                child: IconButton(
                  icon: Icon(
                    isFlashOn ? Icons.flashlight_on : Icons.flashlight_off,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      isFlashOn = !isFlashOn;
                      cameraController.toggleTorch();
                    });
                  },
                ),
              ),
            ],
          ),
        );
      },
    ).then((scannedCode) {
      if (scannedCode != null && scannedCode is String) {
        _customerKanbanController.text = scannedCode;
      }
    });
  }

  void _ScannerTagOk(BuildContext context) {
    bool isProcessing = false;
    final cameraController = MobileScannerController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          contentPadding: EdgeInsets.zero,
          content: Stack(
            children: [
              Container(
                width: 300,
                height: 400,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: MobileScanner(
                    controller: cameraController,
                    fit: BoxFit.cover,
                    onDetect: (capture) async {
                      if (isProcessing) return;
                      final codes = capture.barcodes;
                      for (final barcode in codes) {
                        final String? code = barcode.rawValue;
                        if (code != null) {
                          isProcessing = true;
                          await cameraController.stop();
                          Navigator.of(context).pop(code);
                        }
                      }
                    },
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    cameraController.dispose();
                    Navigator.of(context).pop();
                  },
                ),
              ),
              Positioned(
                bottom: 10,
                left: 10,
                child: IconButton(
                  icon: Icon(
                    isFlashOn ? Icons.flashlight_on : Icons.flashlight_off,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      isFlashOn = !isFlashOn;
                      cameraController.toggleTorch();
                    });
                  },
                ),
              ),
            ],
          ),
        );
      },
    ).then((scannedCode) {
      if (scannedCode != null && scannedCode is String) {
        _tagOkController.text = scannedCode;
      }
    });
  }

  final Color primaryColor = Colors.teal;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: Text(
          "MMKI Kanban",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Scan Barcode", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 6, offset: Offset(0, 3)),
                    ],
                  ),
                  padding: EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Customer Kanban", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          SizedBox(height: 6),
                          TextField(
                            controller: _customerKanbanController,
                            autofocus: true,
                            decoration: InputDecoration(
                              labelText: "Barcode Customer Kanban",
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(Icons.camera_alt, color: primaryColor),
                                onPressed: () => _ScannerCustomerKanban(context),
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 12),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Tag OK / E - Kanban", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          SizedBox(height: 6),
                          TextField(
                            controller: _tagOkController,
                            decoration: InputDecoration(
                              labelText: "QR Code TAG OK / E - Kanban",
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(Icons.camera_alt, color: primaryColor),
                                onPressed: () => _ScannerTagOk(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16),
                Text("Menu Navigasi", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        elevation: 1,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.of(context).push(
                              PageRouteBuilder(
                                pageBuilder: (_, __, ___) => HistoryCombinKanban(sourcePage: "MMKI"),
                                transitionsBuilder: (_, animation, __, child) {
                                  return SlideTransition(
                                    position: Tween<Offset>(begin: Offset(-1, 0), end: Offset.zero).animate(animation),
                                    child: child,
                                  );
                                },
                              ),
                            );
                          },
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.history, size: 24, color: Colors.blueGrey),
                                SizedBox(height: 4),
                                Text("History", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        elevation: 1,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.of(context).push(
                              PageRouteBuilder(
                                pageBuilder: (_, __, ___) => DnList(source: 'MMKI'),
                                transitionsBuilder: (_, animation, __, child) {
                                  return SlideTransition(
                                    position: Tween<Offset>(begin: Offset(1, 0), end: Offset.zero).animate(animation),
                                    child: child,
                                  );
                                },
                              ),
                            );
                          },
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.local_shipping, size: 24, color: Colors.green),
                                SizedBox(height: 4),
                                Text("Delivery Notes", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 16),
                Text("5 Scan Terakhir", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),

                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 6, offset: Offset(0, 3)),
                    ],
                  ),
                  child: _historyKanban.isEmpty
                      ? Center(child: Text("Tidak ada data"))
                      : ListView.builder(
                    itemCount: _historyKanban.length > 5 ? 5 : _historyKanban.length,
                    itemBuilder: (context, index) {
                      final item = _historyKanban[index];
                      return ListTile(
                        title: Text(item['id_kanban'] ?? '-'),
                        subtitle: Text("Label: ${item['id_label'] ?? '-'}"),
                        trailing: Text(item['created_at'] ?? ''),
                      );
                    },
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

