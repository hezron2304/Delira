# 🌴 Delira (MedanXplore)

**Delira** (MedanXplore) is a premium, all-in-one mobile application designed to elevate the tourism experience in Medan, Indonesia. Built with Flutter and powered by AI, Delira provides travelers with a seamless journey from discovery and booking to on-the-ground exploration.

---

## ✨ Key Features

### 🤖 Smart AI Travel Guide
- **Gemini-Powered Assistance**: Integrated with Google's Generative AI to provide personalized travel recommendations.
- **Voice Interaction**: Features Text-to-Speech (TTS) and Speech-to-Text (STT) for hands-free guidance.
- **Real-time Inquiries**: Ask about local history, best culinary spots, or hidden gems in Medan.

### 🎫 Seamless E-Ticketing
- **Easy Booking**: Integrated checkout system for destinations and hotel rooms.
- **Digital Tickets**: Securely store and view your tickets within the app.
- **Booking History**: Keep track of your past and upcoming adventures.

### 🗺️ Interactive Maps & Navigation
- **Real-time Map**: Integrated navigation to help you find your way through Medan's vibrant streets.
- **Point of Interest (POI)**: Discover popular landmarks, restaurants, and hotels directly on the map.

### 🏨 Premium Hotel Discovery
- **Visual Browsing**: High-quality images and detailed descriptions for hotel selections.
- **Smart Filtering**: Find the perfect place to stay based on your preferences.

---

## 🛠️ Technology Stack

- **Framework**: [Flutter](https://flutter.dev/) (Material 3)
- **Backend/Database**: [Supabase](https://supabase.com/)
- **AI Engine**: [Google Generative AI (Gemini)](https://ai.google.dev/)
- **Maps**: [Flutter Map](https://pub.dev/packages/flutter_map) with Leaflet
- **Authentication**: Supabase Auth
- **State Management**: Standard Flutter state management with refined UI logic.
- **Theme**: Custom Design System with Google Fonts (Inter).

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (latest stable version)
- Android Studio or VS Code with Flutter extension
- Supabase account for backend services

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/hezron2304/Delira.git
   cd Delira
   ```

2. **Setup environment variables:**
   Create a `.env` file in the root directory and add your keys:
   ```env
   SUPABASE_URL=YOUR_SUPABASE_URL
   SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
   GOOGLE_API_KEY=YOUR_GEMINI_API_KEY
   ```

3. **Install dependencies:**
   ```bash
   flutter pub get
   ```

4. **Run the app:**
   ```bash
   flutter run
   ```

---

## 📂 Project Structure

- `lib/home_page.dart`: The central hub for discovery.
- `lib/ai_guide_page.dart`: Interactive AI assistant interface.
- `lib/map_page.dart`: Real-time map and location services.
- `lib/detail_page.dart`: Detailed destination view and booking gateway.
- `lib/e_ticket_page.dart`: Digital storage for all your bookings.
- `lib/profil_page.dart`: User profile and settings management.

---

## 🎨 Design Aesthetics

Delira follows a modern, "Nature-First" design philosophy with a primary color palette focused on deep, premium greens (`#1A6B4A`) and clean surface aesthetics to provide a relaxing yet sophisticated user experience.

---

## 👨‍💻 Team MedanXplore

This project was developed for **Lomba Mobile Apps (MedanXplore)**.

---
*© 2026 Delira (MedanXplore) Team - Discovering Medan, Redefined.*
