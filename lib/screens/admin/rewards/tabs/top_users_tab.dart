import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TopUsersTab extends StatelessWidget {
  const TopUsersTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('greenPoints', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var data =
                snapshot.data!.docs[index].data() as Map<String, dynamic>;

            int points = data['greenPoints'] ?? 0;
            String name = data['name'] ?? data['userName'] ?? "User";
            String email = data['email'] ?? "";
            String phone = data['phone'] ?? "";
            String subInfo = email + (phone.isNotEmpty ? "\n$phone" : "");

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      index < 3 ? Colors.orange : Colors.green.shade200,
                  foregroundColor: Colors.white,
                  child: Text("${index + 1}",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                title: Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text(subInfo,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade200)),
                  child: Text("$points điểm",
                      style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            );
          },
        );
      },
    );
  }
}