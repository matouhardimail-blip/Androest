import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/agent_model.dart';

class AgentsScreen extends StatefulWidget {
  const AgentsScreen({super.key});

  @override
  State<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends State<AgentsScreen> {
  final List<AgentModel> agents = [
    AgentModel(id: '1', name: 'ChatGPT', description: 'Powerful assistant for everything', provider: 'OpenAI', model: 'GPT-4o', icon: Icons.chat, color: Colors.green, category: 'General', isConnected: true, capabilities: ['Text', 'Vision']),
    AgentModel(id: '2', name: 'Claude', description: 'Thoughtful & helpful AI', provider: 'Anthropic', model: 'Sonnet 3.5', icon: Icons.psychology, color: Colors.orange, category: 'General', isConnected: false, capabilities: ['Text', 'Code']),
    AgentModel(id: '3', name: 'DeepSeek', description: 'Advanced reasoning AI', provider: 'DeepSeek', model: 'DeepSeek-V3', icon: Icons.code, color: Colors.blue, category: 'Coding', isConnected: false, capabilities: ['Text', 'Code']),
    AgentModel(id: '4', name: 'Gemini', description: 'Google multimodal AI', provider: 'Google', model: '2.5 Pro', icon: Icons.auto_awesome, color: Colors.purple, category: 'General', isConnected: true, capabilities: ['Text', 'Vision']),
    AgentModel(id: '5', name: 'Perplexity', description: 'Real-time search & analysis', provider: 'Perplexity', model: 'Sonar', icon: Icons.search, color: Colors.teal, category: 'Research', isConnected: false, capabilities: ['Search']),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.arrow_back, color: Colors.white),
                  const SizedBox(width: 15),
                  Text("Discover Agents", style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: ['All', 'General', 'Coding', 'Research', 'Trading', 'Creative'].map((filter) {
                  return Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: filter == 'All' ? AppColors.primary : AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(filter, style: const TextStyle(color: Colors.white)),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: agents.length,
                itemBuilder: (context, index) {
                  final agent = agents[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 15),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: agent.color.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(agent.icon, color: agent.color, size: 30),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(agent.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 8, height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: agent.isConnected ? AppColors.success : Colors.grey,
                                    ),
                                  )
                                ],
                              ),
                              Text(agent.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.star, color: Colors.amber, size: 14),
                                  const SizedBox(width: 4),
                                  const Text("4.8", style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  const SizedBox(width: 10),
                                  Text(agent.provider, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: agent.isConnected ? AppColors.success.withOpacity(0.2) : AppColors.primary,
                            foregroundColor: agent.isConnected ? AppColors.success : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(agent.isConnected ? "Open" : "Connect"),
                        )
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}