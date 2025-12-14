import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore
import os

# --- CONFIGURATION ---
# The specific ID used in your creation script
TARGET_USER_ID = "system_gutenberg" 
# The collection name in Firestore
COLLECTION_NAME = "lessons"
# Path to your downloaded Firebase key
SERVICE_KEY_PATH = "serviceAccountKey.json"

def initialize_firebase():
    """Initializes Firebase Admin SDK."""
    if not os.path.exists(SERVICE_KEY_PATH):
        print(f"❌ Error: '{SERVICE_KEY_PATH}' not found.")
        print("1. Go to Firebase Console -> Project Settings -> Service Accounts")
        print("2. Generate a new private key")
        print("3. Save it in this folder as 'serviceAccountKey.json'")
        exit(1)

    cred = credentials.Certificate(SERVICE_KEY_PATH)
    firebase_admin.initialize_app(cred)
    return firestore.client()

def delete_collection_by_query(db, batch_size=400):
    """Deletes documents matching the query in batches."""
    coll_ref = db.collection(COLLECTION_NAME)
    # Query strictly for lessons created by the gutenberg script
    query = coll_ref.where("userId", "==", TARGET_USER_ID)
    
    total_deleted = 0
    
    print(f"🔍 Searching for lessons with userId: '{TARGET_USER_ID}'...")

    while True:
        # Get a batch of documents
        docs = list(query.limit(batch_size).stream())
        deleted_count = 0

        if not docs:
            break

        batch = db.batch()
        for doc in docs:
            print(f"   - Marking for deletion: {doc.id}")
            batch.delete(doc.reference)
            deleted_count += 1

        # Commit the batch
        batch.commit()
        total_deleted += deleted_count
        print(f"🗑️  Committed batch of {deleted_count} deletions...")

    if total_deleted == 0:
        print("✅ No lessons found to delete.")
    else:
        print(f"✅ Successfully deleted {total_deleted} lessons from Firestore.")

def clean_local_files():
    """Optional: Cleans the generated JSON files locally."""
    output_dir = "assets/text_lessons"
    if os.path.exists(output_dir):
        choice = input(f"\nDo you also want to delete local JSON files in '{output_dir}'? (y/n): ").lower()
        if choice == 'y':
            for filename in os.listdir(output_dir):
                if filename.startswith("books_") and filename.endswith(".json"):
                    file_path = os.path.join(output_dir, filename)
                    os.remove(file_path)
                    print(f"   Deleted local file: {filename}")
            print("✅ Local cleanup complete.")

if __name__ == "__main__":
    print("==========================================")
    print("🔥 FIREBASE LESSON CLEANUP TOOL 🔥")
    print("==========================================")
    
    # 1. Initialize DB
    db = initialize_firebase()

    # 2. Confirm Safety
    print(f"\nWARNING: This will delete ALL lessons where userId='{TARGET_USER_ID}'.")
    confirm = input("Are you sure you want to proceed? (type 'yes' to confirm): ")
    
    if confirm.lower() == "yes":
        # 3. Run Deletion
        delete_collection_by_query(db)
        
        # 4. Ask about local files
        clean_local_files()
    else:
        print("❌ Operation cancelled.")