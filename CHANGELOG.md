# SwimPB Tracker Changelog

This document tracks all changes, enhancements, and planned features for the SwimPB Tracker application.

## [v1.1.0] - 2026-03-24
### Added (Pre-Release Polish)
- **Time Standardization**: Refactored the entire app to use a centralized `TimeUtils` engine. All PBs, goals, and history now use the exact same formatting logic for 100% consistency. (2026-03-24 18:30)
- **Service Layer Consolidation**: Standardized `ThemeService` and `PreferenceService` as robust singletons with safe initialization in `main.dart`. (2026-03-24 18:15)
- **Performance Optimization**: Conducted a project-wide `const` pass on stable widgets to minimize rebuild overhead and improve frame rates. (2026-03-24 18:45)
- **Production Cleanup**: Removed all `debugPrint` and diagnostic logs used during OCR development for a clean release build. (2026-03-24 18:40)
- **Package Renaming**: Officially updated the Android App ID to `com.trisoftsg.swimpb_tracker` for Play Store compliance. (2026-03-24 20:30)
- **Security & Optimization**: Conducted an R8 minification audit. Remained on the standard build for v1.1.0 to prioritize absolute runtime stability. (2026-03-24 21:15)

### Fixed
- **Team Data Persistence**: Fixed a critical issue where swimmer nationality and photos were not restored during ZIP imports. Existing swimmers and their metadata are now correctly merged and updated. (2026-03-24 18:42)
- **Photo Sync**: Standardized photo filename generation for cross-platform reliability in export archives. (2026-03-24 18:40)
- **History UI**: Removed redundant club/team display from individual events in the meet history list for a cleaner look. (2026-03-24 18:29)
- **ZIP Support**: Enabled the `.zip` extension in the file picker to allow multi-swimmer team data imports (including photos). (2026-03-24 18:21)
- **Tab Tooltips**: Restored missing tooltips for primary navigation (2026-03-24 11:01).
- **Chart Annotations**: Optimized label placement to prevent overlapping when qualification and goal lines are close (2026-03-24 17:22).
- **Light Mode Contrast**: Fixed "Goal" button visibility and chart highlights for light theme users (2026-03-24 17:15).

---

## [v1.0.3+9] - 2026-03-23
### Added
- **TimeUtils**: Initial implementation of centralized time formatting and parsing.
- **BaseReport Mixin**: Standardized PDF report layouts and styling.
- **Exit App Confirmation**: Added safety dialog during app closure.

---

## Future Enhancements & Roadmap

### 📱 User Interface & Experience
- [ ] **Sharing Feature**: Implement "Share with a Friend" in the Settings menu.
- [ ] **Smart Notifications**: Goal-proximity alerts and automatic "Qualification Watch" notifications.

### ☁️ Cloud & Connectivity
- [ ] **Cloud Sync**: Firebase integration for secure multi-device backup.
- [ ] **User Authentication**: Secure login via Google, Facebook, and Email.
- [ ] **Wearable Sync**: Integration with Garmin and Apple Watch.

### 🏆 OCR & Automated Data Entry
- [x] **OCR Hardening (v1.1.0 Ready)**: Advanced grid extraction and strict garbage filtering. Reliability ~85%. Parked to prioritize file-based stability.
- [ ] **Season Planner**: Group meets into seasons and set "Target Meet" goals with a Taper Visualizer.
- [ ] **Coach/Parent Portal**: Secure, view-only access for real-time progress monitoring.
