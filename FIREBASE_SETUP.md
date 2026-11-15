# Firebase do DividiTrip

O workspace já contém `lib/firebase_options.dart`, `android/app/google-services.json` e os plugins Android correspondentes. `main.dart` chama `Firebase.initializeApp` com as opções geradas. Não execute novamente `flutterfire configure` sem intenção de trocar o projeto Firebase.

## Conferir no Console Firebase

1. Em Authentication > Sign-in method, habilite E-mail/Senha e Google. Se solicitado, informe o nome de suporte e o e-mail de suporte do projeto.
2. Em Configurações do projeto > Seus apps > app Android, cadastre as impressões digitais SHA-1 para as variantes usadas (debug e release) e baixe novamente o `google-services.json` se o Console atualizar os clientes OAuth.
3. Confirme que `android/app/google-services.json` contém um cliente OAuth do tipo Web (client type 3), necessário para obter o ID token usado pelo Firebase Auth.
4. Confirme que o Cloud Firestore está criado.
5. Confirme que o bucket Firebase Storage está criado.
6. Publique `firestore.rules` no Firestore Rules e `storage.rules` no Storage Rules. Revise as regras no Console antes de publicar.
7. Confirme que o applicationId Android registrado corresponde a `android/app/build.gradle.kts`.

Não coloque chaves privadas ou credenciais de conta de serviço no aplicativo. Os arquivos locais de configuração Firebase são os gerados para este app e não substituem regras de segurança.

## Coleções usadas pelo código

- `users/{uid}/groups/{groupId}` (índice de grupos do usuário)
- `invites/{code}` (código de entrada)
- `groups/{groupId}`
- `groups/{groupId}/members/{uid}`
- `groups/{groupId}/participants/{participantId}`
- `groups/{groupId}/expenses/{expenseId}`
- `groups/{groupId}/settlements/{settlementId}`
- `groups/{groupId}/_operations/{operationId}`
- Comprovantes em Storage: `groups/{groupId}/expenses/{expenseId}/receipt.{ext}`

O criador autenticado do grupo recebe papel owner durante a primeira operação de sincronização, que também cria o índice em `users/{uid}/groups` e o convite. Quem entra com código ganha papel member e os dados do grupo são baixados para SQLite. O modo visitante não cria documentos na nuvem.

## Revisão e publicação das regras

As regras em `firestore.rules` e `storage.rules` são um protótipo com validações de identidade, papel, esquema, tamanhos e caminhos. Revise e teste-as com contas de owner, membro e não membro antes de distribuir o app. As regras do Firestore não conseguem conferir a soma dos valores do mapa de parcelas; essa validação permanece no app.

O projeto está associado ao Firebase CLI e os caminhos das regras estão registrados em `firebase.json`. Depois de validar no emulador e aprovar os arquivos, publique somente as regras com:

```powershell
npx -y firebase-tools@latest deploy --only firestore:rules,storage --project calcula-despesa-amigos
```

Esse comando altera regras no projeto remoto. Não use `--force`; não publique até revisar o diff e validar os fluxos. Regras de Storage consultam documentos do Firestore; ao publicar pela primeira vez, o Console/CLI pode pedir para habilitar essa integração.
