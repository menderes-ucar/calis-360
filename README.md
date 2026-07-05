# 🚀 Çalış360

<p align="center">
  <b size="6">Smart Study Planner & Academic Productivity Platform</b>
</p>

<p align="center">
An advanced, production-ready academic productivity application engineered with Flutter and Firebase to centralize study workflows, optimize schedule management, and drive student success.
</p>

<p align="center">
<a href="https://play.google.com/store/apps/details?id=com.calis360.app">
<img src="https://img.shields.io/badge/Download-Google%20Play-34A853?style=for-the-badge&logo=google-play&logoColor=white"/>
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

# 📱 Screenshots & UI Showcase

<p align="center">
  <img src="https://uqr.to/images/shared_images/12836267_image3.png" width="45%" alt="Dashboard Overview"/>
  <img src="https://uqr.to/images/shared_images/12836266_image2.png" width="45%" alt="Exam & Question Tracking"/>
</p>

<p align="center">
  <img src="https://uqr.to/images/shared_images/12836268_image4.png" width="45%" alt="Academic Calendar"/>
  <img src="https://uqr.to/images/shared_images/12836269_image5.png" width="45%" alt="Goal Management System"/>
</p>

<p align="center">
  <img src="https://uqr.to/images/shared_images/12836265_image1.png" width="45%" alt="Premium Settings"/>
</p>

---

# 📖 Overview

**Çalış360** is a full-stack mobile platform built to consolidate fragmented student workflows into a single, intuitive ecosystem. Instead of jumping between disparate apps for calendar events, task lists, and exam tracking, Çalış360 coordinates the entire academic cycle. 

The primary engineering focus of this project was to establish a highly maintainable, scalable, and cross-platform architecture utilizing deterministic state management and cloud synchronization.

---

# ✨ Core Features

### 📚 Academic CRM & Analytics
- **Granular Goal Setting:** Daily, weekly, and monthly objective breakdown with continuous progression metrics.
- **Dynamic Scheduling:** Full-featured academic planner synced with university courses and modular timetables.
- **Exam & Question Bank Repository:** Dedicated module to archive challenging questions and analyze past exam performance.

### 📝 Productivity Engine
- **Task & Smart Notes System:** Integrated rich-text options tied directly to specific academic modules.
- **Countdown Infrastructure:** Real-time countdown engine built for high-stakes exam preparation tracking.

### 🔒 Enterprise-Grade Infrastructure
- **Secure Authentication:** Seamless user onboarding and token management via Firebase Authentication.
- **Real-Time Data Layer:** Offline-first capability with instant Cloud Firestore multi-device synchronization.
- **Premium Tiering System:** Feature-flagged architecture enabling modular access control and configuration maps.

---

# 🛠 Tech Stack

| Layer | Technology | Purpose |
| :--- | :--- | :--- |
| **Frontend Framework** | Flutter (v3.35) | Cross-platform UI rendering |
| **Language** | Dart (v3.9) | Strongly-typed, asynchronous execution |
| **State Management** | Provider | Reactive, predictable state propagation |
| **Routing Architecture** | GoRouter | Declarative, deep-link ready navigation scheme |
| **Database & Auth** | Cloud Firestore / Firebase Auth | Cloud-native data storage & identity federation |
| **Local Storage** | SharedPreferences | High-performance key-value local caching |

---

# 🏗 Architectural Blueprint

```text
       ┌────────────────────────────────────────────────────────┐
       │                   Presentation Layer                   │
       │         (Material 3 UI / Highly Reusable Widgets)      │
       └───────────────────────────┬────────────────────────────┘
                                   │
                                   ▼
       ┌────────────────────────────────────────────────────────┐
       │               State Management (Provider)              │
       │          (Business Logic & Reactive UI Triggers)       │
       └───────────────────────────┬────────────────────────────┘
                                   │
                                   ▼
       ┌────────────────────────────────────────────────────────┐
       │                   Repository Pattern                   │
       │        (Abstracted Data Sourcing & Local Cache)        │
       └───────────────────────────┬────────────────────────────┘
                                   │
                                   ▼
       ┌────────────────────────────────────────────────────────┐
       │               Network & Firebase Services              │
       │       (Firestore Rules / Federated Authentication)     │
       └────────────────────────────────────────────────────────┘
