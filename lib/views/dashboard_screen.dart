import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'my_items_screen.dart';
import 'report_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = SupabaseService();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () async {
              // 1. Call the service to clear Supabase session
              await service.signOut();

              // 2. Navigate to Login and remove all previous screens from memory
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login', // Replace with your actual login route name
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome back, ${service.currentUser?.email?.split('@')[0] ?? 'User'}!",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // --- STATISTICS SECTION ---
            FutureBuilder<Map<String, int>>(
              future: service.getUserStats(),
              builder: (context, snapshot) {
                final active = snapshot.data?['active'] ?? 0;
                final resolved = snapshot.data?['resolved'] ?? 0;

                return Row(
                  children: [
                    _buildStatCard("Active", active.toString(), Colors.blue),
                    const SizedBox(width: 15),
                    _buildStatCard(
                      "Resolved",
                      resolved.toString(),
                      Colors.green,
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 30),
            const Text(
              "Quick Actions",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),

            // --- QUICK ACTIONS GRID ---
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 15,
              crossAxisSpacing: 15,
              childAspectRatio: 1.5,
              children: [
                _buildActionCard(
                  context,
                  "Report Item",
                  Icons.add_circle_outline,
                  Colors.orange,
                  const ReportScreen(),
                ),
                _buildActionCard(
                  context,
                  "My Items",
                  Icons.list_alt,
                  Colors.purple,
                  const MyItemsScreen(),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // --- INFO BANNER ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[700]!, Colors.blue[400]!],
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Row(
                children: [
                  Icon(Icons.tips_and_updates, color: Colors.white, size: 40),
                  SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      "Tip: Detailed descriptions and clear photos lead to 80% faster resolutions!",
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to build Stats Cards
  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
          ],
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // Helper to build Quick Action Cards
  Widget _buildActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    Widget destination,
  ) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => destination),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
