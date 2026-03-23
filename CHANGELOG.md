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
- [ ] **Sharing Feature**: Implement "Share with a Friend" in the Settings menu (currently a placeholder).
- [ ] **Service Layer Alignment**: Refactor `ThemeService` and `PreferenceService` for better architectural consistency.
- [ ] **Cloud Sync & Firebase**: Upgrade the app with Firebase for secure cloud backup, team synchronization, and advanced crashlytics.
- [ ] **Advanced Analytics**: Add more detailed swim progression metrics, cross-swimmer comparisons, and **Block Time** (swimmer reaction time off the start blocks).
