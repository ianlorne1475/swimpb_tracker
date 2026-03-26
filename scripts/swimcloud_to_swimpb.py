import csv
import sys
import os
from datetime import datetime

try:
    from SwimScraper import SwimScraper as ss
except ImportError:
    print("Error: SwimScraper library not found.")
    print("Please install it using: pip install SwimScraper")
    sys.exit(1)

def map_stroke(sc_event):
    """Maps SwimCloud event string to SwimPB stroke name."""
    sc_event = sc_event.lower()
    if 'free' in sc_event:
        return 'Freestyle'
    if 'back' in sc_event:
        return 'Backstroke'
    if 'breast' in sc_event:
        return 'Breaststroke'
    if 'fly' in sc_event:
        return 'Butterfly'
    if 'im' in sc_event:
        return 'IM'
    return 'Freestyle' # Default fallback

def extract_distance(sc_event):
    """Extracts numeric distance from SwimCloud event string."""
    parts = sc_event.split()
    for part in parts:
        if part.replace('m', '').isdigit():
            return int(part.replace('m', ''))
    return 50 # Default fallback

def format_time(sc_time):
    """Ensures time is in MM:SS.hh or SS.hh format."""
    # SwimCloud sometimes returns seconds as float or string.
    # SwimPB expects MM:SS.hh (e.g., 1:02.34) or SS.hh (e.g., 29.45)
    return str(sc_time).strip()

def convert_swimcloud_to_swimpb(swimmer_id, first_name, surname, dob, gender, nationality, club):
    print(f"Fetching events for Swimmer ID: {swimmer_id}...")
    try:
        event_list = ss.getSwimmerEvents(swimmer_id)
    except Exception as e:
        print(f"Error fetching data from SwimCloud: {e}")
        return

    all_results = []
    
    for event_info in event_list:
        event_name = event_info['event']
        event_id = event_info['event_id']
        
        print(f"  Fetching times for {event_name}...")
        try:
            times = ss.getSwimmerTimes(swimmer_id, event_name, event_id)
        except Exception as e:
            print(f"    Skipping {event_name} due to error: {e}")
            continue

        for t in times:
            # SwimCloud pool types: SCM, LCM, SCY
            course = t['pool_type']
            if course == 'SCY':
                continue # Skip yards for now as SwimPB is meters-focused
            
            result = {
                'FirstName': first_name,
                'Surname': surname,
                'Gender': gender,
                'DOB': dob,
                'Nationality': nationality,
                'Club': club or t.get('team_name', ''),
                'MeetTitle': t['meet_name'],
                'MeetDate': t['date'], # Usually YYYY-MM-DD
                'Course': course,
                'Distance': extract_distance(event_name),
                'Stroke': map_stroke(event_name),
                'Time': format_time(t['time']),
                'DataType': 'result'
            }
            all_results.append(result)

    if not all_results:
        print("No SCM/LCM results found.")
        return

    output_file = f"{first_name}_{surname}_swimcloud_export.csv"
    headers = ['FirstName', 'Surname', 'Gender', 'DOB', 'Nationality', 'Club', 'MeetTitle', 'MeetDate', 'Course', 'Distance', 'Stroke', 'Time', 'DataType']

    with open(output_file, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=headers)
        writer.writeheader()
        writer.writerows(all_results)

    print(f"\nSuccess! Exported {len(all_results)} results to {output_file}")
    print("You can now import this file directly into SwimPB Tracker.")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python swimcloud_to_swimpb.py <SwimmerID>")
        print("Optional: python swimcloud_to_swimpb.py <SwimmerID> <FirstName> <Surname> <DOB:YYYY-MM-DD> <Gender:Male/Female> <Nationality:2-letter>")
        sys.exit(1)

    swimmer_id = sys.argv[1]
    
    # Defaults or interactive input if not provided via CLI
    first_name = sys.argv[2] if len(sys.argv) > 2 else input("Enter Swimmer First Name: ")
    surname = sys.argv[3] if len(sys.argv) > 3 else input("Enter Swimmer Surname: ")
    dob = sys.argv[4] if len(sys.argv) > 4 else input("Enter DOB (YYYY-MM-DD): ")
    gender = sys.argv[5] if len(sys.argv) > 5 else input("Enter Gender (Male/Female): ")
    nationality = sys.argv[6] if len(sys.argv) > 6 else input("Enter Nationality (e.g., SG): ")
    club = input("Enter Club Name (optional, press Enter to use SwimCloud data): ")

    convert_swimcloud_to_swimpb(swimmer_id, first_name, surname, dob, gender, nationality, club)
