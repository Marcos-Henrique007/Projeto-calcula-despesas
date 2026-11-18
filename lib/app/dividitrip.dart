import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import '../viewmodels/session_view_model.dart';
import '../viewmodels/theme_view_model.dart';
import '../views/groups_view.dart';

class DividiTripApp extends StatelessWidget {
  const DividiTripApp({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionViewModel>();
    final themeViewModel = context.watch<ThemeViewModel>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DividiTrip',

      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeViewModel.themeMode,

      home: session.isLoading
          ? const StartupView()
          : GroupsView(
        key: ValueKey(session.actorId),
      ),
    );
  }
}

class StartupView extends StatelessWidget {
  const StartupView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.travel_explore,
              size: 56,
              color: Color(0xFF059669),
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
