<div align="center">

# 📦 StockFlow
### Smart Inventory & Business Management

A full-stack mobile application for managing products, inventory, employees, and point-of-sale operations.

![Flutter](https://img.shields.io/badge/Flutter-Mobile-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-Language-0175C2?logo=dart&logoColor=white)
![Node.js](https://img.shields.io/badge/Node.js-Backend-339933?logo=nodedotjs&logoColor=white)
![Express](https://img.shields.io/badge/Express-REST%20API-000000?logo=express&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-Database-4169E1?logo=postgresql&logoColor=white)

<!-- Add a real app screenshot here, e.g. docs/images/preview.png -->

</div>

---

## 📖 Overview

**StockFlow** is a full-stack inventory and business management application designed to bring everyday business operations into one mobile experience. It supports product and category management, inventory workflows, and point-of-sale (POS) sales. Role-aware access is intended to provide users with features appropriate to their responsibilities.

The Flutter client communicates with a Node.js/Express REST API. PostgreSQL is used for relational data storage, with Cloudinary and Firebase Cloud Messaging integrations included in the project stack.

> **Project status:** Update with the current status (MVP complete, in development, deployed, etc.) and add a demo link if available.

## ✨ Features

- **Authentication:** registration/login, session handling, JWT-based authentication, secure device-side token storage.
- **Role-aware access:** Owner, Manager, and Cashier navigation/permissions (confirm exact permissions against backend implementation).
- **Dashboard:** centralized entry point to business operations.
- **Products:** create/manage product records, search/filter, pagination, product images, barcode scanning support.
- **Categories:** organize products and support category-based browsing.
- **Inventory:** view and manage stock information and inventory-related movements.
- **POS & sales:** select products, manage cart quantities, submit sales, and view receipt information.
- **Notifications:** Firebase Cloud Messaging integration (document exact event coverage after verifying implementation).
- **Settings:** access account and application settings available to the signed-in role.

## 👥 Roles

| Role | Intended responsibility |
|---|---|
| **Owner** | Business administration and oversight |
| **Manager** | Day-to-day operational management |
| **Cashier** | POS and sales workflows |

**Security:** Flutter route guards and hidden UI controls improve UX, but are not sufficient security. The backend must independently authenticate requests and enforce permissions.

## 🧰 Technology Stack

| Layer | Technology | Purpose |
|---|---|---|
| Mobile | Flutter | Cross-platform UI |
| Language | Dart | App logic and UI code |
| State management | Riverpod | Manage and expose app state |
| Navigation | GoRouter | Declarative routing |
| Networking | Dio | HTTP requests and interceptors |
| Authentication | JWT + secure storage | Authenticated API access and local credential storage |
| Backend | Node.js + Express | REST API and server-side business logic |
| Database | PostgreSQL | Relational business data |
| Images | Cloudinary | Image hosting/storage integration |
| Push notifications | Firebase Cloud Messaging | Push-notification infrastructure |
| API | REST + JSON | Client/server communication |

Check `pubspec.yaml` and backend package files before publishing to ensure the stack and package versions match the current branch.

## 🏗️ Architecture

StockFlow uses a feature-oriented Flutter structure, separating UI, application/state logic, and data access.

```text
Flutter Mobile App
┌──────────────────────────────────────────┐
│ Presentation: screens and widgets        │
│                 ↓                        │
│ Application: Riverpod controllers/state  │
│                 ↓                        │
│ Data: repositories and models            │
│                 ↓                        │
│ Dio HTTP client                           │
└──────────────────┬───────────────────────┘
                   │ HTTPS + JSON
                   ▼
┌──────────────────────────────────────────┐
│ Node.js + Express REST API                │
│ Routes → middleware → validation          │
│        → business logic                   │
└──────────────────┬───────────────────────┘
                   ▼
             PostgreSQL

Supporting services:
• Cloudinary — product image hosting
• Firebase Cloud Messaging — push notifications
```

### Typical request lifecycle

1. The user interacts with a Flutter screen.
2. The screen calls a Riverpod controller/provider.
3. The controller coordinates the operation through a repository.
4. The repository uses Dio to call the API.
5. Express middleware and backend logic authenticate, authorize, validate, and process the request.
6. PostgreSQL stores or retrieves the relevant data.
7. The API response returns through the repository/controller.
8. Riverpod state changes and Flutter rebuilds the relevant UI.

### Suggested project structure

Adjust this to match the actual repository:

```text
lib/
├── core/
│   ├── constants/
│   ├── navigation/
│   ├── network/
│   ├── theme/
│   └── widgets/
└── features/
    ├── auth/
    ├── dashboard/
    ├── products/
    ├── categories/
    ├── inventory/
    ├── sales/
    └── settings/
```

## 🔄 Example: POS sale flow

```text
Cashier selects products
        ↓
Flutter POS/cart UI
        ↓
Riverpod manages screen state
        ↓
Repository sends request using Dio
        ↓
Express authenticates and authorizes
        ↓
Backend validates sale and stock
        ↓
PostgreSQL records sale + stock changes
        ↓
Response updates app state and receipt UI
```

Critical business rules—especially stock validation and inventory updates—must be enforced on the backend. Related database writes should use a transaction where appropriate so they cannot be partially committed.

## 🚀 Getting Started

### Prerequisites

- Flutter SDK compatible with the project's SDK constraint
- Git
- Android Studio / VS Code and an emulator or connected device
- A running StockFlow backend and configured PostgreSQL database
- Any credentials required by enabled external integrations

### 1. Clone

```bash
git clone <YOUR_GITHUB_REPOSITORY_URL>
cd <YOUR_REPOSITORY_FOLDER>
```

Replace both placeholders with the actual repository URL and directory.

### 2. Install dependencies

Run from the Flutter app directory (where `pubspec.yaml` is located):

```bash
flutter pub get
```

### 3. Configure the API

Set the API base URL using the configuration method already implemented in the project. For Android emulators, `localhost` refers to the emulator itself; use the appropriate host address for your development machine/backend.

Do not commit real secrets, private keys, production credentials, or a real `.env` file. If the project has an environment template, document its exact filename and required keys here.

### 4. Run

```bash
flutter run
```

## 🧪 Quality Checks

Run from the Flutter app directory:

```bash
flutter analyze
flutter test
```

`flutter analyze` performs static analysis; `flutter test` runs the tests that exist in the repository. Only state that these checks pass after running them on the current code.

## 🔒 Security Notes

- Use HTTPS for production API traffic.
- Keep secrets and credentials out of source control.
- Store tokens using the project's secure-storage mechanism.
- Enforce authorization on the backend for every protected operation.
- Validate input on the server; client-side validation is not a security boundary.
- Never log passwords, tokens, or sensitive user data.
- Treat client-calculated totals and stock values as untrusted; verify critical rules server-side.
- Keep token expiry, refresh, revocation, and logout behavior consistent with the backend.

## 🖼️ Screenshots

Add actual screenshots under `docs/images/`, then replace these placeholders:

| Screen | Suggested file |
|---|---|
| Login | `docs/images/login.png` |
| Dashboard | `docs/images/dashboard.png` |
| Products | `docs/images/products.png` |
| Inventory | `docs/images/inventory.png` |
| POS / Sales | `docs/images/pos.png` |

Example:

```md
![StockFlow dashboard](docs/images/dashboard.png)
```

## 🧭 Roadmap

Update this list to reflect what is genuinely unfinished:

- [ ] Add screenshots and a short demo video
- [ ] Document exact role permissions and supported notification events
- [ ] Document backend setup and required environment variables
- [ ] Expand meaningful unit, widget, and integration test coverage
- [ ] Verify search debounce, pagination retry, and error states
- [ ] Complete authentication/authorization security review
- [ ] Prepare and document a release build

## 🤝 Contributing

This is a personal learning and portfolio project. Please open an issue describing a proposed change before submitting a pull request.

## 👨‍💻 Author

**Dhaval Rathod**

- GitHub: [dhaval8888](https://github.com/dhaval8888)
- LinkedIn: [Dhaval Rathod](https://www.linkedin.com/in/dhaval-rathod88/)

## 📄 License

No license is specified in this README. Add a `LICENSE` file and update this section if you intend to grant reuse rights.

---

<div align="center">

**StockFlow — bringing inventory and sales workflows together.**

</div>
