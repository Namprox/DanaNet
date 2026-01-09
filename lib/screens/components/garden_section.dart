import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';

class GardenSection extends StatelessWidget {
  final int waterDrops;
  final int treeLevel;
  final int maxLevel;
  final Animation<double> scaleAnimation;
  final VoidCallback onWater;
  final VoidCallback onReset;

  const GardenSection({
    super.key,
    required this.waterDrops,
    required this.treeLevel,
    required this.maxLevel,
    required this.scaleAnimation,
    required this.onWater,
    required this.onReset,
  });

  String _getTreeIcon() {
    if (treeLevel == 1) return "🌱";
    if (treeLevel == 2) return "🌿";
    if (treeLevel == 3) return "🌳";
    if (treeLevel == 4) return "🍎";
    return "🌳";
  }

  @override
  Widget build(BuildContext context) {
    // Gọi Provider ngôn ngữ
    final lang = Provider.of<LanguageProvider>(context);
    bool isMaxLevel = treeLevel >= maxLevel;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [Colors.green.shade100, Colors.green.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 5))
          ]),
      child: Column(children: [
        // Tiêu đề dùng lang
        Text(lang.getText('your_garden'),
            style: const TextStyle(
                color: Colors.green, fontWeight: FontWeight.bold)),

        const SizedBox(height: 20),
        ScaleTransition(
          scale: scaleAnimation,
          child: Text(_getTreeIcon(), style: const TextStyle(fontSize: 100)),
        ),
        const SizedBox(height: 10),

        // Text Cấp độ
        Text(
            isMaxLevel
                ? lang.getText('level_max')
                : "${lang.getText('level')} $treeLevel",
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87)),

        const SizedBox(height: 20),

        if (isMaxLevel)
          ElevatedButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.autorenew),
            // Text Tái sinh
            label: Text(lang.getText('rebirth_tree')),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple, foregroundColor: Colors.white),
          )
        else
          ElevatedButton.icon(
            onPressed: waterDrops >= 20 ? onWater : null,
            icon: const Icon(Icons.water_drop),
            // Text Tưới cây
            label: Text(lang.getText('water_tree')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[300],
              disabledForegroundColor: Colors.grey[600],
            ),
          )
      ]),
    );
  }
}