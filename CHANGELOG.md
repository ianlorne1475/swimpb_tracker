# SwimPB Tracker Changelog

This document tracks all changes, enhancements, and planned features for the SwimPB Tracker application.

## [v1.0.3+9] - 2026-03-24
### Fixed (Today)
- **Tab Tooltips**: Restored missing tooltips for the primary navigation tabs. (2026-03-24 10:46)
- **Tooltip Styling**: Applied semi-transparent glassmorphism theme to all tooltips project-wide. (2026-03-24 10:47)
- **Chart Annotations**: Repositioned Qualification and Goal labels to the top-right and made their backgrounds **fully transparent**. (2026-03-24 10:53)

## [v1.0.3+9] - 2026-03-23
### Added
- **TimeUtils**: Centralized all time formatting and parsing logic into a utility class. (2026-03-23 21:00)
- **BaseReport Mixin**: Standardized PDF report layouts and styling. (2026-03-23 21:05)
- **Exit App Confirmation**: Added a safety dialog and full process termination (`exit(0)`). (2026-03-23 21:15)
- **Version Increment**: Updated build number to 9 and version to 1.0.3. (2026-03-23 21:20)

### Fixed
- **Settings UI**: Resolved an issue where the "Delete Race Data" dropdown wouldn't update. (2026-03-23 21:22)
- **Main Screen Logic**: Fixed a crash when deleting the last swimmer. (2026-03-23 21:25)
- **ReportService Migration**: Completed the transition to the modular singleton architecture. (2026-03-23 21:28)

### Refactored
- **ReportService**: Modularized the service by extracting static content. (2026-03-23 21:30)
- **Model Clean-up**: Updated `SwimEvent` and related models to use `TimeUtils`. (2026-03-23 21:32)

## [v1.0.1] - 2026-03-19
### Finalized
- **Stylized Launcher Icon**: Applied the final high-quality icon assets. (2026-03-19 15:30)
- **Persistence**: Verified SQLite data persistence across app restarts. (2026-03-19 15:35)
- **Reset Logic**: Implemented "Clear All Data" functionality. (2026-03-19 15:40)

---

## Future Enhancements & Roadmap

### 📱 User Interface & Experience
- [ ] **Sharing Feature**: Implement "Share with a Friend" in the Settings menu (currently a placeholder).
- [ ] **Service Layer Alignment**: Refactor `ThemeService` and `PreferenceService` for better architectural consistency.
- [ ] **Smart Notifications**: Goal-proximity alerts and automatic "Qualification Watch" notifications for major meets.

### ☁️ Cloud & Connectivity
- [ ] **Cloud Sync & Firebase**: Upgrade with Firebase for secure backup, team synchronization, and advanced crashlytics.
- [ ] **User Authentication**: Secure login via **Google, Facebook, and Email** for multi-device sync and personalized profiles.
- [ ] **Wearable Sync**: Integrate with **Garmin, Apple Watch, and Whoop** to automate training and heart rate data import.

### 📊 Performance & Coaching
- [ ] **Training Logbook**: Track daily yardage/meters and **RPE** (Rate of Perceived Exertion) to monitor fatigue.
- [ ] **Training Set Builder**: Generate custom swim sets based on available pool time and specific stroke techniques to improve.
- [ ] **Deep Analytics**: Detailed **Split Analysis** for races and stroke-efficiency metrics (Stroke Count/Rate).
- [ ] **Block Time**: Dedicated tracking for swimmer reaction time off the start blocks.
- [ ] **Advanced Comparisons**: Technical tools for cross-swimmer and multi-season progression analysis.

### 🏆 Planning & Community
- [ ] **Season Planner**: Group meets into seasons and set a primary "Target Meet" with a **Taper Visualizer**.
- [ ] **Team Leaderboards**: Permission-based club rankings and squad performance tracking.
- [ ] **Coach/Parent Portal**: Secure, view-only access for coaches to monitor multiple swimmers' progress in real-time.
