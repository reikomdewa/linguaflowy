import firebase_admin
from firebase_admin import credentials, firestore
import json
import os
import sys
import time

# --- CONFIGURATION ---
SERVICE_ACCOUNT_FILE = "serviceAccountKey.json"

# UPDATED PATHS
TARGET_DIRECTORIES = [
    "assets/guided_courses",         # <--- CORRECTED HERE
    "assets/native_videos",
    "assets/audio_library",
    "assets/youtube_audio_library",
    "assets/text_lessons",
    "assets/beginner_books"
]

def initialize_firebase():
    """Initializes Firebase Admin SDK."""
    if not os.path.exists(SERVICE_ACCOUNT_FILE):
        print(f"\n❌ ERROR: '{SERVICE_ACCOUNT_FILE}' not found.")
        print("   Please download it from Firebase Console -> Project Settings -> Service Accounts.")
        sys.exit(1)
        
    try:
        cred = credentials.Certificate(SERVICE_ACCOUNT_FILE)
        if not firebase_admin._apps:
            firebase_admin.initialize_app(cred)
        return firestore.client()
    except Exception as e:
        print(f"\n❌ FIREBASE AUTH ERROR: {e}")
        sys.exit(1)

def process_file(db, filepath):
    """Reads a JSON file and uploads lessons if they are missing from Firestore."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            lessons = json.load(f)
    except Exception as e:
        print(f"   ⚠️ Could not read {filepath}: {e}")
        return 0, 0

    uploaded_count = 0
    skipped_count = 0

    # Batch initialization
    batch = db.batch()
    batch_counter = 0
    BATCH_LIMIT = 400 

    print(f"   📂 Processing: {os.path.basename(filepath)} ({len(lessons)} items)")

    for lesson in lessons:
        lesson_id = str(lesson.get('id'))
        
        # 1. Check if ID exists in Firestore
        doc_ref = db.collection('lessons').document(lesson_id)
        doc = doc_ref.get()

        if doc.exists:
            skipped_count += 1
        else:
            # 2. Fix data consistency (Video/Audio URL mapping)
            if 'videoUrl' not in lesson and 'audioUrl' in lesson:
                lesson['videoUrl'] = lesson['audioUrl']
            
            # 3. Add to batch
            batch.set(doc_ref, lesson, merge=True)
            batch_counter += 1
            uploaded_count += 1

        # 4. Commit batch if limit reached
        if batch_counter >= BATCH_LIMIT:
            batch.commit()
            batch = db.batch()
            batch_counter = 0
            print(f"      💾 Committed batch of {BATCH_LIMIT}...")

    # Final commit for remaining items
    if batch_counter > 0:
        batch.commit()

    return uploaded_count, skipped_count

def main():
    print(f"\n{'='*60}")
    print("🔥 FIREBASE SYNC STARTED")
    print(f"{'='*60}\n")
    
    db = initialize_firebase()
    
    total_uploaded = 0
    total_skipped = 0
    start_time = time.time()

    for folder in TARGET_DIRECTORIES:
        if not os.path.exists(folder):
            print(f"⚠️  Folder not found, skipping: {folder}")
            continue

        for filename in os.listdir(folder):
            if filename.endswith(".json"):
                filepath = os.path.join(folder, filename)
                up, skip = process_file(db, filepath)
                total_uploaded += up
                total_skipped += skip

    elapsed = time.time() - start_time
    minutes = int(elapsed // 60)
    seconds = int(elapsed % 60)

    print(f"\n{'='*60}")
    print(f"🎉 SYNC COMPLETE in {minutes}m {seconds}s")
    print(f"✅ Uploaded New: {total_uploaded}")
    print(f"⏭️  Skipped (Duplicates): {total_skipped}")
    print(f"{'='*60}")

if __name__ == "__main__":
    main()