import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ShippingPrepPage extends StatefulWidget {
  final String? initialCustomer;
  const ShippingPrepPage({super.key, this.initialCustomer});

  @override
  State<ShippingPrepPage> createState() => _ShippingPrepPageState();
}

class _ShippingPrepPageState extends State<ShippingPrepPage> {
  String? selectedCustomer;
  DateTime? selectedDate;
  final TextEditingController _dateController = TextEditingController();

  // ── filter DN & TMMIN ──
  String? selectedRoute;
  String? selectedTrip;
  List<String> _routeOptions = [];
  List<String> _tripOptions  = [];
  final Set<String> _expandedDNCards = {};

  // ── filter non-DN ──
  String? selectedCycle;          // untuk form search (MMKI)
  String? selectedCycleFilter;    // untuk sub-filter setelah data masuk
  List<String> _cycleOptions = [];
  Map<String, dynamic> _cycleSummary = {};
  bool _isLoading   = false;
  bool _hasSearched = false;

  List<dynamic> _allData  = [];
  List<dynamic> _filtered = [];

  final Color primaryDark = const Color(0xFF1565C0);
  final Color bgColor     = const Color(0xFFF5F7FA);

  static const String _apiBase = 'http://192.168.10.55/sto/combin-kanban';
  bool get _isDN => selectedCustomer == 'DN4' || selectedCustomer == 'DN5';
  bool get _isTmmin => selectedCustomer?.toUpperCase() == 'TMMIN';

  @override
  void initState() {
    super.initState();
    if (widget.initialCustomer != null) {
      selectedCustomer = widget.initialCustomer;
      selectedDate = DateTime.now();
      _dateController.text = selectedDate!.toIso8601String().split('T').first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleSearch();
      });
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  // ── Date picker ────────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: primaryDark),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
        _dateController.text = picked.toIso8601String().split('T').first;
      });
    }
  }

  void _onCustomerChanged(String? value) {
    setState(() {
      selectedCustomer     = value;
      selectedCycle        = null;
      selectedCycleFilter  = null;
      selectedRoute        = null;
      selectedTrip         = null;
      _routeOptions        = [];
      _tripOptions         = [];
      _cycleOptions        = [];
      _cycleSummary        = {}; // ✅ reset
      _allData             = [];
      _filtered            = [];
      _expandedDNCards.clear();
      _hasSearched         = false;
    });
  }

  // ── Search ─────────────────────────────────────────────────────────────────
  Future<void> _handleSearch() async {
    if (selectedCustomer == null || _dateController.text.isEmpty) {
      _snack("Customer dan tanggal wajib diisi");
      return;
    }
    setState(() => _isLoading = true);
    try {
      if (_isDN) {
        await _fetchDN();
      } else {
        await _fetchFlat();
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchDN() async {
    final token = await _getToken();

    final uriAll = Uri.parse('$_apiBase/adm-trip').replace(
      queryParameters: {
        'dn'   : selectedCustomer ?? '',
        'date' : _dateController.text,
      },
    );

    try {
      final res = await http.get(uriAll, headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode != 200) { _snack("Server error: ${res.statusCode}"); return; }

      final raw  = jsonDecode(res.body);
      final List<dynamic> data = raw is List ? raw : (raw['data'] ?? []);

      final routes = data
          .map((x) => x['route']?.toString() ?? '')
          .where((r) => r.isNotEmpty)
          .toSet().toList()..sort();

      final trips = data
          .map((x) => x['trip']?.toString() ?? '')
          .where((t) => t.isNotEmpty)
          .toSet().toList()
        ..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));

      final firstRoute = routes.isNotEmpty ? routes.first : null;
      final firstTrip  = trips.isNotEmpty  ? trips.first  : null;

      setState(() {
        _allData      = data;
        _routeOptions = routes;
        _tripOptions  = trips;
        selectedRoute = firstRoute;
        selectedTrip  = firstTrip;
        _hasSearched  = true;
        _filtered     = _applyDNFilter(data, firstRoute, firstTrip);
      });
    } catch (e) {
      _snack("Gagal fetch DN: $e");
    }
  }
  // ── Fetch non-DN ───────────────────────────────────────────────────────────
  // ── Fetch non-DN ───────────────────────────────────────────────────────────
  Future<void> _fetchFlat() async {
    final token    = await _getToken();
    final dateStr  = _dateController.text;
    final customer = selectedCustomer?.toLowerCase() ?? '';

    // ✅ URL baru: /mieruka_shipping
    final uri = Uri.parse('$_apiBase/mieruka_shipping').replace(
      queryParameters: {
        'customer': customer,
        'tanggal' : dateStr,
        'cycle'   : selectedCycle ?? '',
      },
    );

    try {
      final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode != 200) { _snack("Server error: ${res.statusCode}"); return; }

      final body = jsonDecode(res.body);

      // ✅ Struktur: body['data']['data'] dan body['data']['cycle_summary']
      final dynamic rawData = body['data'];
      final Map<String, dynamic> dataWrapper =
      rawData is Map ? rawData.cast<String, dynamic>() : {};
      final List<dynamic> data                = dataWrapper['data']          ?? [];
      final Map<String, dynamic> cycleSummary = (dataWrapper['cycle_summary'] as Map?)
          ?.cast<String, dynamic>() ?? {};

      final currentCust = selectedCustomer?.toUpperCase() ?? '';

      // ✅ FILTER DEFENSIF: Pastikan hanya data milik customer yang dipilih yang diproses
      final List<dynamic> customerData = data.where((x) {
        final itemCust = (x['customer'] ?? x['CUSTOMER'])?.toString().trim().toUpperCase();
        return itemCust == null || itemCust.isEmpty || itemCust == currentCust;
      }).toList();

      // ✅ KHUSUS TMMIN: Filter Route (RD40, RD37, RM17) & Cycle seperti ADM
      if (_isTmmin) {
        for (var item in customerData) {
          final kunnr = (item['kunnr'] ?? item['KUNNR'])?.toString().trim().toUpperCase() ?? '';
          final bstnk = (item['bstnk'] ?? item['BSTNK'])?.toString().trim() ?? '';
          String route = '-';
          if (kunnr == 'C-ADM0001') {
            if (bstnk.startsWith('1')) {
              route = 'RM17';
            } else {
              route = 'RD40';
            }
          } else if (kunnr == 'C-TMMIN01') {
            route = 'RD37';
          } else {
            route = (item['route'] ?? item['ROUTE'])?.toString() ?? '-';
          }
          item['route'] = route;
          item['ROUTE'] = route;
        }

        final routes = customerData
            .map((x) => x['route']?.toString() ?? '')
            .where((r) => r.isNotEmpty && r != '-')
            .toSet()
            .toList()
          ..sort();

        final firstRoute = routes.isNotEmpty ? routes.first : null;

        final cycles = customerData
            .where((x) => firstRoute == null || x['route']?.toString() == firstRoute)
            .map((x) => (x['cycle'] ?? x['CYCLE'])?.toString() ?? '')
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));

        final firstCycle = cycles.isNotEmpty ? cycles.first : null;

        setState(() {
          _allData            = customerData;
          _routeOptions       = routes;
          _cycleOptions       = cycles;
          selectedRoute       = firstRoute;
          selectedCycleFilter = firstCycle;
          _hasSearched        = true;
          _filtered           = _applyTmminFilter(customerData, firstRoute, firstCycle);
        });
        return;
      }

      // ✅ Hitung/validasi cycle summary agar benar-benar merefleksikan customer terpilih
      final Map<String, dynamic> computedSummary = {};
      for (var item in customerData) {
        final c = (item['cycle'] ?? item['CYCLE'])?.toString();
        if (c == null || c.isEmpty) continue;
        final isScanned = item['FINISH']?.toString() == '1' || item['is_scan']?.toString() == '1';
        if (!computedSummary.containsKey(c)) {
          final serverInfo = cycleSummary[c] as Map<String, dynamic>?;
          computedSummary[c] = {
            'totalData': 0,
            'totalFinish': 0,
            'etd': serverInfo?['etd'] ?? item['ETD'] ?? item['etd'] ?? '--:--:--',
            'vdatu': serverInfo?['vdatu'] ?? item['VDATU'] ?? item['vdatu'],
          };
        }
        computedSummary[c]['totalData'] = (computedSummary[c]['totalData'] as int) + 1;
        if (isScanned) {
          computedSummary[c]['totalFinish'] = (computedSummary[c]['totalFinish'] as int) + 1;
        }
      }

      final finalSummary = computedSummary.isNotEmpty ? computedSummary : cycleSummary;

      final cycles = finalSummary.keys.toList()
        ..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));

      final firstCycle = cycles.isNotEmpty ? cycles.first : null;

      setState(() {
        _allData            = customerData;
        _cycleSummary       = finalSummary;
        _cycleOptions       = cycles;
        selectedCycleFilter = firstCycle;
        _hasSearched        = true;
        _filtered           = _applyFlatFilter(customerData, firstCycle);
      });
    } catch (e) {
      _snack("Gagal fetch data: $e");
    }
  }
  // ── Filter DN (route + trip) ───────────────────────────────────────────────
  List<dynamic> _applyDNFilter(List<dynamic> source, String? route, String? trip) {
    return source.where((x) {
      final matchRoute = route == null || x['route']?.toString() == route;
      final matchTrip  = trip  == null || x['trip']?.toString()  == trip;
      return matchRoute && matchTrip;
    }).toList();
  }

  // ── Filter non-DN (cycle) ──────────────────────────────────────────────────
  List<dynamic> _applyFlatFilter(List<dynamic> source, String? cycle) {
    final selectedCust = selectedCustomer?.toUpperCase();
    return source.where((x) {
      final c = x['cycle']?.toString() ?? x['CYCLE']?.toString() ?? '';
      final itemCust = (x['customer'] ?? x['CUSTOMER'])?.toString().trim().toUpperCase();
      final matchCust = selectedCust == null || itemCust == null || itemCust.isEmpty || itemCust == selectedCust;
      if (cycle == null) return matchCust;
      return c == cycle && matchCust;
    }).toList();
  }

  // ── Filter TMMIN (route + cycle) ───────────────────────────────────────────
  List<dynamic> _applyTmminFilter(List<dynamic> source, String? route, String? cycle) {
    return source.where((x) {
      final itemRoute = x['route']?.toString() ?? x['ROUTE']?.toString();
      final itemCycle = (x['cycle'] ?? x['CYCLE'])?.toString();
      final matchRoute = route == null || itemRoute == route;
      final matchCycle = cycle == null || itemCycle == cycle;
      return matchRoute && matchCycle;
    }).toList();
  }

  // ── Getters ────────────────────────────────────────────────────────────────
  List<dynamic> get _palletItems =>
      _filtered.where((x) => (x['jenis'] ?? '').toString().toUpperCase() == 'PALLET').toList();

  List<dynamic> get _polyboxItems =>
      _filtered.where((x) => (x['jenis'] ?? '').toString().toUpperCase() == 'POLYBOX').toList();

  int get _totalFinish => _filtered.where((x) {
    return x['FINISH']?.toString() == '1' || x['is_scan']?.toString() == '1';
  }).length;

  Color get _statusColor {
    if (_filtered.isEmpty) return Colors.grey;
    return _totalFinish >= _filtered.length
        ? Colors.green.shade700
        : Colors.red.shade700;
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ── Build ──────────────────────────────────────────────────────────────────
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
          // Sub-filter DN: Route + Trip
          if (_hasSearched && _isDN) _buildDNSubFilter(),
          // Sub-filter TMMIN: Route + Cycle
          if (_hasSearched && _isTmmin) _buildTmminSubFilter(),
          // Sub-filter non-DN non-TMMIN: Cycle
          if (_hasSearched && !_isDN && !_isTmmin && _cycleOptions.isNotEmpty) _buildFlatSubFilter(),
          if (_hasSearched && _filtered.isNotEmpty) _buildStatusBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  // ── Status bar ─────────────────────────────────────────────────────────────
  Widget _buildStatusBar() {
    final isComplete = _totalFinish >= _filtered.length;
    return Container(
      color: _statusColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            isComplete ? Icons.check_circle : Icons.pending_actions_rounded,
            color: Colors.white, size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            isComplete ? "COMPLETE" : "MINUS",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          Text(
            "$_totalFinish / ${_filtered.length} ITEM",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ── DN sub-filter (Route + Trip) ───────────────────────────────────────────
  Widget _buildDNSubFilter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Route", style: TextStyle(fontSize: 11, color: Colors.grey)),
                DropdownButton<String>(
                  value: selectedRoute,
                  isExpanded: true,
                  items: _routeOptions
                      .map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (val) => setState(() {
                    selectedRoute = val;
                    _filtered = _applyDNFilter(_allData, selectedRoute, selectedTrip);
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Trip", style: TextStyle(fontSize: 11, color: Colors.grey)),
                DropdownButton<String>(
                  value: selectedTrip,
                  isExpanded: true,
                  items: _tripOptions
                      .map((t) => DropdownMenuItem(value: t, child: Text("Trip $t", style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (val) => setState(() {
                    selectedTrip = val;
                    _filtered = _applyDNFilter(_allData, selectedRoute, selectedTrip);
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── TMMIN sub-filter (Route + Cycle) ───────────────────────────────────────
  Widget _buildTmminSubFilter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Route", style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                DropdownButton<String>(
                  value: selectedRoute,
                  isExpanded: true,
                  hint: const Text("- Pilih Route -", style: TextStyle(fontSize: 13)),
                  items: _routeOptions
                      .map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(r, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() {
                    selectedRoute = val;
                    final cycles = _allData
                        .where((x) => x['route']?.toString() == val)
                        .map((x) => (x['cycle'] ?? x['CYCLE'])?.toString() ?? '')
                        .where((c) => c.isNotEmpty)
                        .toSet()
                        .toList()
                      ..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
                    _cycleOptions = cycles;
                    if (!cycles.contains(selectedCycleFilter)) {
                      selectedCycleFilter = cycles.isNotEmpty ? cycles.first : null;
                    }
                    _filtered = _applyTmminFilter(_allData, selectedRoute, selectedCycleFilter);
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Cycle", style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                DropdownButton<String>(
                  value: selectedCycleFilter,
                  isExpanded: true,
                  hint: const Text("- Pilih Cycle -", style: TextStyle(fontSize: 13)),
                  items: _cycleOptions
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text("Cycle $c", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() {
                    selectedCycleFilter = val;
                    _filtered = _applyTmminFilter(_allData, selectedRoute, selectedCycleFilter);
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Non-DN sub-filter (Cycle) ──────────────────────────────────────────────
  Widget _buildFlatSubFilter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          const Text("Cycle :", style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _cycleOptions.map((c) {
                  final isSelected = selectedCycleFilter == c;

                  // ✅ Ambil info dari cycle_summary
                  final summary     = _cycleSummary[c] as Map<String, dynamic>? ?? {};
                  final totalData   = summary['totalData']   ?? 0;
                  final totalFinish = summary['totalFinish'] ?? 0;
                  final etd         = summary['etd']?.toString() ?? '';
                  final etdShort    = etd.length >= 5 ? etd.substring(0, 5) : etd;
                  final isComplete  = totalData > 0 && totalFinish >= totalData;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "C$c",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : primaryDark,
                            ),
                          ),
                          Text(
                            "$totalFinish/$totalData",
                            style: TextStyle(
                              fontSize: 10,
                              color: isSelected
                                  ? Colors.white70
                                  : (isComplete ? Colors.green.shade700 : Colors.red.shade700),
                            ),
                          ),
                          if (selectedCustomer?.toUpperCase() != 'TMMIN' &&
                              etdShort.isNotEmpty)
                            Text(
                              etdShort,
                              style: TextStyle(
                                fontSize: 9,
                                color: isSelected ? Colors.white60 : Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                      selected: isSelected,
                      selectedColor: isComplete ? Colors.green.shade700 : Colors.red.shade700,
                      backgroundColor: isComplete ? Colors.green.shade50 : Colors.red.shade50,
                      side: BorderSide(
                        color: isComplete ? Colors.green.shade400 : Colors.red.shade400,
                      ),
                      onSelected: (_) => setState(() {
                        selectedCycleFilter = c;
                        _filtered = _applyFlatFilter(_allData, c);
                      }),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
  // ── Body ───────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_isLoading) return Center(child: CircularProgressIndicator(color: primaryDark));
    if (!_hasSearched) return const Center(child: Text("Gunakan filter untuk menampilkan data"));
    if (_filtered.isEmpty) return const Center(child: Text("Data tidak ditemukan"));

    if (_isDN) return _buildDNItems();
    return _buildFlatItems();
  }

  // ── DN items ───────────────────────────────────────────────────────────────
  Widget _buildDNItems() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_palletItems.isNotEmpty) ...[
          _buildSectionHeader("PALLET", Colors.orange.shade700),
          const SizedBox(height: 8),
          _buildDNItemGrid(_palletItems),
          const SizedBox(height: 16),
        ],
        if (_polyboxItems.isNotEmpty) ...[
          _buildSectionHeader("POLYBOX", Colors.green.shade700),
          const SizedBox(height: 8),
          _buildDNItemGrid(_polyboxItems),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildDNItemGrid(List<dynamic> items) {
    List<Widget> rows = [];
    for (int i = 0; i < items.length; i += 2) {
      final item1 = items[i];
      final item2 = (i + 1 < items.length) ? items[i + 1] : null;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildDNCard(item1)),
              const SizedBox(width: 8),
              Expanded(child: item2 != null ? _buildDNCard(item2) : const SizedBox()),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }

  // ── Non-DN items ───────────────────────────────────────────────────────────
  Widget _buildFlatItems() {
    // TMMIN: group by ETD
    if (selectedCustomer == 'TMMIN') {
      return _buildFlatItemsGroupedByEtd();
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildSectionHeader(
          "${selectedCustomer ?? ''} — Cycle ${selectedCycleFilter ?? '-'}",
          Colors.blue.shade700,
        ),
        const SizedBox(height: 8),
        _buildFlatItemGrid(_filtered),
      ],
    );
  }
  Widget _buildFlatItemsGroupedByEtd() {
    final grouped = _groupByEtd(_filtered);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Header Route & Cycle
        _buildSectionHeader(
          "TMMIN — Route ${selectedRoute ?? '-'} — Cycle ${selectedCycleFilter ?? '-'}",
          Colors.blue.shade700,
        ),
        const SizedBox(height: 12),

        ...grouped.entries.map((entry) {
          final etdLabel = entry.key;
          final items    = entry.value;
          final doneCount  = items.where((x) =>
          x['FINISH']?.toString() == '1' || x['is_scan']?.toString() == '1').length;
          final isComplete = doneCount >= items.length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── ETD separator header ──
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isComplete ? Colors.green.shade700 : Colors.orange.shade700,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      "ETD $etdLabel",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "$doneCount / ${items.length}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      isComplete ? Icons.check_circle : Icons.pending_actions_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ],
                ),
              ),

              // ── Grid items dalam grup ETD ini ──
              _buildFlatItemGrid(items),
              const SizedBox(height: 16),
            ],
          );
        }).toList(),
      ],
    );
  }
  Widget _buildSectionHeader(String label, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: accent, width: 5)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.bold,
          fontSize: 14, letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildFlatItemGrid(List<dynamic> items) {
    List<Widget> rows = [];
    for (int i = 0; i < items.length; i += 3) {
      final item1 = items[i];
      final item2 = (i + 1 < items.length) ? items[i + 1] : null;
      final item3 = (i + 2 < items.length) ? items[i + 2] : null;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildFlatCard(item1)),
              const SizedBox(width: 8),
              Expanded(child: item2 != null ? _buildFlatCard(item2) : const SizedBox()),
              const SizedBox(width: 8),
              Expanded(child: item3 != null ? _buildFlatCard(item3) : const SizedBox()),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }

  // ── Card DN ────────────────────────────────────────────────────────────────
  Widget _buildDNCard(dynamic item) {
    final isOk        = item['is_scan']?.toString() == '1' || item['FINISH']?.toString() == '1';
    final scanned     = item['scanned']?.toString() ?? '';
    final total       = item['total']?.toString() ?? '';
    final jobNum      = item['job_number']?.toString() ?? '-';
    final partNum     = item['part_number']?.toString() ?? '-';
    final qty         = item['qty']?.toString() ?? '-';
    final rawBarcode  = item['barcode']?.toString() ?? '';
    final dnNumber    = (item['dn_number']?.toString() ??
        (rawBarcode.length >= 16 ? rawBarcode.substring(0, 16) : rawBarcode)).trim();

    final isExpanded  = _expandedDNCards.contains(jobNum);

    final bgCard      = isOk ? Colors.green.shade50  : Colors.red.shade50;
    final borderColor = isOk ? Colors.green.shade600 : Colors.red.shade600;
    final badgeColor  = isOk ? Colors.green.shade600 : Colors.red.shade700;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isExpanded) {
            _expandedDNCards.remove(jobNum);
          } else {
            _expandedDNCards.add(jobNum);
          }
        });
      },
      child: _buildCardShell(
        isOk: isOk,
        bgCard: bgCard,
        borderColor: borderColor,
        badgeColor: badgeColor,
        badge: scanned.isNotEmpty && total.isNotEmpty
            ? Text("$scanned/$total",
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))
            : Icon(isOk ? Icons.check : Icons.close, color: Colors.white, size: 14),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(
                  isOk ? Icons.check_circle : Icons.pending_actions_rounded,
                  color: isOk ? Colors.green.shade700 : Colors.red.shade700,
                  size: 20,
                ),
                const Spacer(),
                Icon(
                  isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(jobNum,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const Divider(height: 8, thickness: 0.8),
            Text(partNum,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const Divider(height: 8, thickness: 0.8),
            Text("Qty: $qty", style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
            if (isExpanded) ...[
              const Divider(height: 8, thickness: 0.8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "DN :",
                      style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dnNumber.isNotEmpty ? dnNumber : "-",
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: primaryDark,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Card non-DN ────────────────────────────────────────────────────────────
  Widget _buildFlatCard(dynamic item) {
    final isOk         = item['FINISH']?.toString() == '1' || item['is_scan']?.toString() == '1';
    final matnr        = item['MATNR']?.toString() ?? '-';
    final bismt        = item['BISMT']?.toString() ?? '-';
    final kwmeng       = item['KWMENG']?.toString() ?? '-';
    final totalQtyScan = item['total_qty_scan']?.toString() ?? '0';
    final cycle        = item['cycle']?.toString() ?? item['CYCLE']?.toString() ?? '-';
    final etaRaw       = item['ETA']?.toString() ?? item['eta']?.toString() ?? '';
    final eta          = etaRaw.length >= 5 ? etaRaw.substring(etaRaw.length - 8, etaRaw.length - 3) : etaRaw;
    final bstnk        = item['all_bstnk']?.toString() ?? item['BSTNK']?.toString() ?? item['bstnk']?.toString() ?? '-';

    final cardKey      = "${matnr}_$cycle";
    final isExpanded   = _expandedDNCards.contains(cardKey);

    final bgCard      = isOk ? Colors.green.shade50  : Colors.red.shade50;
    final borderColor = isOk ? Colors.green.shade600 : Colors.red.shade600;
    final badgeColor  = isOk ? Colors.green.shade600 : Colors.red.shade700;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isExpanded) {
            _expandedDNCards.remove(cardKey);
          } else {
            _expandedDNCards.add(cardKey);
          }
        });
      },
      child: _buildCardShell(
        isOk: isOk,
        bgCard: bgCard,
        borderColor: borderColor,
        badgeColor: badgeColor,
        badge: Text(
          "$totalQtyScan/$kwmeng",
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(
                  isOk ? Icons.check_circle : Icons.pending_actions_rounded,
                  color: isOk ? Colors.green.shade700 : Colors.red.shade700,
                  size: 18,
                ),
                const Spacer(),
                Icon(
                  isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(matnr,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const Divider(height: 6, thickness: 0.8),
            Text(bismt,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const Divider(height: 6, thickness: 0.8),
            Row(
              children: [
                if (selectedCustomer?.toUpperCase() == 'TMMIN' && (item['route'] != null && item['route'] != '-')) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: primaryDark.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item['route'].toString(),
                      style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: primaryDark),
                    ),
                  ),
                ],
                Icon(Icons.loop, size: 10, color: Colors.grey.shade500),
                const SizedBox(width: 2),
                Text("C$cycle", style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
                const Spacer(),
                Icon(Icons.schedule, size: 10, color: Colors.grey.shade500),
                const SizedBox(width: 2),
                Text(eta, style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
              ],
            ),
            if (isExpanded) ...[
              const Divider(height: 6, thickness: 0.8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedCustomer?.toUpperCase() == 'TMMIN' ? "BSTNK :" : "DN / BSTNK :",
                      style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bstnk.isNotEmpty ? bstnk : "-",
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Card shell ─────────────────────────────────────────────────────────────
  Widget _buildCardShell({
    required bool isOk,
    required Color bgCard,
    required Color borderColor,
    required Color badgeColor,
    required Widget badge,
    required Widget body,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(10),
                  bottomLeft: Radius.circular(8),
                ),
              ),
              child: badge,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: body,
          ),
        ],
      ),
    );
  }
  String _formatVdatuToDmy(dynamic vdatu) {
    if (vdatu == null) return '';
    final s = vdatu.toString().trim();
    if (s.isEmpty) return '';
    if (s.length == 8 && RegExp(r'^\d{8}$').hasMatch(s)) {
      // 20261021 -> 21-10-2026
      final yyyy = s.substring(0, 4);
      final mm = s.substring(4, 6);
      final dd = s.substring(6, 8);
      return '$dd-$mm-$yyyy';
    } else if (s.contains('-')) {
      final parts = s.split('-');
      if (parts.length == 3) {
        if (parts[0].length == 4) {
          // yyyy-mm-dd -> dd-mm-yyyy
          return '${parts[2]}-${parts[1]}-${parts[0]}';
        }
        return s;
      }
    }
    return s;
  }

  /// Menghitung tanggal & jam ETD (keberangkatan) berdasarkan VDATU (tgl kedatangan) dan ETA/ETD.
  /// Karena VDATU adalah tanggal kedatangan, maka keberangkatan = kedatangan (ETA) - 2 jam.
  /// Jika menyeberang tengah malam ke hari sebelumnya (jam ETA < 02:00 atau jam ETD >= 22:00),
  /// maka tanggal yang ditampilkan adalah tanggal sebelumnya (VDATU - 1 hari).
  String _getEtdDateTimeLabel(dynamic item) {
    if (item == null) return '--:--:--';

    // 1. Jika backend sudah mengirimkan ETD_DATETIME yang sudah terhitung:
    final backendEtdDt = item['ETD_DATETIME']?.toString() ?? item['etd_datetime']?.toString();
    if (backendEtdDt != null && backendEtdDt.trim().isNotEmpty) {
      return backendEtdDt.trim();
    }

    final vdatuRaw = item['VDATU']?.toString() ?? item['vdatu']?.toString() ?? '';
    final realEtaRaw = item['REAL_ETA']?.toString() ?? item['real_eta']?.toString();
    final etdRaw = item['ETD']?.toString() ??
        item['etd']?.toString() ??
        item['ETA']?.toString() ??
        item['eta']?.toString() ??
        '--:--:--';

    String cleanTime(String t) {
      final s = t.trim();
      if (s.length >= 19) return s.substring(11, 19);
      if (s.length >= 8) return s.substring(0, 8);
      if (s.length == 5) return '$s:00';
      return s;
    }

    // Parse VDATU ke DateTime
    DateTime? arrivalDate;
    final vClean = vdatuRaw.replaceAll('-', '').trim();
    if (vClean.length == 8 && RegExp(r'^\d{8}$').hasMatch(vClean)) {
      final y = int.tryParse(vClean.substring(0, 4));
      final m = int.tryParse(vClean.substring(4, 6));
      final d = int.tryParse(vClean.substring(6, 8));
      if (y != null && m != null && d != null) {
        arrivalDate = DateTime(y, m, d);
      }
    } else if (vdatuRaw.contains('-')) {
      final parts = vdatuRaw.split('-');
      if (parts.length == 3 && parts[0].length == 4) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final d = int.tryParse(parts[2]);
        if (y != null && m != null && d != null) {
          arrivalDate = DateTime(y, m, d);
        }
      }
    }

    // Kasus 1: Ada arrivalDate dan REAL_ETA (jam kedatangan murni)
    if (arrivalDate != null && realEtaRaw != null && realEtaRaw.trim().isNotEmpty) {
      final tStr = cleanTime(realEtaRaw);
      final parts = tStr.split(':');
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0]) ?? 0;
        final min = int.tryParse(parts[1]) ?? 0;
        final sec = parts.length > 2 ? (int.tryParse(parts[2]) ?? 0) : 0;
        final arrivalDt = DateTime(arrivalDate.year, arrivalDate.month, arrivalDate.day, h, min, sec);
        final departureDt = arrivalDt.subtract(const Duration(hours: 2));
        final dd = departureDt.day.toString().padLeft(2, '0');
        final mm = departureDt.month.toString().padLeft(2, '0');
        final yyyy = departureDt.year.toString();
        final hh = departureDt.hour.toString().padLeft(2, '0');
        final mStr = departureDt.minute.toString().padLeft(2, '0');
        final sStr = departureDt.second.toString().padLeft(2, '0');
        return '$dd-$mm-$yyyy $hh:$mStr:$sStr';
      }
    }

    // Kasus 2: Ada arrivalDate dan ETD (jam keberangkatan)
    if (arrivalDate != null && etdRaw != '--:--:--') {
      final tStr = cleanTime(etdRaw);
      final parts = tStr.split(':');
      if (parts.isNotEmpty) {
        final etdHour = int.tryParse(parts[0]) ?? 0;
        // Jika jam keberangkatan >= 22 (misal 22:08 atau 23:54), berarti kedatangan di hari berikutnya
        // Sehingga keberangkatan terjadi di hari sebelumnya (VDATU - 1 hari)
        DateTime departureDate = arrivalDate;
        if (etdHour >= 22) {
          departureDate = arrivalDate.subtract(const Duration(days: 1));
        }
        final dd = departureDate.day.toString().padLeft(2, '0');
        final mm = departureDate.month.toString().padLeft(2, '0');
        final yyyy = departureDate.year.toString();
        return '$dd-$mm-$yyyy $tStr';
      }
    }

    // Fallback
    final fallbackDate = _formatVdatuToDmy(vdatuRaw);
    final fallbackTime = cleanTime(etdRaw);
    if (fallbackDate.isNotEmpty) {
      return '$fallbackDate $fallbackTime';
    }
    return fallbackTime;
  }

  /// Menghasilkan format kunci yyyy-MM-dd HH:mm:ss untuk pengurutan kronologis yang akurat
  String _getSortableKey(dynamic item) {
    final label = _getEtdDateTimeLabel(item);
    // Format label: dd-MM-yyyy HH:mm:ss
    final parts = label.split(' ');
    if (parts.length == 2 && parts[0].contains('-')) {
      final dateParts = parts[0].split('-');
      if (dateParts.length == 3 && dateParts[2].length == 4) {
        // dd-mm-yyyy -> yyyy-mm-dd
        return '${dateParts[2]}-${dateParts[1]}-${dateParts[0]} ${parts[1]}';
      }
    }
    return label;
  }

  Map<String, List<dynamic>> _groupByEtd(List<dynamic> items) {
    final Map<String, List<dynamic>> grouped = {};
    for (final item in items) {
      final etdLabel = _getEtdDateTimeLabel(item);
      grouped.putIfAbsent(etdLabel, () => []).add(item);
    }

    // Urutkan secara kronologis berdasarkan tanggal dan waktu keberangkatan yang sebenarnya
    final sorted = Map.fromEntries(
      grouped.entries.toList()
        ..sort((a, b) {
          final itemA = a.value.first;
          final itemB = b.value.first;
          final keyA = _getSortableKey(itemA);
          final keyB = _getSortableKey(itemB);
          return keyA.compareTo(keyB);
        }),
    );
    return sorted;
  }
  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Customer (col-md-5 -> flex: 5)
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Customer",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedCustomer,
                          hint: const Text("Pilih", style: TextStyle(fontSize: 13, color: Colors.grey)),
                          isExpanded: true,
                          items: ["DN4", "DN5", "MKM", "TMMIN", "MMKI", "HMMI"]
                              .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13))))
                              .toList(),
                          onChanged: _onCustomerChanged,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Delivery Date (col-md-5 -> flex: 5)
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Delivery Date",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 44,
                      child: TextFormField(
                        controller: _dateController,
                        readOnly: true,
                        onTap: _pickDate,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: "Tanggal",
                          hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                          prefixIcon: Icon(Icons.calendar_month, color: primaryDark, size: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Button Search (col-md-2 -> flex: 2)
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _handleSearch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryDark,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 1,
                    ),
                    child: const Icon(Icons.search, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ],
          ),
          // Cycle di form search hanya untuk MMKI (jika dipilih)
          if (!_isDN && selectedCustomer == 'MMKI') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text("Cycle:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                const SizedBox(width: 12),
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedCycle,
                      hint: const Text("Pilih Cycle", style: TextStyle(fontSize: 12)),
                      items: const ["1", "5"]
                          .map((e) => DropdownMenuItem(value: e, child: Text("Cycle $e", style: const TextStyle(fontSize: 12))))
                          .toList(),
                      onChanged: (val) => setState(() => selectedCycle = val),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

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
