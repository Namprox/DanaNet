import 'package:flutter/material.dart';
import 'tabs/rewards_management_tab.dart';
import 'tabs/top_users_tab.dart';
import 'tabs/transaction_history_tab.dart';
import 'tabs/redemption_history_tab.dart';

class AdminRewardsScreen extends StatefulWidget {
  const AdminRewardsScreen({super.key});

  @override
  State<AdminRewardsScreen> createState() => _AdminRewardsScreenState();
}

class _AdminRewardsScreenState extends State<AdminRewardsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.green.shade700,
          child: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: const [
              Tab(icon: Icon(Icons.card_giftcard), text: "Kho quà"),
              Tab(icon: Icon(Icons.people), text: "Top user"),
              Tab(icon: Icon(Icons.history), text: "Giao dịch"),
              Tab(icon: Icon(Icons.redeem), text: "Lịch sử"),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              RewardsManagementTab(),
              TopUsersTab(),
              TransactionHistoryTab(),
              RedemptionHistoryTab(),
            ],
          ),
        ),
      ],
    );
  }
}