import 'package:flutter/material.dart';
import 'package:emanifest/component/tag_ok_autocomplete.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui'; // Untuk ImageFilter blur
import 'history_combin_kanban.dart';
import 'dn_list.dart';
import 'shipping_prep_page.dart';

class KanbanHmmi extends StatefulWidget {
  @override
  _KanbanHmmiPageState createState() => _KanbanHmmiPageState();
}

class _KanbanHmmiPageState extends State<KanbanHmmi> {

  bool isFlashOn = false;
  bool _isSubmitting = false;
  bool _isLoading = false;
  List<dynamic> _historyKanban = [];
  final TextEditingController _customerKanbanController = TextEditingController();
  final TextEditingController _tagOkController = TextEditingController();
  final Color primaryDark = const Color(0xFF1565C0);
  final Color primaryLight = const Color(0xFF1E88E5);
  final Color bgColor = const Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    fetchHistoryKanban();
    _customerKanbanController.addListener(_checkIfBothFieldsAreFilled);
    _tagOkController.addListener(_checkIfBothFieldsAreFilled);
  }

  @override
  void dispose() {
    _customerKanbanController.dispose();
    _tagOkController.dispose();
    super.dispose();
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
        body: {'customer': 'Grup2', 'quick': 'true'},
      );
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        setState(() {
          _historyKanban = responseData['data'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetch history: $e');
    }
  }

 void _checkIfBothFieldsAreFilled() {
    final idLabel = _customerKanbanController.text.trim();
    final idKanban = _tagOkController.text.trim();

    if (idKanban.isNotEmpty && idLabel.isNotEmpty && !_isSubmitting && !_isLoading) {
      _fetchPreviewData(idKanban, idLabel);
    }
  }

  Future<void> _fetchPreviewData(String idKanban, String idLabel) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    setState(() => _isLoading = true);

    try {
     final uri = Uri.parse('http://192.168.10.55/sto/combin-kanban/hmmi-kanban-preview')
          .replace(queryParameters: {
        'id_label': idLabel,
        'id_kanban': idKanban,
      });
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      debugPrint("Response Body: ${response.body}");

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);

          if (data['status'] == true) {
            setState(() => _isLoading = false);
            _showConfirmationDialog(data, idKanban, idLabel);
          } else {
            setState(() => _isLoading = false);
            _tagOkController.clear();
            _showDialog('Gagal', data['message'] ?? 'Validasi gagal', false);
          }
        } catch (e) {
          setState(() => _isLoading = false);
          _showDialog('Server Error', 'Format data tidak valid (Bukan JSON). Cek URL API.', false);
        }
      } else {
        setState(() => _isLoading = false);
        _showDialog('Error ${response.statusCode}', 'Gagal terhubung ke server.', false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showDialog('Connection Error', 'Gagal mengambil data: $e', false);
    }
  }
  int? _recalculateHmmiTrip(List<dynamic> breakdown, int? boxSeq, double qtyKanban) {
    if (breakdown.isEmpty || boxSeq == null || boxSeq <= 0 || qtyKanban <= 0) {
      return null;
    }

    final double targetQty = boxSeq * qtyKanban;
    double cumulativeQty = 0.0;

    for (final item in breakdown) {
      if (item is! Map) continue;
      final int cycle = (item['cycle'] is num)
          ? (item['cycle'] as num).toInt()
          : (int.tryParse(item['cycle']?.toString() ?? '') ?? 0);
      final double kwmeng = (item['kwmeng'] is num)
          ? (item['kwmeng'] as num).toDouble()
          : (double.tryParse(item['kwmeng']?.toString() ?? '') ?? 0.0);

      cumulativeQty += kwmeng;
      if (cycle >= 1 && cycle <= 10 && targetQty <= cumulativeQty + 1e-9) {
        return cycle;
      }
    }

    return null;
  }

  void _showConfirmationDialog(Map<String, dynamic> data, String idKanban, String idLabel) {
    String customer = data['customer'] ?? '';
    String qtyDisplay = data['qty_kanban'].toString();

    if (customer == 'MMKI') {
      String cleanLabel = idLabel.replaceAll(RegExp(r'\D'), '');
      if (cleanLabel.length >= 3) {
        String thirdFromEnd = cleanLabel[cleanLabel.length - 3];
        if (thirdFromEnd == '0') {
          qtyDisplay = cleanLabel.substring(cleanLabel.length - 2);
        } else {
          qtyDisplay = cleanLabel.substring(cleanLabel.length - 3);
        }
      }
      qtyDisplay = int.tryParse(qtyDisplay)?.toString() ?? qtyDisplay;
    }

    final TextEditingController qtyKanbanEditController =
        TextEditingController(text: qtyDisplay);

    final bool isHmmi = customer == 'HMMI';
    final List<dynamic> tripBreakdown =
        (data['trip_breakdown'] is List) ? List<dynamic>.from(data['trip_breakdown']) : [];
    final int? boxSequence = (data['box_sequence'] is num)
        ? (data['box_sequence'] as num).toInt()
        : int.tryParse(data['box_sequence']?.toString() ?? '');
    int? suggestedTrip = (data['suggested_trip'] is num)
        ? (data['suggested_trip'] as num).toInt()
        : int.tryParse(data['suggested_trip']?.toString() ?? '');
    if (suggestedTrip != null && (suggestedTrip < 1 || suggestedTrip > 10)) {
      suggestedTrip = null;
    }

    int? selectedTrip = suggestedTrip;
    bool userEditedTrip = false;
    String? tripValidationError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: const [
                  Icon(Icons.preview_outlined, color: Colors.blue),
                  SizedBox(width: 10),
                  Text("Preview Data"),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildReadonlyField("Part Label", data['part_label']?.toString() ?? '-'),
                    _buildReadonlyField("ID Label", idLabel),
                    const SizedBox(height: 12),
                    _buildReadonlyField("ID Kanban", idKanban),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    _buildReadonlyField("Customer", customer),
                    const SizedBox(height: 12),
                    _buildEditableQty(
                      "Qty Kanban",
                      qtyKanbanEditController,
                      onChanged: isHmmi
                          ? (val) {
                              setDialogState(() {
                                final double newQty = double.tryParse(val.trim()) ?? 0;
                                suggestedTrip = _recalculateHmmiTrip(
                                  tripBreakdown,
                                  boxSequence,
                                  newQty,
                                );
                                if (!userEditedTrip) {
                                  selectedTrip = suggestedTrip;
                                }
                                tripValidationError = null;
                              });
                            }
                          : null,
                    ),
                    if (isHmmi) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: suggestedTrip != null
                              ? Colors.blue.shade50
                              : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: suggestedTrip != null
                                ? Colors.blue.shade200
                                : Colors.orange.shade300,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              suggestedTrip != null
                                  ? "Saran Sistem: Trip $suggestedTrip${boxSequence != null ? ' (Urutan Box $boxSequence)' : ''}"
                                  : "Tidak ditemukan di schedule, silakan pilih trip secara manual.",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: suggestedTrip != null
                                    ? Colors.blue.shade900
                                    : Colors.orange.shade900,
                              ),
                            ),
                            if (tripBreakdown.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                "Schedule: ${tripBreakdown.map((e) => 'T${e['cycle']}:${(e['kwmeng'] as num).toInt()}').join(' | ')}",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Trip Delivery",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blueGrey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      DropdownButtonFormField<int>(
                        key: ValueKey<int?>(selectedTrip),
                        initialValue: selectedTrip,
                        hint: const Text("Pilih Trip (1 - 10)"),
                        isExpanded: true,
                        decoration: InputDecoration(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.blue.withValues(alpha: 0.05),
                        ),
                        items: List.generate(10, (index) => index + 1).map((tripNo) {
                          final bool isSuggested = suggestedTrip == tripNo;
                          return DropdownMenuItem<int>(
                            value: tripNo,
                            child: Text(
                              isSuggested ? "Trip $tripNo (Saran)" : "Trip $tripNo",
                              style: TextStyle(
                                fontWeight: isSuggested ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() {
                            selectedTrip = val;
                            userEditedTrip = true;
                            tripValidationError = null;
                          });
                        },
                      ),
                      if (tripValidationError != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          tripValidationError!,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 15),
                    Center(
                      child: Text(
                        "Pastikan data sudah sesuai sebelum menekan PROSES",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text("Batal", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryDark,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    if (isHmmi && selectedTrip == null) {
                      setDialogState(() {
                        tripValidationError = "Harap pilih Trip (1 - 10) terlebih dahulu.";
                      });
                      return;
                    }
                    String finalQtyKanban = qtyKanbanEditController.text.trim();
                    Navigator.of(dialogContext).pop();
                    _submitToApi(
                      idKanban,
                      idLabel,
                      data['qty_label'].toString(),
                      finalQtyKanban,
                      trip: selectedTrip,
                    );
                  },
                  child: const Text("PROSES", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildReadonlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
        ),
      ],
    );
  }
  Widget _buildEditableQty(
    String label,
    TextEditingController controller, {
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          onChanged: onChanged,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            isDense: true,
            filled: true,
            fillColor: Colors.blue.withOpacity(0.05),
          ),
        ),
      ],
    );
  }
  Widget _buildInfoRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }
  Future<void> _submitToApi(
    String idKanban,
    String idLabel,
    String qtyLabel,
    String qtyKanban, {
    int? trip,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    // 1. Set loading di awal
    setState(() => _isLoading = true);

    try {
      final Map<String, String> body = {
        'id_kanban': idKanban,
        'id_label': idLabel,
        'qty_label': qtyLabel,
        'qty_kanban': qtyKanban,
      };
      if (trip != null) {
        body['trip'] = trip.toString();
      }

      final response = await http.post(
        Uri.parse('http://192.168.10.55/sto/combin-kanban/hmmi-kanban'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      // 2. Cek apakah widget masih ada di screen (penting untuk async)
      if (!mounted) return;

      final data = jsonDecode(response.body);
      bool isSuccess = data['status'] ?? false;
      final String? warning = data['warning']?.toString();

      String detail = "${data['message']}\n\n"
          "DN : ${data['dn'] ?? '-'}\n"
          "Total : ${data['scanned'] ?? '-'} / ${data['total'] ?? '-'}";
      if (data['trip'] != null) {
        detail += "\nTrip : Trip ${data['trip']}";
      }
      if (warning != null && warning.trim().isNotEmpty) {
        detail += "\n\n⚠ Peringatan:\n$warning";
      }

      // 3. Matikan loading DAHULU sebelum memunculkan dialog
      setState(() => _isLoading = false);

      // 4. Bersihkan input jika sukses agar saat dialog muncul, background sudah bersih
      if (isSuccess) {
        _customerKanbanController.clear();
        _tagOkController.clear();
        // Refresh history di background
        fetchHistoryKanban();
      }

      // 5. Tampilkan dialog hasil
      _showDialog(isSuccess ? 'Sukses' : 'Gagal', detail, isSuccess);

    } catch (e) {
      if (!mounted) return;

      // Matikan loading jika terjadi error
      setState(() => _isLoading = false);
      _showDialog('Error', 'Terjadi kesalahan sistem: $e', false);
    }
  }
  Future<void> _submitManual() async {
    final idLabel = _customerKanbanController.text.trim();
    final idKanban = _tagOkController.text.trim();

    if (idLabel.isEmpty) {
      _showDialog('Peringatan', 'Harap isi Scan Customer dan Scan Tag OK untuk melakukan Combin.', false);
      return;
    }

    if (_isLoading) return;

    _fetchPreviewData(idKanban, idLabel);
  }
  void _showDialog(String title, String message, bool isSuccess) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.noHeader,
      animType: AnimType.scale,
      title: title,
      desc: message,
      customHeader: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isSuccess ? Colors.green.shade50 : Colors.red.shade50,
          shape: BoxShape.circle,
        ),
        child: Icon(
          isSuccess ? Icons.check : Icons.error_outline,
          color: isSuccess ? Colors.green : Colors.red,
          size: 60,
        ),
      ),
      btnOkOnPress: () {
        // Pastikan fokus dilepas dari textfield agar keyboard tidak mengganggu UI
        FocusScope.of(context).unfocus();
      },
      onDismissCallback: (type) {
        debugPrint('Dialog dismissed: $type');
      },
      btnOkColor: isSuccess ? Colors.green : Colors.red,
    ).show();
  }
  void _openScanner(BuildContext context, bool isCustomerKanban) {
    bool isProcessing = false;

    final cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: [BarcodeFormat.qrCode, BarcodeFormat.code128, BarcodeFormat.code39],
      facing: CameraFacing.back,
      returnImage: false,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              contentPadding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: double.maxFinite,
                  height: 420,
                  child: Stack(
                    children: [
                      // ── Kamera dengan BoxFit.cover ───────────────────────────
                      Positioned.fill(
                        child: ClipRect(
                          child: MobileScanner(
                            controller: cameraController,
                            fit: BoxFit.cover,
                            onDetect: (capture) {
                              if (isProcessing) return;
                              final String? code = capture.barcodes.firstOrNull?.rawValue;
                              if (code == null || code.isEmpty) return;

                              isProcessing = true;

                              cameraController.stop();
                              Navigator.of(context).pop(code);
                            },
                          ),
                        ),
                      ),

                      // ── Label instruksi ──────────────────────────────────────
                      Positioned(
                        bottom: 90,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isCustomerKanban
                                  ? 'Arahkan ke Customer Kanban'
                                  : 'Arahkan ke Tag OK / E-Kanban',
                              style: const TextStyle(
                                color: Colors.white, fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // ── Tombol close ─────────────────────────────────────────
                      Positioned(
                        top: 10,
                        right: 10,
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () {
                              cameraController.dispose();
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                      ),

                      // ── Tombol flash ─────────────────────────────────────────
                      Positioned(
                        bottom: 20,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: GestureDetector(
                            onTap: () {
                              setDialogState(() => isFlashOn = !isFlashOn);
                              cameraController.toggleTorch();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isFlashOn
                                    ? Colors.yellow.withOpacity(0.3)
                                    : Colors.black45,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isFlashOn ? Icons.flash_on : Icons.flash_off,
                                color: isFlashOn ? Colors.yellow : Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((value) {
      cameraController.dispose();
      if (value != null && value is String && value.isNotEmpty) {
        if (isCustomerKanban) {
          _customerKanbanController.text = value;
        } else {
          _tagOkController.text = value;
        }
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          _buildHeader(),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 120, 20, 30),
            child: Column(
              children: [
                _buildInputCard(),
                const SizedBox(height: 20),
                _buildNavigationGrid(),
                const SizedBox(height: 25),
                _buildHistoryList(),
              ],
            ),
          ),
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }
  Widget _buildHeader() {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryDark, primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(35)),
      ),
      padding: const EdgeInsets.only(top: 60, left: 25, right: 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text("Grup 2 Kanban", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          SizedBox(height: 5),
          Text("Grup 2 Operational System", style: TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }
  Widget _buildInputCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildTextFieldWithLabel("Customer Kanban", "Scan barcode customer", _customerKanbanController, true),
          const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 18, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text("Tag OK / E-Kanban", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey[800])),
                ],
              ),
              const SizedBox(height: 8),
              TagOkAutocomplete(
                controller: _tagOkController,
                hint: "Scan / Ketik Tag OK",
                customer: "HMMI",
                primaryDark: primaryDark,
                primaryLight: primaryLight,
                onScan: () => _openScanner(context, false),
                onChanged: (val) => _checkIfBothFieldsAreFilled(),
                onSubmitted: (val) => _checkIfBothFieldsAreFilled(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _submitManual,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryDark, primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: primaryDark.withOpacity(0.18),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.visibility_outlined, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  "PREVIEW & SUBMIT",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextFieldWithLabel(String label, String hint, TextEditingController controller, bool isCustomer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
              suffixIcon: IconButton(
                icon: Icon(Icons.qr_code_scanner, color: primaryDark),
                onPressed: () => _openScanner(context, isCustomer),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildNavButton(
            "Riwayat",
            Icons.history,
            Colors.orange,
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => HistoryCombinKanban(sourcePage: "HMMI"))),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildNavButton(
            "Shipping",
            Icons.inventory_2_outlined,
            Colors.blue,
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShippingPrepPage())),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildNavButton(
            "DN List",
            Icons.local_shipping,
            Colors.teal,
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => DnList(source: 'HMMI'))),
          ),
        ),
      ],
    );
  }

  Widget _buildNavButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Aktivitas Terakhir", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _historyKanban.isEmpty
            ? Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
          child: const Center(child: Text("Belum ada data", style: TextStyle(color: Colors.grey))),
        )
            : ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _historyKanban.length,
          itemBuilder: (context, index) {
            final item = _historyKanban[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade50,
                  child: Icon(Icons.inventory_2_outlined, color: primaryDark, size: 20),
                ),
                title: Text("Part - ${item['part']}",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text("${item['created_at']}", style: const TextStyle(fontSize: 12)),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          color: Colors.black12,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 15),
                  Text("Memproses Data..."),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
