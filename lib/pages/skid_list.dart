import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:emanifest/services/auth_service.dart';

class ListSkid extends StatefulWidget {
  final String manifestNo;
  const ListSkid({Key? key, required this.manifestNo}) : super(key: key);

  @override
  _ListSkidState createState() => _ListSkidState();
}

class _ListSkidState extends State<ListSkid> {
  bool isLoading = true;
  List<Map<String, dynamic>> data = [];

  Future<void> _cancelManifest(BuildContext rootContext, String noManifest, String skidNumber, {String? kanbanId}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    try {
      final body = {
        'noManifest': noManifest,
        'noSkid': skidNumber,
      };

      if (kanbanId != null) {
        body['kanbanId'] = kanbanId;
      }

      final response = await http.post(
        Uri.parse('http://192.168.10.55/sto/emanifest/confirm-manifest'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        print('Manifest berhasil dibatalkan');

        showDialog(
          context: rootContext,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: Text('Konfirmasi Pembatalan'),
              content: Text('Batalkan Manifest TMMIN?'),
              actions: <Widget>[
                TextButton(
                  child: Text('No'),
                  onPressed: () => Navigator.of(dialogContext).pop(),
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
                          return Center(child: CircularProgressIndicator());
                        },
                      );

                      final apiUrlCancel = 'https://apihub.toyota.co.id/api/api/exec/tmmin.edcl/api/emanifest-api/0.1.0/api/v1/ManifestCompleteness/cancel';
                      final List<dynamic> bodyData = jsonDecode(response.body);

                      final responseTMMIN = await AuthService().post(apiUrlCancel, bodyData);
                      final Map<String, dynamic> responseJson = jsonDecode(responseTMMIN.body);
                      final String message = responseJson['message'] ?? 'Tidak ada pesan';

                      Navigator.of(rootContext, rootNavigator: true).pop();

                      if (responseTMMIN.statusCode == 200) {
                        if (message.contains("Success")) {
                          try {
                            final bodyCancelFlag = {
                              'noManifest': noManifest,
                              'noSkid': skidNumber,
                            };

                            if (kanbanId != null) {
                              bodyCancelFlag['kanbanId'] = kanbanId;
                            }

                            final localApiUrl = Uri.parse('http://192.168.10.55/sto/emanifest/cancel-flag');
                            final localResponse = await http.post(
                              localApiUrl,
                              headers: {'Content-Type': 'application/x-www-form-urlencoded', 'Authorization': 'Bearer $token'},
                              body: bodyCancelFlag,
                            );
                            print('Response lokal cancel: ${localResponse.statusCode} - ${localResponse.body}');
                          } catch (e) {
                            print('Error saat memanggil API lokal cancel-flag: $e');
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
                                      fetchData(); // ini akan memicu build ulang widget
                                    },
                                    child: Text('OK'),
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
                      print('Error saat cancel ke TMMIN: $e');
                    }
                  },
                ),
              ],
            );
          },
        );
      } else {
        print('Gagal membatalkan manifest: ${response.statusCode}');
      }
    } catch (e) {
      print('Error saat membatalkan manifest: $e');
    }
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
                          try {
                            final localApiUrl = Uri.parse('http://192.168.10.55/sto/emanifest/confirm-flag');

                            final localResponse = await http.post(
                              localApiUrl,
                              headers: {'Content-Type': 'application/x-www-form-urlencoded', 'Authorization': 'Bearer $token'},
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
                                      fetchData();
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

  Future<void> fetchData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final response = await http.get(
      Uri.parse('http://192.168.10.55/sto/emanifest/list-skid?noManifest=${widget.manifestNo}'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      if (responseData['status'] == 'success') {
        setState(() {
          data = (responseData['data'] as List).map((item) {
            List<Map<String, String>> kanbans = [];
            if (item['kanbans'] != null) {
              kanbans = (item['kanbans'] as List).map((kanban) {
                return {
                  'kanban_code': kanban['kanban_code'].toString(),
                  'kanban_id': kanban['kanban_id'].toString(),
                  'prepared': kanban['prepared'].toString(),
                  'is_confirm': kanban['is_confirm'].toString(),
                };
              }).toList();
            }
            return {
              'skid_number': item['skid_number'].toString(),
              'kanbans': kanbans,
            };
          }).toList();
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  final Color primaryColor = Colors.teal;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: primaryColor,
        centerTitle: true,
        elevation: 0,
        title: const Text(
          "List SKID",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : data.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              "Belum ada pengiriman untuk filter ini",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: data.length,
        itemBuilder: (context, index) {
          final skidData = data[index];
          final skidNumber = skidData['skid_number'];
          final kanbans = skidData['kanbans'] as List<Map<String, String>>;
          final allY = kanbans.every((kanban) => kanban['is_confirm'] == 'Y');
          final allN = kanbans.every((kanban) => kanban['is_confirm'] == 'N');
          final Color cardColor = allY
              ? Colors.green.shade50
              : allN
              ? Colors.red.shade50
              : Colors.grey.shade200;

          final Color iconColor = allY
              ? Colors.green
              : allN
              ? Colors.red
              : Colors.grey;

          return Card(
            elevation: 4,
            color: cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ExpansionTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/img/pallet.png',
                    width: 60,
                    height: 20,
                    fit: BoxFit.cover,
                  ),
                ),
                title: Row(
                  children: [
                    Icon(
                      allY
                          ? Icons.check_circle
                          : allN
                          ? Icons.cancel
                          : Icons.help_outline,
                      color: iconColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        skidNumber ?? '-',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                children: [
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...kanbans.map((kanban) {
                          final isConfirm = kanban['is_confirm'];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Code: ${kanban['kanban_code']}'),
                                      Text('ID: ${kanban['kanban_id']}'),
                                      Text('Prepared: ${kanban['prepared']}'),
                                    ],
                                  ),
                                ),
                                if (isConfirm == "Y")
                                  ElevatedButton(
                                    onPressed: () {
                                      _cancelManifest(
                                        context,
                                        widget.manifestNo,
                                        skidNumber,
                                        kanbanId: kanban['kanban_id'],
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      minimumSize: const Size(40, 40),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: const Icon(
                                      Icons.cancel,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),

                        const SizedBox(height: 16),
                        if (allY || allN)
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (allY) {
                                  _cancelManifest(context, widget.manifestNo, skidNumber);
                                } else if (allN) {
                                  _confirmManifest(context, widget.manifestNo, skidNumber);
                                }
                              },
                              icon: Icon(
                                allY ? Icons.cancel : Icons.check_circle,
                                color: Colors.white,
                              ),
                              label: Text(allY ? 'Cancel' : 'Confirm'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: allY ? Colors.red : Colors.green,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
        },
      ),
    );
  }
}

