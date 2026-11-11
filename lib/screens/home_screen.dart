import 'package:flutter/material.dart';
import '../theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.hexagon, color: AppColors.primary, size: 30),
                      const SizedBox(width: 10),
                      Text("AI HUB", style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 22, letterSpacing: 1.2)),
                    ],
                  ),
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.cardBackground,
                    child: Icon(Icons.notifications_none, color: Colors.white, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7659E8), Color(0xFF358CFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Welcome Back!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 5),
                    const Text("Your AI journey starts here...", style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text("Create a Task"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const TextField(
                  decoration: InputDecoration(
                    hintText: "Search agents...",
                    hintStyle: TextStyle(color: AppColors.textSecondary),
                    prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Popular Agents", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 18)),
                  const Text("See all", style: TextStyle(color: AppColors.primary, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 15),
              SizedBox(
                height: 130,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildPopularAgent("ChatGPT", "GPT-4o", Icons.chat_bubble, const Color(0xFF10A37F)),
                    _buildPopularAgent("Claude", "Sonnet 3.5", Icons.psychology, const Color(0xFFD97757)),
                    _buildPopularAgent("Gemini", "2.5 Pro", Icons.auto_awesome, const Color(0xFF4285F4)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPopularAgent(String name, String model, IconData icon, Color color) {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const Spacer(),
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
          const SizedBox(height: 4),
          Text(model, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}