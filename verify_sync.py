import firebase_admin
from firebase_admin import credentials, firestore
import json
import os

SERVICE_ACCOUNT_FILE = "serviceAccountKey.json"

def initialize_firebase():
    if not firebase_admin._apps:
        cred = credentials.Certificate(SERVICE_ACCOUNT_FILE)
        firebase_admin.initialize_app(cred)
    return firestore.client()

def check_storybooks():
    db = initialize_firebase()
    
    # Read local storybook files
    storybook_dir = "assets/storybooks_lessons"
    
    if not os.path.exists(storybook_dir):
        print(f"❌ Directory not found: {storybook_dir}")
        return
    
    total_local = 0
    total_in_firebase = 0
    missing = []
    
    for filename in os.listdir(storybook_dir):
        if filename.endswith(".json"):
            filepath = os.path.join(storybook_dir, filename)
            
            with open(filepath, 'r', encoding='utf-8') as f:
                lessons = json.load(f)
            
            print(f"\n📁 Checking {filename} ({len(lessons)} lessons)...")
            
            for lesson in lessons:
                lesson_id = str(lesson.get('id'))
                total_local += 1
                
                # Check if exists in Firebase
                doc_ref = db.collection('lessons').document(lesson_id)
                doc = doc_ref.get()
                
                if doc.exists:
                    total_in_firebase += 1
                    print(f"   ✅ {lesson_id}")
                else:
                    missing.append(lesson_id)
                    print(f"   ❌ {lesson_id} - NOT FOUND")
    
    print(f"\n{'='*60}")
    print(f"📊 VERIFICATION SUMMARY")
    print(f"{'='*60}")
    print(f"Total local storybook lessons: {total_local}")
    print(f"Found in Firebase: {total_in_firebase}")
    print(f"Missing from Firebase: {len(missing)}")
    
    if missing:
        print(f"\n⚠️ Missing IDs: {missing[:10]}")  # Show first 10
    else:
        print(f"\n🎉 All storybook lessons are synced!")
    print(f"{'='*60}")

if __name__ == "__main__":
    check_storybooks()