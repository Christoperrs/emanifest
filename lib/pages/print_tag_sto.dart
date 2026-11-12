import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';

class PrintPage extends StatelessWidget {
  final String partNumber;
  final String jobNumber;
  final String partDesc;
  final String customer;
  final String tagSto;
  final String type;
  final String area;

  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

  PrintPage({
    required this.partNumber,
    required this.jobNumber,
    required this.partDesc,
    required this.customer,
    required this.type,
    required this.tagSto,
    required this.area,
  });

  void printStruk() async {
    List<BluetoothDevice> devices = await bluetooth.getBondedDevices();

    if (devices.isNotEmpty) {
      await bluetooth.connect(devices[0]);

      bluetooth.printNewLine();
      bluetooth.printCustom("PT. MEKAR ARMADA JAYA - TAMBUN", 1, 0);
      bluetooth.printCustom("--------------------------------", 0, 0);
      bluetooth.printCustom("TAG STO: $tagSto", 0, 0);
      bluetooth.printCustom("Area: $area", 0, 0);
      bluetooth.printCustom("Part Number: $partNumber", 0, 0);
      bluetooth.printCustom("Job Number: $jobNumber", 0, 0);
      bluetooth.printCustom("Deskripsi: $partDesc", 0, 0);
      bluetooth.printCustom("Customer: $customer", 0, 0);
      bluetooth.printCustom("Type: $type", 0, 0);
      bluetooth.printCustom("--------------------------------", 0, 1);

      bluetooth.printQRcode("$tagSto", 230, 230, 1);

      bluetooth.printNewLine();
      bluetooth.printCustom("-- IT Department --", 1, 1);
      bluetooth.paperCut();

      await Future.delayed(Duration(seconds: 1));
      bluetooth.disconnect();
    } else {
      print("Tidak ada perangkat printer yang terhubung.");
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Struk STO"),
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          width: 250, // Lebar kertas struk kecil
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "PT. MEKAR ARMADA JAYA",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              Text(
                "--------------------------------",
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 5),
              Text(
                "TAG STO: $tagSto",
                style: TextStyle(fontSize: 14, fontFamily: 'Courier'),
                textAlign: TextAlign.center,
              ),
              Text(
                "Area: $area",
                style: TextStyle(fontSize: 14, fontFamily: 'Courier'),
                textAlign: TextAlign.center,
              ),
              Text(
                "Area: $partNumber",
                style: TextStyle(fontSize: 14, fontFamily: 'Courier'),
                textAlign: TextAlign.center,
              ),
              Text(
                "Area: $jobNumber",
                style: TextStyle(fontSize: 14, fontFamily: 'Courier'),
                textAlign: TextAlign.center,
              ),
              Text(
                "Area: $partDesc",
                style: TextStyle(fontSize: 14, fontFamily: 'Courier'),
                textAlign: TextAlign.center,
              ),
              Text(
                "Area: $customer",
                style: TextStyle(fontSize: 14, fontFamily: 'Courier'),
                textAlign: TextAlign.center,
              ),
              Text(
                "Area: $type",
                style: TextStyle(fontSize: 14, fontFamily: 'Courier'),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10),
              Text(
                "--------------------------------",
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 10),

              // QR Code
              QrImageView(
                data: "$tagSto",
                size: 100,
                version: QrVersions.auto,
              ),

              SizedBox(height: 10),
              Text(
                "-- IT Departement --",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),

              ElevatedButton(
                onPressed: () {
                  printStruk();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                ),
                child: Text(
                  "Print",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
