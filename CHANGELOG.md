# SwimPB Tracker Changelog

This document tracks all changes, enhancements, and planned features for the SwimPB Tracker application.
    
## [v1.1.5] - 2026-03-26
### Added
- **Historical PB Milestones**: Implemented automatic "PB" badges in the History (Meets) tab for races that were a personal best at the time they occurred. (2026-03-26 16:35)
- **Smooth Tab Transitions**: Replaced the default sliding tab transition with a premium 300ms cross-fade using `AnimatedSwitcher` for a more modern feel. (2026-03-26 16:55)
- **SwimCloud to SwimPB Converter**: Added a standalone Python utility in `scripts/` to extract historical data from SwimCloud.com and convert it to SwimPB CSV format. (2026-03-26 17:40)

## [v1.1.4] - 2026-03-26
### Added
- **Qualification Times Viewer**: Implementation of a comprehensive standards viewer for SNAG 2026, accessible via the Settings menu. (2026-03-25 21:30)
- **5-Way Stroke Filter**: Added a high-density, TabBar-style toggle (Fly, Back, Breast, Free, IM) to the viewer for fast navigation. (2026-03-25 21:40)
- **Pixel-Perfect UI Refinement**: Switched to a Row-based layout to eliminate vertical whitespace and ensure a 1:1 visual match with the main screen's "detached pill" selectors. (2026-03-25 21:45)
- **Theme Toggle Fix**: Resolved an initialization bug where the first toggle operation failed to visually change the theme due to inaccurate system state detection. (2026-03-25 22:05)
- **Report Swimmer Selection**: Added a required swimmer selection step when generating reports from the Settings menu, ensuring the correct profile is targeted. (2026-03-25 22:15)
- **Qualification Viewer UI**: Refined event group headers to match the card body (transparent background) while maintaining the requested white text style. (2026-03-26 07:25)
- **App Help Section Update**: Synchronized in-app documentation with the latest v1.1.4 feature set, including SNAG 2026 standards and History tab filtering. (2026-03-26 08:30)
- **Collapsible Help Sections**: Implemented a stateful, collapsible UI for the "Settings Menu", "Importing Data", "Technical Details", and "Additional Information" help sections to reduce clutter. (2026-03-26 09:05)
- **Chart Visual Refinement**: Reduced the thickness of graph lines (Progression, QT, and Goal) by 50% for a more refined and premium look in the "Chart" tab. (2026-03-26 09:25)
- **Persistent Tooltips**: Enhanced the charting experience by making data point tooltips persist after selection. They remain visible until a new point is selected or the chart background is tapped. (2026-03-26 13:40)
- **Vertical Tooltip Connectors**: Implemented a full-height dashed vertical line that visually links selected data points to their persistent tooltips at the top and the date axis at the bottom. (2026-03-26 14:05)
- **Chart Data Requirement**: Increased the minimum data points required to render a chart from 2 to 3, with an updated user message: "3+ RESULTS REQUIRED FOR A CHART". (2026-03-26 16:25)

## [v1.1.3] - 2026-03-25
### Fixed
- **SNAG QTs (Male)**: Resolved a critical issue where male qualification times were not being seeded in the production app. (2026-03-25 06:55)
- **Gender Export**: Fixed missing gender field in CSV and XLSX exports to ensure data integrity during import/export. (2026-03-25 07:12)
- **Database Seeding**: Optimized the standards initialization to use a "seed once" guard, preventing duplicate entries and improving startup time. (2026-03-25 07:10)
### Added
- **History Tab Filter**: Added a styled three-way toggle (All, LCM, SCM) to the History tab, allowing users to quickly filter swim meets by course type. (2026-03-25 19:46)

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
- [ ] **Visual Polish**: Custom stroke icons (Fly, Back, Breast, Free, IM) and enhanced micro-interactions for tab transitions.
- [ ] **Sharing Feature**: Implement "Share with a Friend" in the Settings menu.
- [ ] **Smart Notifications**: Goal-proximity alerts and automatic "Qualification Watch" notifications.

### 💾 Data & Analytics
- [ ] **Meet Analytics Dashboard**: High-level summaries including "Most Improved Stroke," meet counts, and success rates for goals/QTs.
- [ ] **Enhanced Goal Tracking**: Display interim "step" goals directly on the Progression charts.
- [ ] **Quick-Add Actions**: Memory-aware data entry (last meet/date) and quick duplication of events in History.
- [ ] **Split Times Support**: Enable recording of 25m (SCM) and 50m (LCM) splits for detailed performance analysis.
- [ ] **Relational Export Format**: Redesign XLSX/CSV exports to separate Swimmer Profiles from Results/Goals.

### 🏆 Advanced Features
- [ ] **Season Planner**: Group meets into seasons and set "Target Meet" goals with a Taper Visualizer and countdown widgets.
- [ ] **Cloud Sync**: Firebase integration for secure multi-device backup and user authentication.
- [ ] **Coach/Parent Portal**: Secure, view-only access for real-time progress monitoring.
- [ ] **Wearable Sync**: Integration with Garmin and Apple Watch.
