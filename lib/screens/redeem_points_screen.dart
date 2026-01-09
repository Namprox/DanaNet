import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

class RedeemPointsScreen extends StatefulWidget {
  const RedeemPointsScreen({super.key});

  @override
  State<RedeemPointsScreen> createState() => _RedeemPointsScreenState();
}

class _RedeemPointsScreenState extends State<RedeemPointsScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  bool isRecalculating = false;

  // Thêm tham số lang
  void _showSupportInfo(LanguageProvider lang) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.blue),
            const SizedBox(width: 10),
            Text(lang.getText('support_info_title'),
                style: const TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.getText('important_note'),
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const SizedBox(height: 10),
            Text(
              lang.getText('support_desc'),
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, foregroundColor: Colors.white),
            child: Text(lang.getText('understood')),
          ),
        ],
      ),
    );
  }

  // Thêm tham số lang
  Future<void> _recalculatePoints(LanguageProvider lang) async {
    if (currentUser == null) return;

    setState(() => isRecalculating = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final uid = currentUser!.uid;

      QuerySnapshot soldPostsSnapshot = await firestore
          .collection('scrap_posts')
          .where('uid', isEqualTo: uid)
          .where('role', isEqualTo: 'seller')
          .where('status', isEqualTo: 'completed')
          .get();

      int totalEarned = soldPostsSnapshot.docs.length * 10;

      QuerySnapshot spentSnapshot = await firestore
          .collection('redemptions')
          .where('uid', isEqualTo: uid)
          .get();

      int totalSpent = 0;
      for (var doc in spentSnapshot.docs) {
        totalSpent += (doc['pointsSpent'] as num).toInt();
      }

      int realPoints = totalEarned - totalSpent;
      if (realPoints < 0) realPoints = 0;

      await firestore.collection('users').doc(uid).update({
        'greenPoints': realPoints,
        'totalSales': soldPostsSnapshot.docs.length,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("${lang.getText('sync_success')} $realPoints"),
              backgroundColor: Colors.blue),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("${lang.getText('sync_error')} $e")));
      }
    } finally {
      if (mounted) setState(() => isRecalculating = false);
    }
  }

  // Thêm tham số lang
  Future<void> _redeemReward(String rewardId, String rewardTitle, int cost,
      int currentPoints, LanguageProvider lang) async {
    if (currentUser == null) return;

    if (currentPoints < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(lang.getText('not_enough_points_msg')),
            backgroundColor: Colors.red),
      );
      return;
    }

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.getText('confirm_redeem')),
        // Text ghép chuỗi động
        content: Text(
            "${lang.getText('redeem_ask_1')} $cost ${lang.getText('redeem_ask_2')} '$rewardTitle'?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(lang.getText('cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(lang.getText('redeem_now')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentReference userRef = FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid);
        DocumentSnapshot userSnapshot = await transaction.get(userRef);
        int latestPoints =
            (userSnapshot.data() as Map<String, dynamic>)['greenPoints'] ?? 0;

        if (latestPoints < cost) {
          throw Exception(lang.getText('insufficient_points_err'));
        }

        transaction.update(userRef, {
          'greenPoints': FieldValue.increment(-cost),
        });

        DocumentReference historyRef =
            FirebaseFirestore.instance.collection('redemptions').doc();
        transaction.set(historyRef, {
          'uid': currentUser!.uid,
          'rewardId': rewardId,
          'rewardTitle': rewardTitle,
          'pointsSpent': cost,
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
        });
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(lang.getText('redeem_success_title'),
                        style: const TextStyle(fontSize: 18))),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    "${lang.getText('redeem_success_msg_1')} '$rewardTitle'."),
                const SizedBox(height: 15),
                Text(
                  lang.getText('important_note'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.red),
                ),
                const SizedBox(height: 5),
                Text(
                  lang.getText('support_desc'),
                  style: const TextStyle(height: 1.5),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white),
                child: Text(lang.getText('understood')),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("${lang.getText('error')}: $e"),
            backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildRewardImage(String? imageSource) {
    if (imageSource == null || imageSource.isEmpty) {
      return Container(
        height: 150,
        width: double.infinity,
        color: Colors.grey[200],
        child: const Icon(Icons.card_giftcard, size: 50, color: Colors.grey),
      );
    }

    if (imageSource.startsWith('http')) {
      return Image.network(
        imageSource,
        height: 150,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => Container(
            height: 150,
            width: double.infinity,
            color: Colors.grey[200],
            child: const Icon(Icons.broken_image)),
      );
    } else {
      try {
        return Image.memory(
          base64Decode(imageSource),
          height: 150,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => Container(
              height: 150,
              width: double.infinity,
              color: Colors.grey[200],
              child: const Icon(Icons.broken_image)),
        );
      } catch (e) {
        return Container(
            height: 150,
            width: double.infinity,
            color: Colors.grey[200],
            child: const Icon(Icons.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lắng nghe ngôn ngữ
    final lang = Provider.of<LanguageProvider>(context);

    if (currentUser == null) {
      return Scaffold(
          body: Center(child: Text(lang.getText('login_required'))));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.getText('redeem_title')),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.error_outline),
            tooltip: lang.getText('support_info_title'),
            onPressed: () => _showSupportInfo(lang),
          ),
          isRecalculating
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(color: Colors.white))
              : IconButton(
                  icon: const Icon(Icons.sync),
                  tooltip: lang.getText('sync_points'),
                  onPressed: () => _recalculatePoints(lang),
                )
        ],
      ),
      body: Column(
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser!.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const LinearProgressIndicator();
              var userData = snapshot.data!.data() as Map<String, dynamic>;
              int myPoints = userData['greenPoints'] ?? 0;

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border:
                      Border(bottom: BorderSide(color: Colors.green.shade200)),
                ),
                child: Column(
                  children: [
                    Text(lang.getText('your_points'),
                        style:
                            const TextStyle(fontSize: 16, color: Colors.grey)),
                    const SizedBox(height: 5),
                    Text(
                      "$myPoints ☘️",
                      style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.green),
                    ),
                    if (myPoints == 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(lang.getText('earn_points_hint'),
                            style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.green.shade900)),
                      )
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('rewards').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                      child: Text(lang.getText('no_rewards')));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    Map<String, dynamic> data =
                        doc.data() as Map<String, dynamic>;

                    String title =
                        data['title'] ?? lang.getText('gift_default');
                    int cost = data['pointsRequired'] ?? 0;
                    String desc = data['description'] ?? "";
                    String? imageUrl = data['imageUrl'];

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12)),
                            child: _buildRewardImage(imageUrl),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                        child: Text(title,
                                            style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold))),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                          color: Colors.orange.shade100,
                                          borderRadius:
                                              BorderRadius.circular(20)),
                                      child: Text(
                                          "$cost ${lang.getText('points')}",
                                          style: TextStyle(
                                              color: Colors.orange.shade900,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(desc,
                                    style: TextStyle(color: Colors.grey[600]),
                                    maxLines: 2),
                                const SizedBox(height: 15),
                                SizedBox(
                                  width: double.infinity,
                                  child: StreamBuilder<DocumentSnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(currentUser!.uid)
                                        .snapshots(),
                                    builder: (context, userSnap) {
                                      int currentPoints = 0;
                                      if (userSnap.hasData &&
                                          userSnap.data!.exists) {
                                        currentPoints = (userSnap.data!.data()
                                                    as Map<String, dynamic>)[
                                                'greenPoints'] ??
                                            0;
                                      }
                                      bool canRedeem = currentPoints >= cost;
                                      return ElevatedButton(
                                        onPressed: canRedeem
                                            ? () => _redeemReward(
                                                doc.id,
                                                title,
                                                cost,
                                                currentPoints,
                                                lang)
                                            : null,
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: canRedeem
                                                ? Colors.green
                                                : Colors.grey,
                                            foregroundColor: Colors.white),
                                        child: Text(canRedeem
                                            ? lang.getText('redeem_now_btn')
                                            : lang.getText(
                                                'not_enough_points_btn')),
                                      );
                                    },
                                  ),
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}