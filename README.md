# 🚀 Çalış360

<p align="center">
  <b>Smart Study Planner & Academic Productivity Platform</b>
</p>

<p align="center">
An advanced, production-ready academic productivity application engineered with Flutter and Firebase to centralize study workflows, optimize schedule management, and drive student success.
</p>

<p align="center">
<a href="https://play.google.com/store/apps/details?id=com.calis360.app">
  <img src="https://img.shields.io/badge/Download-Google%20Play-34A853?style=for-the-badge&logo=google-play&logoColor=white"/>
</a>
<a href="https://www.linkedin.com/in/menderes-u%C3%A7ar-97a7b9343">
  <img src="https://img.shields.io/badge/LinkedIn-Profile-0077B5?style=for-the-badge&logo=linkedin&logoColor=white"/>
</a>
</p>

<p align="center">
<img src="https://img.shields.io/badge/Flutter-3.35-02569B?logo=flutter&logoColor=white"/>
<img src="https://img.shields.io/badge/Dart-3.9-0175C2?logo=dart&logoColor=white"/>
<img src="https://img.shields.io/badge/Firebase-FFCA28?logo=firebase&logoColor=black"/>
<img src="https://img.shields.io/badge/Cloud%20Firestore-Database-orange"/>
<img src="https://img.shields.io/badge/Material%203-UI-6200EE"/>
<img src="https://img.shields.io/badge/Maintained-Yes-brightgreen"/>
</p>

---

# 📱 Production UI Showcase

<p align="center">
  <img src="https://github.com/user-attachments/assets/63f855e5-d8b7-4cc3-b51e-8f0f5513d1b9" width="48%" style="max-width: 450px; border-radius: 10px; margin: 1%;" alt="Dashboard Overview"/>
  <img src="https://github.com/user-attachments/assets/7967eb0b-14ca-46b1-852c-94052be9c964" width="48%" style="max-width: 450px; border-radius: 10px; margin: 1%;" alt="Exam & Question Tracking"/>
</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/59ee4d6a-3f5e-401f-9a11-308086c07d56" width="48%" style="max-width: 450px; border-radius: 10px; margin: 1%;" alt="Academic Calendar"/>
  <img src="https://github.com/user-attachments/assets/b1c6b3ce-0568-4588-a45a-9a431de69edb" width="48%" style="max-width: 450px; border-radius: 10px; margin: 1%;" alt="Goal Management System"/>
</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/3a649261-47e0-4e6e-acee-c1be11305326" width="48%" style="max-width: 450px; border-radius: 10px; margin: 1%;" alt="Premium Settings"/>
</p>

---

# 📖 Overview

**Çalış360** is a full-stack, cross-platform mobile ecosystem built to eliminate fragmented student workflows by consolidating academic metrics, intelligent scheduling, and target tracking into a single source of truth. 

The primary engineering focus of this project was to implement a **highly resilient, scalable, and decoupled architecture** leveraging deterministic state propagation, an abstract repository layer, and offline-first cloud synchronization patterns.

---

# ✨ Enterprise Features

### 📊 Academic CRM & Analytics Engine
- **Granular Goal Setting:** Multi-tier target decomposition (Daily/Weekly/Monthly) mapping user milestones via localized progression engines.
- **Dynamic Timetable Grid:** Custom academic scheduling infrastructure designed to synchronize recurring university course structures with localized background execution.
- **Question Bank & Performance Diagnostics:** A dedicated repository module for isolating complex problem sets, allowing students to archive images of challenging tasks and track quantitative exam net metrics over time.

### 📝 Core Productivity Mechanics
- **Context-Aware Notes:** Modular rich-text logging bound to specific academic modules for seamless cross-referencing.
- **High-Stakes Countdown Engine:** Real-time countdown infrastructure built using optimized periodic streams to track critical exam windows without UI blocking or performance overhead.

### 🔒 Resilient Infrastructure
- **Identity Federation:** Secure onboarding and session preservation implemented via Firebase Authentication token validation.
- **Offline-First Synchronizer:** Built on top of Cloud Firestore's multi-device caching layer to guarantee uninterrupted write operations during network latency or cellular drops.
- **Feature-Flagged Premium Subscriptions:** Configuration-driven access control mappings enabling modular UI adjustments and feature gating for commercial tiers.

---

# 🛠 Production Tech Stack

| Layer | Technology | Engineering Purpose |
| :--- | :--- | :--- |
| **Frontend Framework** | Flutter (v3.35) | High-performance, 60fps compiled UI delivery across target platforms. |
| **Language** | Dart (v3.9) | Strongly-typed, sound null-safety asset pipelines with ahead-of-time (AOT) compilation. |
| **State Management** | Provider | Reactive, deterministic, and predictable unidirectional state propagation. |
| **Routing Protocol** | GoRouter | Declarative, deep-link ready navigation topology with compile-time type-safety patterns. |
| **Database & Auth** | Cloud Firestore / Auth | Distributed, cloud-native storage infrastructure utilizing secure identity federation. |
| **Local Persistence** | SharedPreferences | Low-latency key-value local state caching for fast boot workflows. |

---

# 🏗 Architectural Blueprint

The application enforces strict separation of concerns utilizing a clean, repository-driven adaptation of MVVM architecture to maximize testability and maintain modular isolation:

```text
        ┌────────────────────────────────────────────────────────┐
        │                   Presentation Layer                   │
        │          (Material 3 UI / Dumb Layout Widgets)         │
        └───────────────────────────┬────────────────────────────┘
                                    │
                                    ▼
        ┌────────────────────────────────────────────────────────┐
        │               State Management (Provider)              │
        │          (Business Logic / ViewModel Adapters)         │
        └───────────────────────────┬────────────────────────────┘
                                    │
                                    ▼
        ┌────────────────────────────────────────────────────────┐
        │                   Repository Pattern                   │
        │        (Unified Interface for Cloud / Cache Data)       │
        └───────────────────────────┬────────────────────────────┘
                                    │
                                    ▼
        ┌────────────────────────────────────────────────────────┐
        │               Network & Core Infrastructure            │
        │         (Firestore Queries / Client Authentication)    │
        └────────────────────────────────────────────────────────┘
