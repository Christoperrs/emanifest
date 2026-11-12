import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:emanifest/pages/print_tag_sto.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class FormSTOPage extends StatefulWidget {
  const FormSTOPage({super.key});

  @override
  State<FormSTOPage> createState() => _FormSTOPageState();
}

class _FormSTOPageState extends State<FormSTOPage> {
  final _formKey = GlobalKey<FormState>();
  final _textController_1 = TextEditingController();
  final _textController_2 = TextEditingController();
  final _textController_3 = TextEditingController();

  final TextEditingController _textControllerPartNumber = TextEditingController();
  final TextEditingController _textControllerJobNumber = TextEditingController();
  final TextEditingController _textControllerPartDesc = TextEditingController();
  final TextEditingController _textControllerCustomer = TextEditingController();
  final TextEditingController _textControllerType = TextEditingController();


  List<String> _partNumberList = [];

  final List<String> _tagList = ['TAG001', 'TAG002', 'TAG003'];
  final List<String> _qtyList = ['1', '5', '10', '20', '50'];



  final List<String> _dropdownItems = ['IRM', 'KORIDOR', 'IFP', 'METAL FINISH', 'WELDING', 'PRESS', 'INTGD WRHS'];
  String? _selectedValue;

  String? _fileName;
  PlatformFile? _pickedFile;

  void _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg'],
    );

    if (result != null) {
      setState(() {
        _pickedFile = result.files.first;
        _fileName = _pickedFile!.name;
      });
    }
  }

  Future<void> _showCustomDialog(BuildContext context, String title, String message) {
    return showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            CupertinoDialogAction(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }


  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      String partNumber = _textControllerPartNumber.text;
      String jobNumber = _textControllerJobNumber.text;
      String partDesc = _textControllerPartDesc.text;
      String customer = _textControllerCustomer.text;
      String type = _textControllerType.text;
      String area = _selectedValue!;

      String apiUrl = 'http://192.168.10.55/sto/documentation/store-mobile';

      try {
        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {
            'partNumber': partNumber,
            'jobNumber': jobNumber,
            'partDesc': partDesc,
            'customer': customer,
            'type': type,
            'area': area,
          },
        );

        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          String idTag = responseData['id_tags'].toString();
          _showCustomDialog(context, "Sukses", responseData['message'])
              .then((_) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PrintPage(
                  partNumber: partNumber,
                  jobNumber: jobNumber,
                  partDesc: partDesc,
                  customer: customer,
                  tagSto: idTag,
                  type: type,
                  area: area,
                ),
              ),
            );
          });
        } else {
          _showCustomDialog(context, "Gagal", "Terjadi kesalahan, coba lagi!");
        }
      } catch (e) {
        _showCustomDialog(context, "Error", "Terjadi masalah dengan koneksi: $e");
      }
    }
  }

  @override
  void initState() {
    super.initState();
    fetchPartNumberList();
  }

  Future<void> fetchPartNumberList() async {
    final url = Uri.parse('http://192.168.10.55/sto/documentation/get-part-mobile');
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data is List) {
          setState(() {
            _partNumberList = List<String>.from(data);
          });
        } else {
          print('Format data tidak sesuai');
        }
      } else {
        print('Gagal mengambil data NIK: ${response.statusCode}');
      }
    } catch (e) {
      print('Terjadi kesalahan saat fetch data: $e');
    }
  }

  Future<void> fetchPartDetail(String partNumber) async {
    final url = Uri.parse('http://192.168.10.55/sto/documentation/get-part-detail');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'part_number': partNumber,
          'area': _selectedValue
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          _textControllerJobNumber.text = data['job_number'] ?? '';
          _textControllerPartDesc.text = data['material_description'] ?? '';
          _textControllerCustomer.text = data['customer'] ?? '';
          _textControllerType.text = data['type'] ?? '';
        });
      } else {
        print('Gagal fetch detail part: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetch detail part: $e');
    }
  }


  @override
  void dispose() {
    _textController_1.dispose();
    _textController_2.dispose();
    _textController_3.dispose();
    _textControllerPartNumber.dispose();
    _textControllerJobNumber.dispose();
    _textControllerPartDesc.dispose();
    _textControllerCustomer.dispose();
    _textControllerType.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Form STO"),
        leading: BackButton(),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 50),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Image.asset('assets/img/icon-maj.png', width: 100),
                const SizedBox(height: 20),
                const Text("Preparation STO", style: TextStyle(fontSize: 28)),
                const SizedBox(height: 20),
                const Text("PT Mekar Armada Jaya", style: TextStyle(fontSize: 18)),
                const SizedBox(height: 30),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Pilih Area',
                          labelStyle: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                          hintText: 'Pilih area lokasi',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.blue, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: Icon(Icons.location_on, color: Colors.grey[600]),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          errorBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.red, width: 1.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.red, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          errorStyle: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                        ),
                        value: _selectedValue,
                        items: _dropdownItems.map((item) {
                          return DropdownMenuItem(
                            value: item,
                            child: Text(item),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => _selectedValue = value),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Harap pilih area lokasi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TypeAheadField<String>(
                        direction: VerticalDirection.up,
                        suggestionsCallback: (pattern) async {
                          return _partNumberList
                              .where((item) => item.toLowerCase().contains(pattern.toLowerCase()))
                              .toList();
                        },
                        itemBuilder: (context, suggestion) {
                          return ListTile(title: Text(suggestion));
                        },
                        onSelected: (suggestion) {
                          _textControllerPartNumber.text = suggestion;
                          fetchPartDetail(suggestion);
                        },
                        builder: (context, controller, focusNode) {
                          return TextFormField(
                            controller: _textControllerPartNumber,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              labelText: 'Part Number',
                              hintText: 'Masukkan Part Number',
                              prefixIcon: Icon(Icons.build),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onChanged: (val) {
                              controller.text = val;
                              controller.selection = TextSelection.collapsed(offset: val.length);
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      TypeAheadField<String>(
                        direction: VerticalDirection.up,
                        suggestionsCallback: (pattern) async {
                          return _tagList
                              .where((item) =>
                              item.toLowerCase().contains(pattern.toLowerCase()))
                              .toList();
                        },
                        itemBuilder: (context, suggestion) {
                          return ListTile(title: Text(suggestion));
                        },
                        onSelected: (suggestion) {
                          _textControllerJobNumber.text = suggestion;
                        },
                        builder: (context, controller, focusNode) {
                          controller.text = _textControllerJobNumber.text;
                          controller.selection = TextSelection.fromPosition(
                            TextPosition(offset: controller.text.length),
                          );

                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            onChanged: (val) {
                              _textControllerJobNumber.text = val;
                            },
                            decoration: InputDecoration(
                              labelText: 'Job Number',
                              labelStyle: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                              hintText: 'Masukkan Job Number',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              prefixIcon: Icon(Icons.category, color: Colors.grey[600]),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.blue, width: 2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.red, width: 1.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.red, width: 2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              errorStyle: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            validator: (value) =>
                            value == null || value.isEmpty ? 'Harap masukkan Job Number' : null,
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      TypeAheadField<String>(
                        direction: VerticalDirection.up,
                        suggestionsCallback: (pattern) async {
                          return _tagList
                              .where((item) =>
                              item.toLowerCase().contains(pattern.toLowerCase()))
                              .toList();
                        },
                        itemBuilder: (context, suggestion) {
                          return ListTile(title: Text(suggestion));
                        },
                        onSelected: (suggestion) {
                          _textControllerPartDesc.text = suggestion;
                        },
                        builder: (context, controller, focusNode) {
                          // Sinkronkan controller internal builder dengan controller milik kita
                          controller.text = _textControllerPartDesc.text;
                          controller.selection = TextSelection.fromPosition(
                            TextPosition(offset: controller.text.length),
                          );

                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            onChanged: (val) {
                              _textControllerPartDesc.text = val;
                            },
                            decoration: InputDecoration(
                              labelText: 'Part Description',
                              labelStyle: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                              hintText: 'Masukkan Part Description',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              prefixIcon: Icon(Icons.description, color: Colors.grey[600]),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.blue, width: 2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.red, width: 1.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.red, width: 2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              errorStyle: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            validator: (value) =>
                            value == null || value.isEmpty ? 'Harap masukkan Part Description' : null,
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      TypeAheadField<String>(
                        direction: VerticalDirection.up,
                        suggestionsCallback: (pattern) async {
                          return _tagList
                              .where((item) =>
                              item.toLowerCase().contains(pattern.toLowerCase()))
                              .toList();
                        },
                        itemBuilder: (context, suggestion) {
                          return ListTile(title: Text(suggestion));
                        },
                        onSelected: (suggestion) {
                          _textControllerCustomer.text = suggestion;
                        },
                        builder: (context, controller, focusNode) {
                          // Sinkronkan controller internal builder dengan controller milik kita
                          controller.text = _textControllerCustomer.text;
                          controller.selection = TextSelection.fromPosition(
                            TextPosition(offset: controller.text.length),
                          );

                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            onChanged: (val) {
                              _textControllerCustomer.text = val;
                            },
                            decoration: InputDecoration(
                              labelText: 'Customer',
                              labelStyle: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                              hintText: 'Masukkan Customer',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              prefixIcon: Icon(Icons.people, color: Colors.grey[600]),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.blue, width: 2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.red, width: 1.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.red, width: 2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              errorStyle: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            validator: (value) =>
                            value == null || value.isEmpty ? 'Harap masukkan Customer' : null,
                          );
                        },
                      ),
                      const SizedBox(height: 30),
                      TypeAheadField<String>(
                        direction: VerticalDirection.up,
                        suggestionsCallback: (pattern) async {
                          return _tagList
                              .where((item) =>
                              item.toLowerCase().contains(pattern.toLowerCase()))
                              .toList();
                        },
                        itemBuilder: (context, suggestion) {
                          return ListTile(title: Text(suggestion));
                        },
                        onSelected: (suggestion) {
                          _textControllerType.text = suggestion;
                        },
                        builder: (context, controller, focusNode) {
                          controller.text = _textControllerType.text;
                          controller.selection = TextSelection.fromPosition(
                            TextPosition(offset: controller.text.length),
                          );

                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            onChanged: (val) {
                              _textControllerType.text = val;
                            },
                            decoration: InputDecoration(
                              labelText: 'Type',
                              labelStyle: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                              hintText: 'Masukkan Type',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              prefixIcon: Icon(Icons.label, color: Colors.grey[600]),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.blue, width: 2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.red, width: 1.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.red, width: 2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              errorStyle: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            validator: (value) =>
                            value == null || value.isEmpty ? 'Harap masukkan Type' : null,
                          );
                        },
                      ),
                      const SizedBox(height: 30),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          ),
                          child: const Text("Simpan", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

