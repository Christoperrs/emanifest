import 'package:flutter/material.dart';
import 'pages/login_page.dart';
import 'pages/syncdata.dart';
import 'pages/job_list.dart';
import 'pages/kanban_tmmin.dart';
import 'pages/kanban_polybox.dart';
import 'pages/kanban_adm.dart';
import 'pages/kanban_hmmi.dart';
import 'pages/form_tag_sto.dart';
import 'pages/tarik_data_sap_page.dart';



void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Login Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => LoginPage(),
        '/dashboard': (context) => const DashboardPage(),
        '/joblist': (context) => JobList(),
        '/kanbanTmmin': (context) => KanbanTmmin(),
        '/kanbanHmmi': (context) => KanbanHmmi(),
        '/kanbanAdm': (context) => KanbanAdm(),
        '/kanbanPolybox': (context) => KanbanPolybox(),
        '/formSTO': (context) => FormSTOPage(),
        '/tarikDataSap': (context) => const TarikDataSapPage(),
      },
    );
  }
}
