SwimPB Tracker v1.0.1 help and release notes

This README file is intended to answer some basic questions related to app content and function.

The app can track multiple swimmers personal best times. It will track Short Course and Long Course times.

The top tile displays the swimmers profile information. The app is organised in to 4 tabs that record the following:

1. PB times arranged by course type, distance and stroke.
2. The swimmers 5 most recent times selected by distance, stroke and course type.
3. Swimmer progress graphs selected by distance, stroke, course type and time period.
4. A historical list of swim meets that the swimmer has participated in together with all event information and times.

The settings menu allows the user to manage the following:

1. Add a new swimmer.
2. Bulk import swimmer data from .xlsx, .csv or photo files (OCR). Download sample file here.
3. Bulk export swimmer data to either a .xlsx or .csv file.
4. Generate various reports for personal bests, national qualification and personal goals.
5. Toggle the app from light mode to dark mode.
6. Delete a swimmer profile and their swim data.
7. Delete swim data for a selected swimmer.

## Importing & Exporting Data
Managing your data is simple, whether you're tracking one swimmer or a whole team:

*   **Bringing Data In**: You can quickly add lots of records at once using an Excel or CSV file. Tap "Download sample file here" in the app menu to get a template. You can include results for just one person or a whole team in the same file! Once ready, use the "Import" option to upload your file.
*   **Saving Individual Data**: If you export data for a single swimmer, it will be saved as a single Excel or CSV file.
*   **Saving Team Data**: If you export data for multiple swimmers or a whole team, the app will create a ZIP file. This is a special "folder" that keeps everything together—including swimmer photos—so they stay linked to the right profiles when you move them to another device.
*   **Photo Scans**: You can also use your camera to scan results directly from a photo. The app will "read" the times and help you add them to your history.

## Technical Column Details (for CSV)
If you are manually creating or editing a CSV file, please ensure it has these headers:
*   **FirstName, Surname**: Swimmer's name.
*   **Gender**: 'Male' or 'Female'.
*   **DOB**: Date of Birth (YYYY-MM-DD).
*   **Nationality**: 2-letter country code (e.g., SG).
*   **Club**: Swimmer's club name (optional).
*   **MeetTitle**: Name of the swim meet.
*   **MeetDate**: Date of the meet (YYYY-MM-DD).
*   **Course**: 'SCM' or 'LCM'.
*   **Distance**: Numeric distance (50, 100, 200, etc.).
*   **Stroke**: 'Freestyle', 'Backstroke', 'Breaststroke', 'Butterfly', or 'IM'.
*   **Time**: Result or goal time in format 'MM:SS.hh' or 'SS.hh'.
*   **DataType**: 'result' (default) or 'goal'.

Additional information:

The app includes the LCM qualification times as used for the SNAG 2026 meet.

Any time in the PB tab that meets the qualification time is annotated with a gold QT badge. All LCM PB times also include the delta between the PB and QT times. 

Any times in the Recent tab that meet the qualification time are annotated with a gold QT badge.

The graphs displayed in the Chart tab for LCM selections include the qualification standard as a green horizontal line on the graph.

Additionally, users can set their own custom target "Goals" for any event. This is done by tapping the bulls-eye icon on the Chart tab. Custom goals are displayed as blue dashed lines on the graphs, and as a target time on the PB and Recent tabs.

For meet records on the History tab SCM meets are annotated in blue, LCM meets are annotated in green.

Swimmer age is calculated as of the 31st December, this is in line with Singapore Aquatics policy.

Contact: trisoftsg@gmail.com

## License / Copyright
Copyright (c) 2026 trisoftsg. All Rights Reserved.

This software and associated documentation files are proprietary to trisoftsg.

Unauthorized copying, modification, or distribution of this software, via any medium,
is strictly prohibited.   