# Revisão das regras Firebase (rascunho)

O Firebase CLI encontrou o banco Firestore Native, edição Standard, database (default), na região nam5. O app está associado ao mesmo projeto Firebase configurado em firebase.json.

## Acesso e consultas observadas

O cliente usa Firebase Auth. As leituras e gravações Firestore estão em lib/data/services/firestore_sync_service.dart:

- users/{uid}/groups/{groupId}: lista o índice do usuário autenticado.
- invites/{code}: leitura pontual por código; criação junto com o primeiro grupo.
- groups/{groupId}: leitura do documento de grupo.
- Subcoleções members, participants, expenses, settlements e _operations.
- Consulta filtrada: participants.where('uid', isEqualTo: actorUid).limit(1).
- Não há orderBy remoto; os filtros e ordenação de despesas são aplicados no SQLite.

## Regras de negócio representadas

- Leitura de dados do grupo só para membros; a listagem dos próprios índices de grupo só para o usuário correspondente.
- O grupo só é criado com ownerUid e createdBy iguais ao UID autenticado.
- Código de convite só pode ser lido individualmente por usuário autenticado; a listagem é negada.
- Entrada exige documento de convite que aponte ao grupo, cria somente o papel member e o próprio participante.
- Alterações de grupo exigem owner/admin. Despesas podem ser alteradas/excluídas logicamente por seu criador ou owner/admin.
- Valores monetários são inteiros em centavos e limitados; moeda, categoria, modo de divisão, strings e tamanho dos mapas são limitados.
- Storage restringe os comprovantes ao diretório do grupo/despesa, somente imagens permitidas e menos de 10 MiB.
- Marcadores de outbox são idempotentes e não podem ser alterados depois de criados.

## Limitações e riscos conhecidos

- As regras não conseguem iterar de forma geral pelas entradas de shares para provar no servidor que cada parcela é válida e a soma corresponde ao total. Essa invariável é validada no cliente/SQLite; para imposição autoritativa no backend, use Cloud Functions.
- O bootstrap da sincronização faz get de IDs aleatórios ainda inexistentes para grupo e marcador. Regras permitem esse get autenticado somente quando o documento ainda não existe; o conteúdo de documentos existentes continua restrito a membros. A entropia dos IDs deve ser mantida.
- Convites atuais têm 48 bits de entropia e não expiram nem limitam usos. Para lançamento público, adicionar expiração, revogação e/ou token aleatório mais forte.
- O Firestore Emulator carregou as regras sem erro de compilação. O Storage Emulator encerrou com uma mensagem de runtime relacionada ao Java e sem rejeição explícita de sintaxe; a validação de Storage permanece inconclusiva. Não foram executados testes comportamentais com contas de papéis diferentes, e nada foi publicado no projeto remoto. Estas regras são um protótipo, não uma garantia de segurança.
