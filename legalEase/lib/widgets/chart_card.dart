import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ChartCard extends StatelessWidget {
  final String title;
  const ChartCard({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    // Simple mini bar chart using fl_chart with mock data
    return Container(
      height: 140,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(title, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Expanded(
          child: BarChart(BarChartData(
            titlesData: FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            barGroups: [
              BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 3.5, width: 10)]),
              BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 2.2, width: 10)]),
              BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 4.0, width: 10)]),
              BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 1.8, width: 10)]),
            ],
          )),
        )
      ]),
    );
  }
}
