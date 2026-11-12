import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:emanifest/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ScanKanbanPage extends StatefulWidget {
  final String manifestNo;
  const ScanKanbanPage({Key? key, required this.manifestNo}) : super(key: key);

  @override
  _ScanKanbanPageState createState() => _ScanKanbanPageState();
}

class _ScanKanbanPageState extends State<ScanKanbanPage> {
  bool isFlashOn = false;
  MobileScannerController cameraController = MobileScannerController();

  TextEditingController manualInputController = TextEditingController();
  bool isProcessing = false;
  int kanbanTotal = 0;
  int kanbanConfirm = 0;
  String skidNumber = "";

  @override
  void initState() {
    super.initState();
    _fetchKanbanTotal();
    _fetchIdSkid();
  }

  @override
  void dispose() {
    cameraController.stop();
    super.dispose();
  }

  Future<void> _confirmManifest(BuildContext rootContext, String noManifest, String skidNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    try {
      final response = await http.post(
        Uri.parse('http://192.168.10.55/sto/emanifest/confirm-manifest'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $token',
        },
        body: {
          'noManifest': noManifest,
          'noSkid': skidNumber,
        },
      );

      if (response.statusCode == 200) {
        print('Manifest berhasil dikonfirmasi');

        showDialog(
          context: rootContext,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: Text('Konfirmasi'),
              content: Text('Konfirmasi Manifest TMMIN?'),
              actions: <Widget>[
                TextButton(
                  child: Text('No'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
                TextButton(
                  child: Text('Yes'),
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();

                    await Future.delayed(Duration(milliseconds: 100));

                    try {
                      showDialog(
                        context: rootContext,
                        barrierDismissible: false,
                        builder: (BuildContext context) {
                          return Center(
                            child: CircularProgressIndicator(),
                          );
                        },
                      );

                      final apiUrlConfirm = 'https://apihub.toyota.co.id/api/api/exec/tmmin.edcl/api/emanifest-api/0.1.0/api/v1/ManifestCompleteness/confirm';
                      final List<dynamic> bodyData = jsonDecode(response.body);

                      final responseTMMIN = await AuthService().post(apiUrlConfirm, bodyData);
                      final Map<String, dynamic> responseJson = jsonDecode(responseTMMIN.body);
                      final String message = responseJson['message'] ?? 'Tidak ada pesan';

                      Navigator.of(rootContext, rootNavigator: true).pop();

                      if (responseTMMIN.statusCode == 200) {
                        if (message.contains("Success")) {
                          final prefs = await SharedPreferences.getInstance();
                          final token = prefs.getString('jwt_token');

                          try {
                            final localApiUrl = Uri.parse('http://192.168.10.55/sto/emanifest/confirm-flag');

                            final localResponse = await http.post(
                              localApiUrl,
                              headers: {'Content-Type': 'application/x-www-form-urlencoded', 'Authorization': 'Bearer $token',},
                              body: {
                                'noManifest': noManifest,
                                'noSkid': skidNumber,
                              },
                            );
                            print('Response lokal: ${localResponse.statusCode} - ${localResponse.body}');
                          } catch (e) {
                            print('Error saat memanggil API lokal confirm-flag: $e');
                          }

                          showDialog(
                            context: rootContext,
                            builder: (BuildContext context2) {
                              return AlertDialog(
                                title: Text('Berhasil'),
                                content: Text(message),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context2).pop();
                                      // Navigator.of(rootContext).pushReplacementNamed('/joblist');
                                    },
                                    child: Text('OK'),
                                  ),
                                ],
                              );
                            },
                          );
                        } else if (message.contains("Failed")) {
                          showDialog(
                            context: rootContext,
                            builder: (BuildContext context2) {
                              return AlertDialog(
                                title: Text('Gagal'),
                                content: Text(message),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context2).pop(),
                                    child: Text('Tutup'),
                                  ),
                                ],
                              );
                            },
                          );
                        } else {
                          showDialog(
                            context: rootContext,
                            builder: (BuildContext context2) {
                              return AlertDialog(
                                title: Text('Respon Tidak Dikenal'),
                                content: Text(message),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context2).pop(),
                                    child: Text('OK'),
                                  ),
                                ],
                              );
                            },
                          );
                        }
                      } else {
                        showDialog(
                          context: rootContext,
                          builder: (BuildContext context2) {
                            return AlertDialog(
                              title: Text('Error'),
                              content: Text('Terjadi kesalahan saat menghubungi server.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context2).pop(),
                                  child: Text('Tutup'),
                                ),
                              ],
                            );
                          },
                        );
                      }
                    } catch (e) {
                      Navigator.of(rootContext, rootNavigator: true).pop();
                      showDialog(
                        context: rootContext,
                        builder: (BuildContext context2) {
                          return AlertDialog(
                            title: Text('Error'),
                            content: Text('Data Gagal Terkirim'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context2).pop(),
                                child: Text('Tutup'),
                              ),
                            ],
                          );
                        },
                      );
                      print('Error saat konfirmasi ke TMMIN: $e');
                    }
                  },
                ),
              ],
            );
          },
        );
      } else {
        print('Gagal konfirmasi manifest: ${response.statusCode}');
      }
    } catch (e) {
      print('Error saat konfirmasi manifest: $e');
    }
  }

  Future<void> _confirmKanban(String barcode, String noManifest, String skidNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    try {
      setState(() {
        isProcessing = true;
      });

      final response = await http.post(
        Uri.parse('http://192.168.10.55/sto/emanifest/confirm-kanban'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $token',
        },
        body: {
          'kanbanId': barcode,
          'noManifest': noManifest,
          'no_Skid': skidNumber,
        },
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['status'] == 'success') {
        print('Data berhasil dikirim ke API');
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Sukses'),
              content: Text(responseData['message']),
              actions: <Widget>[
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _fetchKanbanTotal();
                    await cameraController.start();
                    setState(() {
                      isProcessing = false;
                    });
                  },
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
      } else {
        print('Gagal mengirim data ke API: ${responseData['message']}');
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Error'),
              content: Text(responseData['message']),
              actions: <Widget>[
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await cameraController.start();
                    setState(() {
                      isProcessing = false;
                    });
                  },
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      print('Error: $e');
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Error'),
            content: Text('Terjadi kesalahan. Coba lagi nanti.'),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    isProcessing = false;
                  });
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }


  Future<void> _fetchKanbanTotal() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    try {
      final response = await http.post(
        Uri.parse('http://192.168.10.55/sto/emanifest/get-qty-kanban'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $token',
        },
        body: {'no_manifest': widget.manifestNo},
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['status'] == 'success') {
          setState(() {
            kanbanTotal = jsonData['data_total'] ?? 0;
            kanbanConfirm = jsonData['data_confirm'] ?? 0;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal mendapatkan data Kanban')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error Server: ${response.statusCode}')),
        );
      }
    } catch (e) {
      print('Error saat fetch kanban: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi error: $e')),
      );
    }
  }

  Future<void> _fetchIdSkid() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    try {
      final response = await http.post(
        Uri.parse('http://192.168.10.55/sto/emanifest/get-id-skid'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $token',
        },
        body: {'no_manifest': widget.manifestNo},
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['status'] == 'success') {
          setState(() {
            skidNumber = jsonData['generate_id'] ?? '';
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal mendapatkan data Kanban')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error Server: ${response.statusCode}')),
        );
      }
    } catch (e) {
      print('Error saat fetch kanban: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi error: $e')),
      );
    }
  }

  // Future<bool> _fetchDataFromApi(String code) async {
  //   final url = Uri.parse('http://192.168.10.55/sto/documentation/get-store?barcode=$code');
  //   try {
  //     final response = await http.get(url);
  //
  //     if (response.statusCode == 200) {
  //       final responseData = json.decode(response.body);
  //
  //       if (responseData != null) {
  //         String idTag = responseData['id_tag'] ?? '';
  //         String area = responseData['area'] ?? '';
  //         String job_no = responseData['job_number'] ?? '';
  //         String part_no = responseData['part_number'] ?? '';
  //         String part_desc = responseData['material_description'] ?? '';
  //
  //         cameraController.stop();
  //         Navigator.push(
  //           context,
  //           MaterialPageRoute(
  //             builder: (context) => CountQty(
  //                 nomorTag: idTag,
  //                 area: area,
  //                 job_no: job_no,
  //                 part_no: part_no,
  //                 part_desc: part_desc
  //             ),
  //           ),
  //         );
  //         return true;
  //       } else {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(content: Text("Data tidak ditemukan di database")),
  //         );
  //         return false;
  //       }
  //     } else {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text("Gagal mengambil data dari server")),
  //       );
  //       return false;
  //     }
  //   } catch (e) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text("Terjadi kesalahan: $e")),
  //     );
  //     return false;
  //   }
  // }

  final Color primaryColor = Colors.teal;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Scan Kanban",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor: Colors.grey.shade100,
      body: Stack(
        children: [
          Column(
            children: [
              // Header Card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "SKID: $skidNumber",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Jumlah Kanban: $kanbanConfirm/$kanbanTotal",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await _confirmManifest(context, widget.manifestNo, skidNumber);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      label: const Text("Selesai"),
                    ),
                  ],
                ),
              ),

              // Kamera Scanner
              Expanded(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          MobileScanner(
                            controller: cameraController,
                            fit: BoxFit.cover,
                            onDetect: (capture) async {
                              if (isProcessing) return;
                              final List<Barcode> barcodes = capture.barcodes;
                              for (final barcode in barcodes) {
                                final String? code = barcode.rawValue;
                                if (code != null) {
                                  isProcessing = true;
                                  await cameraController.stop();
                                  await _confirmKanban(code, widget.manifestNo, skidNumber);
                                }
                              }
                            },
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                shape: BoxShape.circle,
                              ),
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
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),

          // Input Manual di bawah
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(12),
              child: TextField(
                controller: manualInputController,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Masukkan kode barcode/QR manual',
                  prefixIcon: Icon(Icons.keyboard, color: primaryColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: (value) async {
                  final code = value.trim();
                  if (code.isNotEmpty && skidNumber.isNotEmpty) {
                    await _confirmKanban(code, widget.manifestNo, skidNumber);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

}

