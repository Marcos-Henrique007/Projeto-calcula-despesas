# Sincronização offline/online

## Visitante

Sem login, a interface opera apenas sobre SQLite. Grupos, participantes e despesas não entram na outbox e não são enviados à nuvem.

## Conta autenticada

SQLite continua sendo a fonte da interface. Uma gravação local autenticada insere dados e operação UUID na outbox na mesma transação. O SyncCoordinator tenta enviar quando a sessão existe e tenta novamente quando a conectividade retorna. Firestore recebe documentos em `groups/{groupId}` e subcoleções.

A transação Firestore grava um marcador em `groups/{groupId}/_operations/{operationId}`. Repetir a mesma operação não grava o documento uma segunda vez. A revisão atual é comparada com a revisão-base local antes de aplicar a alteração.

## Conflitos e limites

Uma divergência de revisão move a operação para `conflict` e salva payload local e remoto em `sync_conflicts`. Falha de rede mantém a operação pendente. Ainda falta uma tela para comparar e resolver conflitos.

A sincronização baixa os grupos listados em `users/{uid}/groups/{groupId}` e importa grupo, participantes, despesas, parcelas e acertos para SQLite. Uma operação local pendente ou em conflito impede a importação daquele registro, preservando a edição local para resolução explícita. A entrada por código valida `invites/{code}`, grava a associação do usuário e então importa o grupo. Grupos criados enquanto offline só ficam disponíveis para convite depois que a operação de criação sincronizar.

## Comprovantes

A imagem escolhida é copiada para armazenamento privado persistente do app e seu caminho local é salvo junto com a despesa e na operação da outbox. Quando a operação chega à vez de sincronizar, o serviço envia o arquivo para `groups/{groupId}/expenses/{expenseId}/receipt.{ext}` no Firebase Storage, grava o caminho remoto nos metadados da despesa no Firestore e atualiza `receipt_remote_path` no SQLite. Se o upload falhar, a operação permanece pendente e será tentada novamente; o caminho fixo por despesa evita criar cópias com nomes novos em cada tentativa. O envio requer as regras de Storage publicadas.
