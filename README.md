# 🚀 Çalış360

<p align="center">
  <img src="docs/banner.png" alt="Çalış360 Banner" width="100%">
</p>

<h3 align="center">
Smart Study Planner & Academic Productivity Platform
</h3>

<p align="center">
Organize your studies, track your progress and achieve your academic goals with a beautiful Flutter application.
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

<img src="https://img.shields.io/badge/Android-Supported-success"/>

<img src="https://img.shields.io/badge/Maintained-Yes-brightgreen"/>

</p>

---

# 📱 Screenshots

<p align="center">

<img src="screenshots/home.webp" width="250"/>

<img src="screenshots/goals.webp" width="250"/>

</p>

<p align="center">

<img src="screenshots/calendar.webp" width="250"/>

<img src="screenshots/exams.webp" width="250"/>

</p>

<p align="center">

<img src="screenshots/planner.webp" width="250"/>

<img src="screenshots/premium.webp" width="250"/>

</p>

---

# 🎥 Demo

<p align="center">

<img src="docs/demo.gif" width="300"/>

</p>

---

# 📖 About

Çalış360 is a modern academic productivity application developed with Flutter to help students manage every aspect of their university life from a single platform.

The application combines study planning, goal management, productivity tracking, academic scheduling, reminders and note management into one intuitive mobile experience.

Instead of switching between multiple applications every day, students can organize their entire study workflow in one place.

The project focuses on building a production-ready Flutter application by following clean software development principles, modular architecture and reusable components.

---

# ✨ Features

## 📚 Academic Management

- Create and manage study goals
- Organize university courses
- Academic planner
- Semester planning
- Daily study schedule
- Goal progress tracking
- Learning organization

## 📝 Productivity

- Smart Notes
- Task Management
- Productivity Dashboard
- Daily Planning
- Countdown System
- Calendar Integration

## 👤 User Management

- Secure Authentication
- Firebase Login
- User Profile
- Cloud Synchronization

## 🎨 User Experience

- Material Design 3
- Responsive Layout
- Modern UI
- Smooth Navigation
- Beautiful Animations
- Clean Design
- Optimized Performance

---

# 🛠 Tech Stack

| Category | Technology |
|------------|----------------|
| Framework | Flutter |
| Language | Dart |
| Backend | Firebase |
| Authentication | Firebase Authentication |
| Database | Cloud Firestore |
| Routing | Go Router |
| Calendar | table_calendar |
| Image Picker | image_picker |
| Countdown | flutter_countdown_timer |
| Local Storage | SharedPreferences |
| State Management | Provider |
| IDE | Android Studio |
| Version Control | Git & GitHub |

---

# 🏗 Architecture

```text
                Presentation Layer
────────────────────────────────────────

Screens

↓

Widgets

↓

Provider

↓

Repositories

↓

Firebase Services

↓

Cloud Firestore

↓

Firebase Authentication
```

The application follows a layered architecture that separates presentation, business logic and data management.

This approach improves scalability, readability and long-term maintainability while keeping each layer independent and reusable.

---

# 📂 Project Structure

```text
lib
│
├── app
├── core
├── models
├── repositories
├── screens
├── services
├── theme
├── widgets
├── utils
├── firebase_options.dart
└── main.dart
---

# 🚀 Engineering Highlights

This project was built by focusing on maintainability, scalability and production-ready mobile development practices.

### Architecture

- Modular folder structure
- Layered architecture
- Reusable UI components
- Feature-oriented organization
- Separation of concerns

### Performance

- Optimized widget rebuilding
- Lightweight UI components
- Cloud Firestore integration
- Responsive layouts
- Fast navigation using GoRouter

### Security

- Firebase Authentication
- Cloud Firestore Security Rules
- User-specific data isolation
- Secure authentication flow

### Code Quality

- Reusable widgets
- Consistent UI components
- Clean folder hierarchy
- Readable codebase
- Easy maintenance

---

# 💡 Why I Built This

As a Computer Engineering student, I realized that students often rely on several different applications to manage their academic life.

One application for planning.

Another one for taking notes.

Another one for reminders.

Another one for tracking goals.

Çalış360 was developed to bring these essential tools together into a single mobile application with a modern user experience.

Besides solving a real-world problem, this project also allowed me to improve my knowledge of Flutter application architecture, Firebase integration and scalable mobile development.

---

# 📈 Technical Challenges

Some of the engineering challenges during development included:

- Designing a scalable project structure.
- Keeping the UI responsive across different screen sizes.
- Managing user authentication securely.
- Synchronizing cloud data efficiently.
- Creating reusable widgets to reduce duplicated code.
- Organizing application state in a maintainable way.
- Building a clean navigation flow using GoRouter.

---

# ⚡ Performance Optimizations

- Optimized widget tree.
- Reduced unnecessary widget rebuilds.
- Lightweight navigation.
- Efficient Firebase queries.
- Modular UI components.
- Responsive layouts.
- Smooth page transitions.

---

# 📦 Main Dependencies

```yaml
flutter
firebase_core
firebase_auth
cloud_firestore
go_router
provider
table_calendar
image_picker
flutter_countdown_timer
shared_preferences
```

---

# 🚀 Getting Started

Clone the repository.

```bash
git clone https://github.com/menderes-ucar/calis-360.git
```

Navigate to the project.

```bash
cd calis-360
```

Install packages.

```bash
flutter pub get
```

Run the application.

```bash
flutter run
```

---

# 📁 Environment

Before running the project make sure that Firebase is configured correctly.

Required services:

- Firebase Authentication
- Cloud Firestore

Configuration file:

```
firebase_options.dart
```

---

# 🎯 Future Roadmap

## AI

- AI Study Assistant
- Personalized study recommendations
- AI-generated study plans

## Productivity

- Pomodoro Timer
- Study Statistics
- Weekly Reports
- Habit Tracking

## Cloud

- Multi-device synchronization
- Cloud Backup
- Offline-first support

## User Experience

- Dark Theme improvements
- Tablet optimization
- Accessibility improvements
- Localization support

---

# 📊 Project Status

| Feature | Status |
|---------|--------|
| Authentication | ✅ |
| Firestore | ✅ |
| Study Planner | ✅ |
| Goals | ✅ |
| Calendar | ✅ |
| Notes | ✅ |
| Premium System | ✅ |
| Push Notifications | 🚧 |
| AI Assistant | 🚧 |
| Analytics | 🚧 |

---

# 🤝 Contributing

Contributions are welcome.

If you have suggestions for improvements, feel free to open an Issue or submit a Pull Request.

---

# 📱 Google Play

The latest production version is available on Google Play.

https://play.google.com/store/apps/details?id=com.calis360.app

---

# 👨‍💻 Developer

**Menderes Uçar**

Computer Engineering Student

Flutter Developer

Interested in

- Flutter
- Mobile Development
- Firebase
- Backend Development
- Clean Architecture
- UI/UX
- Software Engineering

GitHub

https://github.com/menderes-ucar

LinkedIn

https://www.linkedin.com/in/YOUR-LINKEDIN

---

# ⭐ Support

If you like this project, consider giving it a ⭐ on GitHub.

It helps increase the visibility of the project and motivates future development.

---

# 📄 License

This project is licensed under the MIT License.
