import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../theme.dart';
import '../chat_history_manager.dart';
import '../models/chat_session.dart';
import '../agent_manager.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(int) onTabChange;
  const HomeScreen({super.key, required this.onTabChange});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ChatSession> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    _sessions = await ChatHistoryManager.loadSessions();
    setState(() => _isLoading = false);
  }

  Future<void> _openSession(ChatSession session) async {
    // جلب الوكيل المرتبط بهذه المحادثة
    List<dynamic> agents = await AgentManager.loadAgents();
    var agent = agents.firstWhere((a) => a.id == session.agentId, orElse: () => null);
    
    if (agent != null) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ChatScreen(agent: agent, existingSession: session)),
        ).then((_) => _loadSessions()); // إعادة تحديث القائمة عند العودة
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("الوكيل المرتبط بهذه المحادثة قد تم حذفه.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadSessions,
          color: AppColors.primary,
          backgroundColor: AppColors.cardBackground,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                  ],
                ),
                const SizedBox(height: 25),
                
                // زر إنشاء محادثة جديدة
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
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("مرحباً بك مجدداً!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 5),
                      const Text("هل تريد بدء مهمة جديدة؟", style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () => widget.onTabChange(1), // الانتقال لتبويب الوكلاء
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text("اختر وكيلاً وابدأ"),
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

                Text("المحادثات الأخيرة", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 18)),
                const SizedBox(height: 15),
                
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_sessions.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text("لا توجد محادثات سابقة. ابدأ بإنشاء واحدة!", style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _sessions.length,
                    itemBuilder: (context, index) {
                      final session = _sessions[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.primary,
                            child: Icon(Icons.chat, color: Colors.white, size: 20),
                          ),
                          title: Text(session.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            "الوكيل: ${session.agentName} | ${session.lastUpdated.toString().substring(0, 16)}", 
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
                          onTap: () => _openSession(session),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}