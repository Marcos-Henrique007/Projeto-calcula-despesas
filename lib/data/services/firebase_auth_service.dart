import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseAuthService {
  FirebaseAuthService(this._auth);

  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) throw const AuthFlowException('Não foi possível criar a conta.');
      await user.updateDisplayName(name.trim());
      await user.reload();
      return _auth.currentUser ?? user;
    } on FirebaseAuthException catch (error) {
      throw AuthFlowException(_messageFor(error.code));
    }
  }

  Future<User> signIn({required String email, required String password}) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = result.user;
      if (user == null) throw const AuthFlowException('Não foi possível entrar.');
      return user;
    } on FirebaseAuthException catch (error) {
      throw AuthFlowException(_messageFor(error.code));
    }
  }

  Future<User> signInWithGoogle() async {
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const AuthFlowException(
          'O Google não retornou um token. Confira o cliente OAuth Web no Firebase.',
        );
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final result = await _auth.signInWithCredential(credential);
      final user = result.user;
      if (user == null) {
        throw const AuthFlowException('Não foi possível entrar com o Google.');
      }
      return user;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthFlowException(
          'O Google encerrou a seleção. Se você escolheu uma conta, confira no Firebase/Google Cloud se a SHA-1 desta build está cadastrada para o pacote com.example.projeto_calcula_despesas e se o login Google está habilitado.',
        );
      }
      throw AuthFlowException(
        error.description ?? 'Não foi possível abrir o seletor de contas Google.',
      );
    } on FirebaseAuthException catch (error) {
      throw AuthFlowException(_messageFor(error.code));
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw AuthFlowException(_messageFor(error.code));
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await GoogleSignIn.instance.signOut();
  }

  String _messageFor(String code) => switch (code) {
        'invalid-email' => 'Informe um e-mail válido.',
        'email-already-in-use' => 'Já existe uma conta com este e-mail.',
        'weak-password' => 'A senha precisa ter pelo menos 6 caracteres.',
        'user-not-found' || 'wrong-password' || 'invalid-credential' =>
          'E-mail ou senha incorretos.',
        'network-request-failed' => 'Sem conexão. Tente novamente quando estiver online.',
        'too-many-requests' => 'Muitas tentativas. Aguarde e tente novamente.',
        _ => 'Não foi possível concluir a autenticação. Tente novamente.',
      };
}

class AuthFlowException implements Exception {
  const AuthFlowException(this.message);
  final String message;

  @override
  String toString() => message;
}
