
# DividiTrip — Aplicativo de Divisão de Despesas

Aplicativo mobile desenvolvido em Flutter para facilitar o gerenciamento e a divisão de despesas em grupos de viagem. O sistema permite organizar participantes, registrar gastos, acompanhar saldos e controlar os acertos financeiros entre os integrantes.

## Objetivo

O objetivo do projeto é desenvolver uma aplicação que simplifique a organização financeira de viagens em grupo, permitindo que os participantes acompanhem as despesas e saibam quanto cada pessoa deve pagar ou receber.

## Tecnologias utilizadas

- **Flutter:** desenvolvimento da aplicação mobile.
- **Dart:** linguagem de programação.
- **Provider:** gerenciamento de estado e disponibilização dos ViewModels.
- **ChangeNotifier:** comunicação de alterações de estado com a interface.
- **SQLite / Sqflite:** persistência local dos dados.
- **UUID:** geração de identificadores únicos.

## Arquitetura do projeto

O projeto utiliza a arquitetura **MVVM (Model-View-ViewModel)**, que separa as responsabilidades da aplicação e facilita a manutenção e organização do código.

### Model

Responsável pelas estruturas de dados e pelas regras relacionadas aos dados da aplicação.

Contém os modelos utilizados para representar entidades como participantes, grupos de viagem, despesas e acertos financeiros.

### View

Responsável pela interface visual e pela interação com o usuário.

Apresenta as telas, formulários, componentes e informações da aplicação.

### ViewModel

Responsável pela lógica de apresentação e pelo gerenciamento do estado.

Recebe as interações da View, executa operações necessárias e disponibiliza os dados atualizados para a interface.

### Comunicação entre as camadas

A comunicação segue o fluxo:

1. O usuário realiza uma ação na View.
2. A View aciona o ViewModel.
3. O ViewModel executa a lógica necessária e utiliza os repositórios ou serviços.
4. Os dados são processados e atualizados.
5. O ViewModel notifica as alterações.
6. A View recebe o novo estado e atualiza a interface.

O Provider é utilizado para disponibilizar os ViewModels e facilitar essa comunicação.

## Estrutura de pastas

```text
lib/
├── core/
│   └── di/
│       └── Configureproviders.dart
│
├── data/
│   ├── local/
│   ├── repositories/
│   └── services/
│
├── domain/
│   ├── models/
│   └── services/
│
├── models/
│
├── viewmodels/
│
├── views/
│
├── widgets/
│
└── main.dart
```

### Descrição das pastas

| Pasta | Responsabilidade |
|---|---|
| `core/` | Configurações e injeção de dependências. |
| `data/` | Acesso aos dados, persistência e repositórios. |
| `domain/` | Modelos e regras de negócio. |
| `models/` | Modelos utilizados pela interface. |
| `viewmodels/` | Lógica de apresentação e gerenciamento de estado. |
| `views/` | Telas da aplicação. |
| `widgets/` | Componentes reutilizáveis da interface. |

## Funcionalidades

O aplicativo foi desenvolvido para oferecer recursos de gerenciamento financeiro em grupos de viagem, incluindo:

- Criação e gerenciamento de grupos de viagem.
- Cadastro e gerenciamento de participantes.
- Registro e consulta de despesas.
- Organização de despesas por categorias.
- Divisão de despesas entre participantes.
- Consulta de saldos individuais.
- Cálculo de valores a pagar e receber.
- Gerenciamento de acertos financeiros.
- Persistência local dos dados.

## Como executar o projeto

### Pré-requisitos

- Flutter instalado.
- Dart instalado (incluído no Flutter).
- Android Studio ou Visual Studio Code.
- Emulador Android ou dispositivo físico.

### 1. Clonar o repositório

```bash
git clone https://github.com/Marcos-Henrique007/Projeto-calcula-despesas.git
```

### 2. Entrar na pasta do projeto

```bash
cd Projeto-calcula-despesas
```

### 3. Instalar as dependências

```bash
flutter pub get
```

### 4. Executar a aplicação

```bash
flutter run
```

## Verificação do código

Para analisar o código e identificar possíveis problemas, execute:

```bash
flutter analyze
```

## Objetivo acadêmico

Projeto desenvolvido como atividade acadêmica, com o objetivo de aplicar conhecimentos de desenvolvimento mobile utilizando Flutter, linguagem Dart, gerenciamento de estado, persistência de dados e arquitetura MVVM.

---

**DividiTrip — Organizando despesas, simplificando viagens.**
