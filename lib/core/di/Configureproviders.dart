import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../data/local/database/app_database.dart';

import '../../data/repositories/expense_repository.dart';
import '../../data/repositories/group_repository.dart';
import '../../data/repositories/sync_outbox_repository.dart';

import '../../data/services/firebase_auth_service.dart';
import '../../data/services/firestore_sync_service.dart';
import '../../data/services/receipt_storage_service.dart';
import '../../data/services/group_report_service.dart';
import '../../data/services/exchange_rate_service.dart';
import '../../data/services/sync_coordinator.dart';

import '../../domain/services/financial_calculator.dart';

import '../../viewmodels/session_view_model.dart';
import '../../viewmodels/theme_view_model.dart';

Widget configureProviders({
  required ThemeViewModel themeViewModel,
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      // Tema.
      ChangeNotifierProvider<ThemeViewModel>.value(
        value: themeViewModel,
      ),

      // Banco de dados e conectividade.
      Provider<AppDatabase>(
        create: (_) => AppDatabase(),
      ),

      Provider<Connectivity>(
        create: (_) => Connectivity(),
      ),

      // Serviços.
      Provider<ExchangeRateService>(
        create: (context) => ExchangeRateService(
          database: context.read<AppDatabase>(),
        ),
      ),

      Provider<FirebaseAuthService>(
        create: (_) => FirebaseAuthService(
          FirebaseAuth.instance,
        ),
      ),

      Provider<ReceiptStorageService>(
        create: (_) => ReceiptStorageService(),
      ),

      Provider<GroupReportService>(
        create: (_) => GroupReportService(),
      ),

      // ViewModel da sessão.
      ChangeNotifierProvider<SessionViewModel>(
        create: (context) => SessionViewModel(
          context.read<FirebaseAuthService>(),
        ),
      ),

      // Repositórios.
      Provider<GroupRepository>(
        create: (context) => GroupRepository(
          context.read<AppDatabase>(),
        ),
      ),

      Provider<ExpenseRepository>(
        create: (context) => ExpenseRepository(
          context.read<AppDatabase>(),
        ),
      ),

      Provider<SyncOutboxRepository>(
        create: (context) => SyncOutboxRepository(
          context.read<AppDatabase>(),
        ),
      ),

      // Sincronização com Firebase.
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

      // Cálculos financeiros.
      Provider<FinancialCalculator>(
        create: (_) => const FinancialCalculator(),
      ),
    ],
    child: child,
  );
}

