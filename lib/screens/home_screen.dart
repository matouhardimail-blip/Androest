import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../theme.dart';
import '../chat_history_manager.dart';
import '../models/chat_session.dart';
import '../agent_manager.dart';
import 'chat_screen.dart';
import 'workspace_screen.dart';

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
    List<dynamic> agents = await AgentManager.loadAgents();
    var agent = agents.firstWhere((a) => a.id == session.agentId, orElse: () => null);
    
    if (agent != null) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ChatScreen(agent: agent, existingSession: session)),
        ).then((_) => _loadSessions());
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
                // الشريط العلوي
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.hexagon, color: AppColors.primary, size: 32),
                        const SizedBox(width: 10),
                        Text("AI HUB", style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.folder_special_rounded, color: AppColors.primary, size: 30),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WorkspaceScreen())),
                      tooltip: "مساحة عمل المشاريع",
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                
                // بطاقة الترحيب بتأثير Glassmorphism
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF7659E8).withOpacity(0.8),
                        const Color(0xFF358CFF).withOpacity(0.8)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
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
                      const Text("مرحباً بك مجدداً!", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 8),
                      const Text("ماذا تريد أن تنجز اليوم؟", style: TextStyle(color: Colors.white70, fontSize: 15)),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => widget.onTabChange(1),
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: const Text("اختر وكيلاً وابدأ", style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 35),

                Text("المحادثات الأخيرة", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_sessions.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(30.0),
                      child: Column(
                        children: [
                          Icon(Icons.forum_outlined, size: 50, color: AppColors.textSecondary),
                          SizedBox(height: 15),
                          Text("لا توجد محادثات سابقة.\nابدأ بإنشاء واحدة!", textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
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
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), shape: BoxShape.circle),
                            child: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary, size: 24),
                          ),
                          title: Text(session.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              "الوكيل: ${session.agentName}", 
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)
                            ),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textSecondary),
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