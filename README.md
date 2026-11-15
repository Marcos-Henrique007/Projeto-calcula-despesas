# DividiTrip

Aplicativo Flutter para organizar despesas de viagens e eventos. Usa Provider/ChangeNotifier, SQLite para os dados locais, Firebase Authentication e uma outbox para envio ao Firestore.

## Acesso

O aplicativo abre sem exigir login, em **modo visitante**. Visitantes podem criar grupos, cadastrar participantes e registrar despesas com divisão igualitária. Esses dados ficam no aparelho e não são sincronizados nem compartilhados.

Ao entrar ou criar uma conta Firebase, grupos e despesas criados autenticados podem ser enviados à nuvem. O cadastro de uma conta no Firebase inicia uma sessão autenticada após a criação. Sair encerra essa sessão e volta ao modo visitante; os dados associados ao UID continuam locais, mas não aparecem na lista do visitante.

## Executar

A configuração Firebase Android e `lib/firebase_options.dart` já estão presentes neste workspace. O `main.dart` inicializa Firebase usando essas opções.

```sh
flutter pub get
flutter run
```

Use o [FIREBASE_SETUP.md](FIREBASE_SETUP.md) para verificar Authentication, Firestore, Storage e publicação das regras.

## O que já funciona

- Cadastro, login, logout e recuperação de senha Firebase com mensagens em português.
- Dashboard local de grupos e criação de grupo.
- Cadastro local de participantes.
- Criação de grupos com múltiplos tipos e inclusão automática de quem criou como participante.
- Cadastro de participantes e despesas localmente em SQLite, inclusive sem internet; despesas podem ser filtradas por período, categoria e pagador e excluídas com tombstone sincronizável.
- Cinco formas de divisão: igual, participantes selecionados, valores exatos, porcentagens e cotas/pesos.
- Data e comprovante opcional por câmera ou galeria; a imagem fica em armazenamento privado do app e é enviada ao Firebase Storage quando a despesa autenticada sincroniza.
- Conversão de despesas em BRL, USD, EUR, GBP, ARS e CLP para a moeda-base do grupo, com cotação online, manual e cache offline.
- Cálculo de saldos e simplificação de transferências usando valores inteiros em centavos.
- Registro local e sincronizado de pagamentos, com atualização dos saldos e histórico no grupo.
- Exportação e compartilhamento de fechamento PDF com despesas, categorias, saldos e pagamentos do grupo aberto.
- Outbox com UUID, revisão-base, envio idempotente ao Firestore e detecção de conflitos.
- Login, cadastro, Google, visitante e alternância entre temas claro e escuro.
- Regras de segurança iniciais em `firestore.rules` e `storage.rules`.

## Limitações atuais

Ainda faltam edição de grupos e despesas, uma interface para comparar e resolver conflitos e testes de widgets. A colaboração, entrada por convite e upload dependem de publicar as regras atualizadas no projeto Firebase. As regras em arquivo não são aplicadas automaticamente ao Console.

Veja [APRESENTACAO_MVVM.md](APRESENTACAO_MVVM.md), [SINCRONIZACAO.md](SINCRONIZACAO.md) e [ROTEIRO_VIDEO.md](ROTEIRO_VIDEO.md).

## Verificar

```sh
flutter analyze
flutter test
```
