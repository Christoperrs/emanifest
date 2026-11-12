import 'package:flutter/material.dart';

class MenuItemConfig {
  final IconData icon;
  final String label;
  final String route;
  final List<String> permissions;

  MenuItemConfig({
    required this.icon,
    required this.label,
    required this.route,
    this.permissions = const [],
  });
}

final List<MenuItemConfig> menuItems = [
  MenuItemConfig(
    icon: Icons.qr_code_scanner,
    label: 'Label Toyota',
    route: '/kanbanTmmin',
    permissions: ['cross_check_tmmin'],
  ),
  MenuItemConfig(
    icon: Icons.qr_code_scanner,
    label: 'Label Grup 2',
    route: '/kanbanHmmi',
    permissions: ['cross_check_hmmi'],
  ),
  MenuItemConfig(
    icon: Icons.qr_code_scanner,
    label: 'Label Daihatsu',
    route: '/kanbanAdm',
    permissions: ['cross_check_adm'],
  ),
  MenuItemConfig(
    icon: Icons.qr_code_scanner,
    label: 'Label ADM Polybox',
    route: '/kanbanPolybox',
    permissions: ['cross_check_adm'],
  ),

  MenuItemConfig(
    icon: Icons.report,
    label: 'E-Manifest Toyota',
    route: '/joblist',
    permissions: ['job_list'],
  ),
  MenuItemConfig(
    icon: Icons.search,
    label: 'STO',
    route: '/formSTO',
    permissions: ['form_sto'],
  ),
  MenuItemConfig(
    icon: Icons.cloud_download_outlined,
    label: 'Tarik Data SAP',
    route: '/tarikDataSap',
    permissions: [], // Selalu tampil untuk semua user
  )
];
