# 📝 GitNote 2.0

> **Empowering your knowledge base with the power of Git.**

GitNote 2.0 is a high-performance, developer-centric Markdown note-taking application. Unlike traditional note apps, GitNote treats your GitHub repositories as first-class citizens, providing seamless, real-time synchronization, intelligent merging, and robust point-in-time recovery.

---

## 🚀 Key Features

### 🔄 Intelligent Synchronization
GitNote 2.0 manages your notes with a sophisticated sync engine that handles **Automated Pull/Push cycles**, ensuring your local device and GitHub are always in parity.
- **Smart Merge Helper**: Resolves conflicts locally using a triple-diff logic.
- **Background Sync**: Stays up-to-date even when the app is in the background.

### 🛡️ Time-Travel Recovery
Lost a note? Deleted a folder? No problem.
- **Commit History**: Browse the last 20 commits directly from the app.
- **Full Restore**: Perform a "Hard Reset" of your local workspace to any historical point in your GitHub history.

### 🎨 Premium User Experience
- **Material 3 UI**: A sleek Indigo & Emerald theme designed for focus and productivity.
- **Unified Controls**: A custom Floating Control Bar for single-tap sync and note creation.
- **Drag-and-Drop**: Organize your notes effortlessly with intuitive folder movement.

---

## 🛠️ Technical Architecture

```mermaid
graph TD
    A[Local Storage] -->|Push on Save| B(GitNote Sync Engine)
    B -->|REST API| C[GitHub Repository]
    C -->|Auto-Pull| B
    B -->|Merge Helper| A
```

### Stack
- **Flutter**: Cross-platform frontend excellence.
- **Provider**: Robust reactive state management.
- **GitHub REST API**: Level 3 hypermedia integration.
- **Material 3**: The latest design tokens from Google.

---

## 📥 Installation

### Developer Setup
1. **Clone**: `git clone https://github.com/SchoferMorningstar/GitNote.git`
2. **Setup**: `flutter pub get`
3. **Run**: `flutter run`

### Release Build
To generate a production APK:
```bash
flutter build apk --release
```

---

## 🏷️ Configuration
The app uses a secure Device Flow for GitHub authentication. No manual token entry required! The `clientId` is pre-configured in `AppConfig`.

---

## 📜 Roadmap
- [x] GitHub Sync & Conflict Resolution
- [x] Point-in-time Recovery
- [x] Material 3 Visual Overhaul
- [ ] Multi-repository support
- [ ] End-to-end encryption for private repos

---
Developed by **SchoferMorningstar**.
