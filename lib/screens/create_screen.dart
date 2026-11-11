import 'package:flutter/material.dart';
import '../theme.dart';

class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key});

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  bool isChatGPTSelected = true;
  bool isClaudeSelected = true;
  bool isPerplexitySelected = false;

  void _showResults() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text("Results", style: TextStyle(color: Colors.white)),
        content: const Text("المهمة قيد التنفيذ... هذه مجرد واجهة تجريبية حالياً.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إغلاق", style: TextStyle(color: AppColors.primary)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Multi-Agent Task", style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.hub, color: Colors.white),
                    ),
                    const SizedBox(width: 15),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Main Orchestrator", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                          Text("Divide and coordinate the task", style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              Text("Task Description", style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(15)),
                child: const TextField(
                  maxLines: 4,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "e.g., Build a complete trading analysis for XAUUSD...",
                    hintStyle: TextStyle(color: AppColors.textSecondary),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(15),
                  ),
                ),
              ),
              const SizedBox(height: 25),
              Text("Select Agents:", style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              _buildAgentSelect(
                "ChatGPT", "Analysis & Research", Icons.chat, Colors.green, isChatGPTSelected,
                (val) => setState(() => isChatGPTSelected = val!)
              ),
              _buildAgentSelect(
                "Claude", "Deep Analysis", Icons.psychology, Colors.orange, isClaudeSelected,
                (val) => setState(() => isClaudeSelected = val!)
              ),
              _buildAgentSelect(
                "Perplexity", "Real-time Data", Icons.search, Colors.teal, isPerplexitySelected,
                (val) => setState(() => isPerplexitySelected = val!)
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Executing tasks...", style: TextStyle(color: Colors.white)),
                        Text("75%", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: 0.75,
                      backgroundColor: AppColors.textSecondary.withOpacity(0.2),
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _showResults,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: const Text("View Results", style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgentSelect(String name, String desc, IconData icon, Color color, bool isSelected, Function(bool?) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(desc, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Checkbox(
            value: isSelected,
            activeColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}