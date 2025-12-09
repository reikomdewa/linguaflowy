import firebase_admin
from firebase_admin import credentials, firestore
import json
import os
import sys
import re

# --- CONFIGURATION ---
SERVICE_ACCOUNT_FILE = "serviceAccountKey.json"
# This must match where your save script put the file
INPUT_DIR = "assets/progression_quizzes" 

# REGEX: Matches "es_u01_basics.json"
# Group 1: Language (es)
# Group 2: Unit Number (01)
# Group 3: Topic (basics)
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
    # 1. Parse Filename for Metadata
    match = FILENAME_PATTERN.match(filename)
    if not match:
        print(f"   ⚠️ SKIPPING: '{filename}'")
        print("      (Name must match format: 'es_u01_topic.json')")
        return False
    
    lang_code = match.group(1)
    unit_index = int(match.group(2))
    topic_slug = match.group(3)
    
    # Clean up topic string (e.g. "food_and_drink" -> "Food And Drink")
    display_title = topic_slug.replace("_", " ").title()

    # 2. Read JSON Content
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            questions = json.load(f)
    except Exception as e:
        print(f"   ❌ Error reading JSON: {e}")
        return False

    if not isinstance(questions, list):
        print(f"   ❌ Error: Root of JSON must be a list []")
        return False

    # 3. Create a ID (e.g., es_u01_basics)
    doc_id = f"{lang_code}_u{unit_index:02d}_{topic_slug}"

    print(f"   🚀 Syncing: {lang_code.upper()} Unit {unit_index}: {display_title} ({len(questions)} Qs)")

    # 4. Prepare Firestore Data
    # We store metadata for the Path UI, and the questions array for the Quiz UI
    data = {
        "id": doc_id,
        "language": lang_code,
        "unitIndex": unit_index,     # Crucial for sorting in the app
        "topic": display_title,      # "Basics"
        "questions": questions,      # The content
        "questionCount": len(questions),
        "type": "progression_quiz", 
        "updatedAt": firestore.SERVER_TIMESTAMP
    }

    # 5. Upload (Merge=True updates existing levels without deleting extra fields)
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