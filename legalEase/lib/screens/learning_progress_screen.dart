import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/learning_progress_service.dart';
import '../services/supabase_service.dart';
import 'package:fl_chart/fl_chart.dart';

class LearningProgressScreen extends StatefulWidget {
  const LearningProgressScreen({super.key});

  @override
  State<LearningProgressScreen> createState() => _LearningProgressScreenState();
}

class _LearningProgressScreenState extends State<LearningProgressScreen> {
  late final ValueNotifier<LearningProgress?> _progressNotifier;
  LearningProgress? _progress;
  List<LearningProgress> _weeklyProgress = [];

  @override
  void initState() {
    super.initState();
    _progressNotifier = LearningProgressService.instance.progressNotifier;
    _progress = _progressNotifier.value;
    _progressNotifier.addListener(_handleProgressChanged);
    _loadProgress();
  }

  void _handleProgressChanged() {
    if (!mounted) return;
    setState(() {
      _progress = _progressNotifier.value;
    });
  }

  Future<void> _loadProgress() async {
    await LearningProgressService.instance.refresh();
    final weekly = await LearningProgressService.instance.getWeeklyProgress();
    if (mounted) {
      setState(() {
        _weeklyProgress = weekly;
      });
    }
  }

  @override
  void dispose() {
    _progressNotifier.removeListener(_handleProgressChanged);
    super.dispose();
  }

  Widget _buildProgressCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyChart() {
    if (_weeklyProgress.isEmpty) {
      return Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            'No data for this week',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    final maxValue = _weeklyProgress
        .map((p) => p.knowledgeScore)
        .fold(0.0, (a, b) => a > b ? a : b);

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: _weeklyProgress.asMap().entries.map((entry) {
                return FlSpot(
                  entry.key.toDouble(),
                  entry.value.knowledgeScore,
                );
              }).toList(),
              isCurved: true,
              color: AppTheme.accent,
              barWidth: 3,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: AppTheme.accent.withOpacity(0.1),
              ),
            ),
          ],
          minY: 0,
          maxY: maxValue > 0 ? maxValue * 1.2 : 100,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!SupabaseService.isAuthenticated) {
      return Scaffold(
        backgroundColor: AppTheme.primary,
        appBar: AppBar(
          title: const Text('Learning Progress'),
          backgroundColor: AppTheme.primary,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.trending_up, size: 64, color: Colors.white70),
              const SizedBox(height: 16),
              const Text(
                'Please sign in to view learning progress',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/signin'),
                child: const Text('Sign In'),
              ),
            ],
          ),
        ),
      );
    }

    final progress = _progress ?? LearningProgress(
      id: '',
      userId: SupabaseService.currentUser!.id,
      date: DateTime.now(),
    );

    return Scaffold(
      backgroundColor: AppTheme.primary,
      appBar: AppBar(
        title: const Text('Learning Progress'),
        backgroundColor: AppTheme.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProgress,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProgress,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Knowledge Score Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Knowledge Score',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 150,
                          height: 150,
                          child: CircularProgressIndicator(
                            value: progress.knowledgeScore / 100,
                            strokeWidth: 12,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
                          ),
                        ),
                        Column(
                          children: [
                            Text(
                              '${progress.knowledgeScore.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Today',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Stats Row
              Row(
                children: [
                  _buildProgressCard(
                    'Time Spent',
                    '${progress.timeSpentMinutes}m',
                    Icons.access_time,
                    Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  _buildProgressCard(
                    'Articles',
                    '${progress.articlesViewed}',
                    Icons.article,
                    Colors.green,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  _buildProgressCard(
                    'Queries',
                    '${progress.queriesMade}',
                    Icons.chat,
                    Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  _buildProgressCard(
                    'Topics',
                    '${progress.topicsStudied.length}',
                    Icons.gavel,
                    Colors.purple,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              const Text(
                'Weekly Progress',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              _buildWeeklyChart(),

              const SizedBox(height: 24),

              // Topics Studied
              if (progress.topicsStudied.isNotEmpty) ...[
                const Text(
                  'Topics Studied',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: progress.topicsStudied.map((topicId) {
                      return Chip(
                        label: Text(topicId.substring(0, 8)),
                        backgroundColor: AppTheme.accent.withOpacity(0.2),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

