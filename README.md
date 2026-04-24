# 📝 GitNote

> **The Professional, Git-Backed Markdown Workspace.**

GitNote is a high-performance, developer-centric note-taking application designed for those who value privacy, version control, and the simplicity of Markdown. By treating your GitHub repositories as a first-class file system, GitNote ensures your knowledge base is always synced, versioned, and under your absolute control.

---

## 🌟 Why GitNote?

In an era of proprietary note formats and cloud lock-ins, GitNote stands apart by using standard Markdown and the industrial-strength versioning of Git.

- **🛡️ Full Ownership:** Your notes live in your GitHub repository. No proprietary servers, no data harvesting.
- **🔄 Industrial Sync:** Powered by a sophisticated Git-based synchronization engine that handles automated pull/push cycles and intelligent conflict resolution.
- **🛡️ Point-in-Time Recovery:** Navigate your note history with ease. Restore entire folders or individual files from any previous Git commit.
- **🏷️ Deep Tagging:** A specialized tagging system (`@tag`) that works across your entire directory tree with recursive filtering.

---

## 🚀 Core Features

### 🖋️ Professional Markdown Editor
- **Hybrid Editing:** Switch between a native high-performance text field and a **Live Edit Mode** that renders formatting in real-time.
- **Rich Toolbar:** One-tap access to headings, lists, code blocks, images, and links.
- **Precision Focus:** Optimized cursor management and hit-testing for a seamless mobile writing experience.

### 🏷️ Intelligent Organization
- **Global Tagging:** Use `@tag` syntax to categorize notes.
- **Recursive Search:** Filter your entire repository from the home screen; find notes buried deep in subdirectories instantly.
- **Dynamic Sorting:** Organize your workspace by Name or Date Modified with persistent user preferences.

### 🔄 Advanced Synchronization
- **Background Persistence:** Configurable auto-pull intervals to keep your devices in sync without manual intervention.
- **Conflict Resolution:** Local triple-diff merging logic ensures you never lose data during a sync conflict.
- **Encrypted Metadata:** Secure storage of GitHub tokens and sensitive configuration.

---

## 🛠️ Technical Stack

- **Framework:** [Flutter](https://flutter.dev) (Cross-platform performance)
- **Engine:** [GitHub REST API v3](https://docs.github.com/en/rest)
- **State Management:** Provider (Reactive Architecture)
- **Design System:** Material 3 (Adaptive & Modern)

---

## 📥 Getting Started

### Prerequisites
- Flutter SDK (>= 3.10.0)
- A GitHub Account

### Installation
1. **Clone the Repository:**
   ```bash
   git clone https://github.com/SchoferMorningstar/GitNote.git
   ```
2. **Install Dependencies:**
   ```bash
   flutter pub get
   ```
3. **Configure Environment:**
   Create a `.env` file in the root directory and add your `GITHUB_CLIENT_ID`.
4. **Run the App:**
   ```bash
   flutter run
   ```

---

## 📜 Release History

| Version | Features Added | Improvements & Bug Fixes |
| :--- | :--- | :--- |
| **v1.1.0** | Recursive Tagging System (`@tags`), Visual Tag Chips Bar, Live Edit Mode Toggle, Formatting Toolbar, Sorting (Name/Date), Support Tip integrations. | Resolved cursor jump issues in editor, optimized hit-testing for hit-scrolling, enhanced recovery flow with file-specific restoration. |
| **v1.0.0** | Initial Release, GitHub Sync Engine, Automated Pull/Push, Hard Recovery System, Material 3 UI Overhaul. | Initial stabilization of Git sync logic. |

---

Developed with ❤️ by **SchoferMorningstar**.
