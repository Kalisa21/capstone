# capstone

# legalEase-UI

# LegalEase App


api url: https://github.com/Kalisa21/Mission-capstone---legalEase.git 

apk : https://drive.google.com/file/d/1bVAeT-eDoV-xLBszljLjb6umSw9-zx5A/view?usp=sharing   

A Flutter-based legal knowledge  application with an integrated AI chatbot.

##  Overview

LegalEase is a comprehensive legal app designed to help users access legal information, track their legal knowledge progress,  for legal questions. The app features a modern UI with dashboard analytics, topic exploration, and real-time chat functionality.

##  Features

###  Home Screen
- **Topic Exploration**: Browse legal categories (Criminal Law, Civil Law, Business Law, etc.)
- **Search & Filter**: Advanced search with category filters
- **Card Stack**: Interactive carousel showcasing legal topics with images
- **Profile Navigation**: Quick access to user profile

###  Analytics Dashboard
- **Knowledge Progress**: Semi-circular gauge showing total legal knowledge score
- **Learning Time Tracking**: Visual representation of time spent learning
- **Interactive Charts**: Dynamic bar charts with refresh functionality
- **Recent Topics**: Track recently accessed legal topics

###  AI Chatbot
- **Real-time Chat**: Integration with FastAPI backend for legal assistance
- **Intent Recognition**: Displays classified intents from user queries
- **Typing Indicators**: Smooth animations during bot responses
- **Cross-platform Support**: Works on iOS simulator and Android emulator

###  Knowledge Gap (Help)
- **FAQ Section**: Expandable frequently asked questions
- **External Resources**: Direct links to Rwanda legal resources
- **UI Reference**: Native implementation of complex UI patterns
<img width="1080" height="2400" alt="Screenshot_1761339994" src="https://github.com/user-attachments/assets/664c700c-6565-468b-b701-8a5068a3b81b" />

<img width="1080" height="2400" alt="Screenshot_1761340091" src="https://github.com/user-attachments/assets/6e066dfa-75cd-49b5-b32b-09d7db9ebbbc" />

##  Tech Stack


- **Frontend**: Flutter (Dart)
- **State Management**: StatefulWidget with setState
- **HTTP Client**: http package for API communication
- **UI Components**: Custom widgets with Material Design
- **Charts**: charts and gauges
- **Navigation**: Named routes with MaterialPageRoute

## 📋 Prerequisites

- Flutter SDK (>=3.19.0)
- Dart SDK (^3.9.0)
- Android Studio / VS Code
- Java 17 (for Android builds)
- FastAPI backend running (for chatbot functionality)

##  Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd legal_ease_app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Add required assets**
   Ensure these image assets are in the `assets/` folder:
   - `gavel.png`
   - `civil.png`
   - `criminal.png`
   - `pi.png`
   - `taxation.png`
   - `business.png`

4. **Run the app**
   ```bash
   flutter run
   ```

##  Configuration

### Chatbot API Setup

The app expects a FastAPI backend running at:
- **iOS Simulator**: `http://127.0.0.1:8000`
- **Android Emulator**: `http://10.0.2.2:8000`
- **Physical Device**: Replace with your machine's IP address

### API Endpoint
```
POST /query
Content-Type: application/json

{
  "query": "user message"
}
```

Expected response:
```json
{
  "intent": "classified_intent",
  "response": "bot_response_text"
}
```

## 📱 Building for Release

### Android APK

1. **Create a keystore** (one-time setup)
   ```bash
   keytool -genkey -v -keystore ~/le_release.keystore -alias leapp \
     -keyalg RSA -keysize 2048 -validity 10000
   ```

2. **Create key.properties**
   ```properties
   storePassword=YOUR_STORE_PASSWORD
   keyPassword=YOUR_KEY_PASSWORD
   keyAlias=leapp
   storeFile=/Users/USERNAME/le_release.keystore
   ```

3. **Configure signing in android/app/build.gradle**
   ```gradle
   def keystoreProperties = new Properties()
   def keystorePropertiesFile = rootProject.file("key.properties")
   if (keystorePropertiesFile.exists()) {
     keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
   }

   android {
     signingConfigs {
       release {
         keyAlias keystoreProperties['keyAlias']
         keyPassword keystoreProperties['keyPassword']
         storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
         storePassword keystoreProperties['storePassword']
       }
     }
     buildTypes {
       release {
         signingConfig signingConfigs.release
       }
     }
   }
   ```

4. **Add Internet permission in android/app/src/main/AndroidManifest.xml**
   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   <application android:usesCleartextTraffic="true" ...>
   ```

5. **Build the APK**
   ```bash
   flutter clean
   flutter pub get
   flutter build apk --release
   ```

   For smaller, optimized APKs:
   ```bash
   flutter build apk --release --split-per-abi
   ```

6. **Find your APK**
   - Universal: `build/app/outputs/flutter-apk/app-release.apk`
   - Split: `app-arm64-v8a-release.apk`, `app-armeabi-v7a-release.apk`, etc.

##  Project Structure

```
lib/
├── screens/
│   ├── home_screen.dart          # Main app with tabs and chatbot
│   ├── profile_screen.dart       # User profile (referenced)
│   └── splash_screen.dart        # App launch screen
├── widgets/
│   ├── custom_search_bar.dart    # Search input component
│   ├── case_card.dart           # Topic card widgets
│   └── chart_card.dart          # Chart components
├── theme/
│   └── app_theme.dart           # App colors and styling
├── routes.dart                  # Navigation routes
└── main.dart                    # App entry point

assets/
├── gavel.png                    # Legal icons and images
├── civil.png
├── criminal.png
├── pi.png
├── taxation.png
└── business.png
```

## Design Features

- **Modern Material Design**: Clean, professional interface
- **Custom Animations**: Smooth transitions and loading states
- **Responsive Layout**: Adapts to different screen sizes
- **Dark Theme Support**: Professional color scheme
- **Interactive Elements**: Floating action buttons, animated charts

##  Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.6
  google_fonts: ^6.0.0
  flutter_svg: ^2.0.7
  fl_chart: ^0.68.0
  http: ^1.2.2
  url_launcher: ^6.3.0
```

##  Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/new-feature`)
3. Commit your changes (`git commit -am 'Add new feature'`)
4. Push to the branch (`git push origin feature/new-feature`)
5. Create a Pull Request

##  License

This project is licensed under the MIT License - see the LICENSE file for details.

## Troubleshooting

### Common Issues

1. **Chatbot not responding**
   - Ensure FastAPI backend is running
   - Check network connectivity
   - Verify API endpoint URL matches your setup

2. **Build failures**
   - Run `flutter clean && flutter pub get`
   - Check Flutter and Dart SDK versions
   - Ensure all dependencies are compatible

3. **Asset loading errors**
   - Verify all image files exist in `assets/` folder
   - Check `pubspec.yaml` assets declaration
   - Run `flutter pub get` after adding new assets

4. **APK installation fails**
   - Enable "Install unknown apps" on Android device
   - Ensure APK is properly signed for release builds
   - Check device compatibility (API level, architecture)

## 📞 Support

For support and questions:
- Create an issue in the GitHub repository
- Check existing issues for similar problems
- Review the troubleshooting section above

---

**Note**: This app requires a companion FastAPI backend for full chatbot functionality. The UI and navigation work independently, but chat features need the API endpoint configured.
