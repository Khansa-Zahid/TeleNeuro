# TeleNeuro — AI-Powered Telemedicine Platform

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat&logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=flat&logo=firebase&logoColor=black)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat&logo=dart&logoColor=white)
![GetX](https://img.shields.io/badge/GetX-8B1A1A?style=flat)

> A production-grade cross-platform telemedicine application built with Flutter and Firebase.
> Final Year Project — Bahria University, 2025.
> Built as sole Flutter developer across the full stack.

---

## Features

- 🧠 **AI Diagnosis** — MRI-based detection of brain tumor, Alzheimer's disease, and multiple sclerosis
- 💬 **Real-time Chat** — Instant doctor-patient communication via Firebase Firestore
- 📅 **Appointments** — Full scheduling, management, and status tracking
- 💊 **E-Prescriptions** — Digital prescription creation and patient delivery
- 🔔 **Push Notifications** — FCM-powered real-time alerts for all user roles
- 👥 **Role-Based Access Control** — Separate flows for Patient, Doctor, and Admin
- 🔐 **Authentication** — Firebase Auth with secure session management
- 📱 **Cross-platform** — Android, iOS, and Flutter Web

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend | Flutter (Dart) |
| State Management | GetX |
| Architecture | Clean Architecture |
| Backend | Firebase (Auth · Firestore · Storage · Functions · FCM) |
| AI Integration | MRI image analysis pipeline |

---

## Project Structure

```
lib/
├── core/              # Constants, themes, utilities, routes
├── data/              # Models, repositories, Firebase services
├── domain/            # Use cases, entities, interfaces
└── presentation/      # Screens, GetX controllers, widgets
    ├── patient/
    ├── doctor/
    └── admin/
```

---

<!-- ## Screenshots

> Add your app screenshots here

--->

## Getting Started

### Prerequisites
- Flutter SDK (3.x+)
- Firebase project configured
- Android Studio / VS Code

### Setup

```bash
git clone https://github.com/khansa-zahid/teleneuro.git
cd teleneuro
flutter pub get
```

Add your Firebase config files:
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `lib/firebase_options.dart` (see `firebase_options.example.dart`)

```bash
flutter run
```

---

## About the Developer

**Khansa Zahid** — Flutter Developer & QA Engineer
- 📧 khansaaazahid143@gmail.com
- 💼 [LinkedIn](https://linkedin.com/in/khansa-zahid)
- 🌍 Islamabad, Pakistan | Open to Remote & Relocation
