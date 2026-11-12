import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

Map<String, dynamic> decodeJwtPayload(String token) {
  return JwtDecoder.decode(token);
}

class CustomDrawer extends StatelessWidget {
  final Color primaryColor = Colors.teal;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: FutureBuilder<String?>(
        future: SharedPreferences.getInstance().then((prefs) => prefs.getString('jwt_token')),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final token = snapshot.data!;
          final payload = decodeJwtPayload(token);
          final accessPayload = List<String>.from(payload['payload'] ?? []);

          return Column(
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, primaryColor.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Image.asset('assets/img/icon-maj.png', width: 60),
                        SizedBox(width: 10),
                        Image.asset('assets/img/toyota-icon.png', width: 60),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      "E - Manifest",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "PT Mekar Armada Jaya",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Menu Section
              Expanded(
                child: ListView(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  children: [
                    if (accessPayload.contains('job_list'))
                      _buildDrawerItem(
                        icon: Icons.list_alt,
                        label: "Job List",
                        context: context,
                        routeName: '/joblist',
                      ),

                    if (accessPayload.contains('sync_data'))
                      _buildDrawerItem(
                        icon: Icons.sync,
                        label: "Sync Data",
                        context: context,
                        routeName: '/dashboard',
                      ),

                    if (accessPayload.contains('cross_check_tmmin'))
                      _buildDrawerItem(
                        icon: Icons.assignment_turned_in,
                        label: "Cross Check Kanban TMMIN",
                        context: context,
                        routeName: '/kanbanTmmin',
                      ),

                    if (accessPayload.contains('cross_check_hmmi'))
                      _buildDrawerItem(
                        icon: Icons.assignment_turned_in,
                        label: "Cross Check Kanban HMMI",
                        context: context,
                        routeName: '/kanbanHmmi',
                      ),



                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required BuildContext context,
    required String routeName,
  }) {
    return ListTile(
      leading: Icon(icon, color: primaryColor),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      horizontalTitleGap: 8,
      onTap: () {
        Navigator.pop(context);
        Navigator.pushNamed(context, routeName);
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      hoverColor: primaryColor.withOpacity(0.05),
      splashColor: primaryColor.withOpacity(0.1),
    );
  }
}

