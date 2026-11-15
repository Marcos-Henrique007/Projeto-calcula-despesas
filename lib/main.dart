import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/app_theme.dart';
import 'data/local/database/app_database.dart';
import 'data/repositories/expense_repository.dart';
import 'data/repositories/group_repository.dart';
import 'data/repositories/sync_outbox_repository.dart';
import 'data/services/firebase_auth_service.dart';
import 'data/services/firestore_sync_service.dart';
import 'data/services/receipt_storage_service.dart';
import 'data/services/group_report_service.dart';
import 'data/services/exchange_rate_service.dart';
import 'data/services/sync_coordinator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'domain/services/financial_calculator.dart';
import 'firebase_options.dart';
import 'viewmodels/session_view_model.dart';
import 'views/groups_view.dart';
import 'viewmodels/theme_view_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await GoogleSignIn.instance.initialize();
  final themeViewModel = ThemeViewModel();
  await themeViewModel.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeViewModel>.value(value: themeViewModel),
        Provider<AppDatabase>(create: (_) => AppDatabase()),
        Provider<Connectivity>(create: (_) => Connectivity()),
        Provider<ExchangeRateService>(
          create: (context) => ExchangeRateService(database: context.read<AppDatabase>()),
        ),
        Provider<FirebaseAuthService>(
          create: (_) => FirebaseAuthService(FirebaseAuth.instance),
        ),
        ChangeNotifierProvider<SessionViewModel>(
          create: (context) =>
              SessionViewModel(context.read<FirebaseAuthService>()),
        ),
        Provider<GroupRepository>(
          create: (context) => GroupRepository(context.read<AppDatabase>()),
        ),
        Provider<ReceiptStorageService>(create: (_) => ReceiptStorageService()),
        Provider<GroupReportService>(create: (_) => GroupReportService()),
        Provider<ExpenseRepository>(
          create: (context) => ExpenseRepository(context.read<AppDatabase>()),
        ),
        Provider<SyncOutboxRepository>(
          create: (context) => SyncOutboxRepository(context.read<AppDatabase>()),
        ),
        Provider<FirestoreSyncService>(
          create: (context) => FirestoreSyncService(
            firestore: FirebaseFirestore.instance,
            auth: FirebaseAuth.instance,
            storage: FirebaseStorage.instance,
            outbox: context.read<SyncOutboxRepository>(),
            database: context.read<AppDatabase>(),
          ),
        ),
        ChangeNotifierProvider<SyncCoordinator>(
          create: (context) => SyncCoordinator(
            auth: FirebaseAuth.instance,
            connectivity: context.read<Connectivity>(),
            syncService: context.read<FirestoreSyncService>(),
          ),
        ),
        Provider<FinancialCalculator>(
          create: (_) => const FinancialCalculator(),
        ),
      ],
      child: const DividiTripApp(),
    ),
  );
}

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
          ? const _StartupView()
          : GroupsView(key: ValueKey(session.actorId)),
    );
  }
}

class _StartupView extends StatelessWidget {
  const _StartupView();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.travel_explore, size: 56, color: Color(0xFF059669)),
              SizedBox(height: 20),
              CircularProgressIndicator(),
            ],
          ),
        ),
      );
}
