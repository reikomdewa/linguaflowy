import firebase_admin
from firebase_admin import credentials, firestore
import json
import os
import sys
import time

# --- CONFIGURATION ---
SERVICE_ACCOUNT_FILE = "serviceAccountKey.json"

# Safety Limit: Firestore max is 1,048,576 bytes. 
# We set it to ~950KB to account for metadata overhead.
MAX_DOC_SIZE_BYTES = 950000 

# UPDATED PATHS
TARGET_DIRECTORIES = [
    "assets/guided_courses",
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
        sys.exit(1)
        
    try:
        cred = credentials.Certificate(SERVICE_ACCOUNT_FILE)
        if not firebase_admin._apps:
            firebase_admin.initialize_app(cred)
        return firestore.client()
    except Exception as e:
        print(f"\n❌ FIREBASE AUTH ERROR: {e}")
        sys.exit(1)

def get_document_size(data):
    """Approximates the byte size of the JSON document."""
    # json.dumps creates the string representation, .encode gets actual bytes
    return len(json.dumps(data).encode('utf-8'))

def safe_commit(batch):
    """Commits a batch with error handling so one bad batch doesn't crash the script."""
    try:
        batch.commit()
        return True
    except Exception as e:
        print(f"\n❌ BATCH COMMIT FAILED: {e}")
        print("   (Some items in this batch were not saved)")
        return False

def process_file(db, filepath):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            lessons = json.load(f)
    except Exception as e:
        print(f"   ⚠️ Could not read {filepath}: {e}")
        return 0, 0, 0 # Uploaded, Skipped, TooBig

    uploaded_count = 0
    skipped_count = 0
    too_big_count = 0

    batch = db.batch()
    batch_counter = 0
    BATCH_LIMIT = 400 

    print(f"   📂 Processing: {os.path.basename(filepath)} ({len(lessons)} items)")

    for lesson in lessons:
        lesson_id = str(lesson.get('id'))
        
        # --- 1. SIZE CHECK (Prevents the crash) ---
        doc_size = get_document_size(lesson)
        if doc_size > MAX_DOC_SIZE_BYTES:
            size_mb = doc_size / (1024 * 1024)
            print(f"      ⚠️ SKIPPING HUGE DOC: {lesson_id} ({size_mb:.2f} MB)")
            too_big_count += 1
            continue

        # --- 2. Check Existence ---
        doc_ref = db.collection('lessons').document(lesson_id)
        doc = doc_ref.get()

        if doc.exists:
            skipped_count += 1
        else:
            # Fix data consistency
            if 'videoUrl' not in lesson and 'audioUrl' in lesson:
                lesson['videoUrl'] = lesson['audioUrl']
            
            # Add to batch
            batch.set(doc_ref, lesson, merge=True)
            batch_counter += 1
            uploaded_count += 1

        # --- 3. Commit Batch ---
        if batch_counter >= BATCH_LIMIT:
            if safe_commit(batch):
                print(f"      💾 Committed batch of {BATCH_LIMIT}...")
            
            batch = db.batch() # Reset batch
            batch_counter = 0

    # Final commit
    if batch_counter > 0:
        safe_commit(batch)

    return uploaded_count, skipped_count, too_big_count

def main():
    print(f"\n{'='*60}")
    print("🔥 FIREBASE SYNC STARTED (Safe Mode)")
    print(f"{'='*60}\n")
    
    db = initialize_firebase()
    
    total_uploaded = 0
    total_skipped = 0
    total_too_big = 0
    start_time = time.time()

    for folder in TARGET_DIRECTORIES:
        if not os.path.exists(folder):
            continue

        for filename in os.listdir(folder):
            if filename.endswith(".json"):
                filepath = os.path.join(folder, filename)
                up, skip, big = process_file(db, filepath)
                total_uploaded += up
                total_skipped += skip
                total_too_big += big

    elapsed = time.time() - start_time
    minutes = int(elapsed // 60)
    seconds = int(elapsed % 60)

    print(f"\n{'='*60}")
    print(f"🎉 SYNC COMPLETE in {minutes}m {seconds}s")
    print(f"✅ Uploaded New: {total_uploaded}")
    print(f"⏭️  Skipped (Duplicate): {total_skipped}")
    print(f"⚠️  Skipped (Too Large): {total_too_big}")
    print(f"{'='*60}")

if __name__ == "__main__":
    main()