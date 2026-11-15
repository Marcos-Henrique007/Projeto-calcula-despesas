# Arquitetura MVVM do DividiTrip

## Camadas

- **View** (`lib/views`): telas de autenticação, grupos e detalhes; coleta entrada e apresenta estados.
- **ViewModel** (`lib/viewmodels`): gerencia sessão Firebase, estado da lista/detalhe, validações e comandos.
- **Model** (`lib/domain`): grupo de viagem e cálculo financeiro, sem dependência da interface. Dinheiro é guardado em centavos.
- **Repository** (`lib/data/repositories`): grava grupos, participantes, despesas e fila de sincronização no SQLite.
- **Service** (`lib/data/services`): Authentication, Firestore, cotações e coordenação da sincronização.
- **Persistência local** (`lib/data/local/database`): SQLite é a fonte lida pelas telas, inclusive no modo visitante.

## Visitante e conta autenticada

Visitante usa um identificador local e salva grupos, participantes e despesas no SQLite. Nenhuma operação visitante entra na outbox. Autenticar habilita o envio de novas alterações ao Firestore. O cadastro de uma conta Firebase cria também uma sessão autenticada, conforme o fluxo padrão do Firebase Auth. Sair volta ao modo visitante.

## Fluxo de gravação de despesa

1. A View valida descrição, valor e pagador.
2. O ViewModel divide o total em centavos e chama o Repository.
3. O Repository grava despesa e parcelas dentro de uma transação SQLite. Quando há usuário autenticado, grava também a operação pendente na outbox.
4. A ViewModel atualiza a tela lendo novamente SQLite.
5. O SyncCoordinator tenta enviar a outbox ao Firestore e repete quando a conectividade retorna.
6. Revisões divergentes são registradas como conflito para não substituir dados silenciosamente.

## Estado da implementação

Login/cadastro/recuperação, dashboard de grupos local, participantes, criação/listagem de despesas e os cinco modos de divisão estão conectados. Edição, pagamentos registrados, relatórios e recebimento de atualizações remotas ainda não estão conectados às telas.
