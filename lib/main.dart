import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'viewmodels/settlement_view_model.dart';
import 'views/settlement_view.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => SettlementViewModel(),
      child: const SplitWayApp(),
    ),
  );
}

class SplitWayApp extends StatelessWidget {
  const SplitWayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SplitWay',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
        ),
      ),
      home: const SettlementView(),
    );
  }
}