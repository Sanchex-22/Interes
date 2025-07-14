import 'package:flutter/material.dart';

class RankingScreen extends StatelessWidget {
  final List<Map<String, dynamic>> _users = [
    {'name': 'Carlos', 'rounds': 20},
    {'name': 'Ana', 'rounds': 18},
    {'name': 'Luis', 'rounds': 15},
    {'name': 'María', 'rounds': 12},
    {'name': 'Jorge', 'rounds': 10},
  ];

  @override
  Widget build(BuildContext context) {
    _users.sort((a, b) => b['rounds'].compareTo(a['rounds']));

    return Scaffold(
      appBar: AppBar(title: Text('Ranking por Vueltas')),
      body: ListView.builder(
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          return ListTile(
            leading: CircleAvatar(child: Text('#${index + 1}')),
            title: Text(user['name']),
            trailing: Text('${user['rounds']} vueltas'),
          );
        },
      ),
    );
  }
}
