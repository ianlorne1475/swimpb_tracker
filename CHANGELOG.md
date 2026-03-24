# SwimPB Tracker Changelog

This document tracks all changes, enhancements, and planned features for the SwimPB Tracker application.

## [v1.0.3+9] - 2026-03-23
### Added
- **TimeUtils**: Centralized all time formatting ("M:SS.hh") and parsing logic into a single testable utility class.
- **BaseReport Mixin**: Standardized PDF report layouts (headers, footers, styling) for all generated reports.
- **Exit App Confirmation**: Added a safety dialog and full process termination (`exit(0)`) to the "Exit App" button.
- **Version Increment**: Updated build number to 9 and version to 1.0.3.

### Fixed
- **Settings UI**: Resolved an issue where the "Delete Race Data" dropdown wouldn't update dynamically after a deletion.
- **Main Screen Logic**: Fixed a crash when deleting the last swimmer by ensuring the app reverts to the initial screen if no data remains.
- **Tab Tooltips**: Restored missing tooltips for the primary navigation tabs (PBs, Recent, Chart, History).
- **Chart Annotations**: Repositioned Qualification and Goal labels to the top-right of the progression chart to avoid overlapping with data plots.
- **ReportService Migration**: Completed the transition of all reports to the new modular singleton architecture.

### Refactored
- **ReportService**: Modularized the "God Class" by extracting static content (quotes/tips) into `ReportContent` and separating UI mixins.
- **Model Clean-up**: Updated `SwimEvent` and related models to use `TimeUtils` internally.

## [v1.0.1] - 2026-03-19
### Finalized
- **Stylized Launcher Icon**: Applied the final high-quality icon assets.
- **Persistence**: Verified SQLite data persistence across app restarts.
- **Reset Logic**: Implemented "Clear All Data" functionality with appropriate redirects.

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
