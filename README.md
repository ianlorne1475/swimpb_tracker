# SwimPB Tracker

A professional Flutter application designed to track and manage personal best (PB) times for multiple swimmers. Built for efficiency, accuracy, and ease of use, it supports both Short Course (SCM) and Long Course (LCM) results.

## 🚀 Key Features

- **Multi-Swimmer Management**: Track multiple profiles simultaneously with individual history, goals, and photos.
- **SNAG 2026 Integration**: Built-in qualification standards for Singapore National Age Group (SNAG) 2026.
- **Dynamic Dashboards**:
  - **PBs Tab**: Current personal bests with automated QT (Qualification Time) badges and deltas.
  - **Recent Tab**: Track your last 5 performances for any event.
  - **Chart Tab**: Visual progression graphs with target goal lines and qualification benchmarks.
  - **History Tab**: Complete meet-by-meet history with color-coded course indicators.
- **Qualification Times Viewer**: A dedicated, high-density viewer in Settings for browsing all SNAG 2026 standards with 5-way stroke filtering.
- **Smart Data Management**:
  - **Excel/CSV Support**: Bulk import and export for individual or team data.
  - **Team ZIP Archives**: Export entire teams including profile photos for easy device migration.
  - **OCR Scanning**: Extract results directly from meet result photos using on-device text recognition.
- **Professional Analytics**: Generate PDF Performance Reports, PB Certificates, and Goal Tracking summaries.

## 🎨 Design Philosophy

SwimPB Tracker features a modern, high-density UI designed for professional coaches and parents:
- **Glassmorphism Aesthetic**: Semi-transparent overlays and sleek dark/light mode support.
- **Detached Pill Selectors**: Consistent TabBar-style navigation throughout the app.
- **Pixel-Perfect Layouts**: Optimized for viewing 50+ event standards on a single screen.

## 🛠 Tech Stack

- **Framework**: Flutter (Dart)
- **Database**: SQLite (via `sqflite`)
- **PDF Generation**: `pdf` and `printing`
- **OCR Engine**: Google ML Kit Text Recognition
- **Excel Processing**: `excel` package

## 📧 Contact & Support

Developed by **trisoftsg**. For feedback or suggestions, contact us at [trisoftsg@gmail.com](mailto:trisoftsg@gmail.com).

---
Copyright (c) 2026 trisoftsg. All Rights Reserved.
