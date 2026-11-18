import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase_options.dart';
import 'app/dividitrip.dart';
import 'core/di/configureproviders.dart';
import 'viewmodels/theme_view_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o Firebase.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Inicializa o Google Sign-In.
  await GoogleSignIn.instance.initialize();

  // Carrega as preferências de tema.
  final themeViewModel = ThemeViewModel();
  await themeViewModel.load();

  // Configura as dependências e inicia o aplicativo.
  runApp(
    configureProviders(
      themeViewModel: themeViewModel,
      child: const DividiTripApp(),
    ),
  );
}
