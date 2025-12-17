import json
from pathlib import Path
import shutil

# Path to the JSON file
JSON_PATH = Path("assets/guided_courses/lessons_fr.json")

# Title prefix to remove (Standardized to lowercase for robust matching)
TITLE_PREFIX = "French the natural way".lower().strip()

# Key name for the title field
TITLE_KEY = "title"

def main():
    if not JSON_PATH.exists():
        print(f"Error: File not found at {JSON_PATH}")
        return

    # 1. Create a backup before modifying (Safety first!)
    backup_path = JSON_PATH.with_suffix(".json.bak")
    shutil.copy(JSON_PATH, backup_path)
    print(f"Backup created at {backup_path}")

    # 2. Read the data
    with open(JSON_PATH, "r", encoding="utf-8") as f:
        try:
            lessons = json.load(f)
        except json.JSONDecodeError:
            print("Error: Failed to decode JSON. Check the file format.")
            return

    if not isinstance(lessons, list):
        print("Error: Expected JSON root to be a list of lessons.")
        return

    original_count = len(lessons)

    # 3. Filter lessons
    # We use .strip().lower() to ensure it catches "French the Natural Way" or " french the natural way"
    filtered_lessons = []
    for lesson in lessons:
        title = str(lesson.get(TITLE_KEY, "")).strip().lower()
        
        if not title.startswith(TITLE_PREFIX):
            filtered_lessons.append(lesson)

    removed_count = original_count - len(filtered_lessons)

    # 4. Save the file
    with open(JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(filtered_lessons, f, ensure_ascii=False, indent=2)

    print(f"--- Process Complete ---")
    print(f"Removed: {removed_count} lesson(s).")
    print(f"Remaining: {len(filtered_lessons)} lesson(s).")

if __name__ == "__main__":
    main()