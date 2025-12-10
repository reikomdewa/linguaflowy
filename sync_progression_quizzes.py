import firebase_admin
from firebase_admin import credentials, firestore
import json
import os
import sys
import re
from datetime import datetime

# --- CONFIGURATION ---
SERVICE_ACCOUNT_FILE = "serviceAccountKey.json"
INPUT_DIR = "assets/progression_quizzes" 

# REGEX: Matches "es_u01_basics.json"
FILENAME_PATTERN = re.compile(r"^([a-z]{2})_u(\d+)_(.+)\.json$")

def initialize_firebase():
    if not os.path.exists(SERVICE_ACCOUNT_FILE):
        print(f"❌ Error: {SERVICE_ACCOUNT_FILE} not found.")
        sys.exit(1)
    try:
        cred = credentials.Certificate(SERVICE_ACCOUNT_FILE)
        if not firebase_admin._apps:
            firebase_admin.initialize_app(cred)
        return firestore.client()
    except Exception as e:
        print(f"❌ Auth Error: {e}")
        sys.exit(1)

def process_file(db, filepath, filename):
    # 1. Parse Filename
    match = FILENAME_PATTERN.match(filename)
    if not match:
        print(f"   ⚠️ SKIPPING: '{filename}'")
        print("      (Name must match format: 'es_u01_topic.json')")
        return False
    
    lang_code = match.group(1)
    unit_index = int(match.group(2))
    topic_slug = match.group(3)
    
    display_title = topic_slug.replace("_", " ").title()

    # 2. Read JSON
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            questions = json.load(f)
    except Exception as e:
        print(f"   ❌ Error reading JSON: {e}")
        return False

    if not isinstance(questions, list):
        print(f"   ❌ Error: Root of JSON must be a list []")
        return False

    # 3. Create ID
    doc_id = f"{lang_code}_u{unit_index:02d}_{topic_slug}"

    print(f"   🚀 Syncing: {lang_code.upper()} Unit {unit_index}: {display_title} ({len(questions)} Qs)")

    # 4. Extract 'createdAt' from JSON (From the Generator Script)
    # We look at the first question to find the timestamp for the whole lesson.
    created_at_val = firestore.SERVER_TIMESTAMP # Default to NOW if missing in JSON
    
    if len(questions) > 0 and isinstance(questions[0], dict):
        raw_date = questions[0].get('createdAt')
        if raw_date:
            try:
                # Convert ISO string (e.g., "2025-12-10T...") to Python datetime
                # This ensures Firestore stores it as a Timestamp, allowing perfect sorting.
                if raw_date.endswith('Z'):
                    raw_date = raw_date[:-1] + '+00:00'
                created_at_val = datetime.fromisoformat(raw_date)
            except Exception:
                # If parsing fails, store string (Flutter app handles this too)
                created_at_val = raw_date

    # 5. Prepare Firestore Data
    data = {
        "id": doc_id,
        "language": lang_code,
        "unitIndex": unit_index,
        "topic": display_title,
        "questions": questions,
        "questionCount": len(questions),
        "type": "progression_quiz", 
        "createdAt": created_at_val,         # <--- STABLE SORT KEY
        "updatedAt": firestore.SERVER_TIMESTAMP
    }

    # 6. Upload
    try:
        db.collection('quiz_levels').document(doc_id).set(data, merge=True)
        return True
    except Exception as e:
        print(f"      ❌ Upload failed: {e}")
        return False

def main():
    print(f"\n{'='*60}")
    print("🎓 PROGRESSION QUIZ SYNC STARTED")
    print(f"{'='*60}\n")
    
    db = initialize_firebase()
    
    if not os.path.exists(INPUT_DIR):
        print(f"❌ Error: Directory '{INPUT_DIR}' not found.")
        return

    files = [f for f in os.listdir(INPUT_DIR) if f.endswith('.json')]
    
    if not files:
        print("   No JSON files found to sync.")
        return

    success_count = 0
    for f in files:
        if process_file(db, os.path.join(INPUT_DIR, f), f):
            success_count += 1

    print(f"\n✅ SUCCESS: Synced {success_count} quiz levels to Firestore.")

if __name__ == "__main__":
    main()