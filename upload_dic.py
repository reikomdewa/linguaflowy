import os
import firebase_admin
from firebase_admin import credentials, storage

# --- CONFIGURATION ---
# 1. Path to your downloaded JSON key
KEY_PATH = 'serviceAccountKey.json' 

# 2. Your Storage Bucket Name (Do NOT include 'gs://')
# Example: 'linguaflow-12345.appspot.com'
BUCKET_NAME = 'YOUR_PROJECT_ID.appspot.com'

# 3. Path to your local files (Relative to this script)
LOCAL_FOLDER_PATH = './assets/dictionaries'

# 4. Where to put them in the cloud
CLOUD_FOLDER_PATH = 'dictionaries'
# ---------------------

def upload_files():
    # 1. Initialize Firebase
    if not firebase_admin._apps:
        cred = credentials.Certificate(KEY_PATH)
        firebase_admin.initialize_app(cred, {
            'storageBucket': BUCKET_NAME
        })

    bucket = storage.bucket()
    
    # 2. Check if folder exists
    if not os.path.exists(LOCAL_FOLDER_PATH):
        print(f"Error: Folder '{LOCAL_FOLDER_PATH}' not found.")
        return

    # 3. Iterate and Upload
    files = [f for f in os.listdir(LOCAL_FOLDER_PATH) if f.endswith('.txt')]
    total_files = len(files)
    
    print(f"Found {total_files} dictionary files to upload...")

    for index, filename in enumerate(files):
        local_file = os.path.join(LOCAL_FOLDER_PATH, filename)
        
        # Create the path in the cloud (dictionaries/lemmatization-en.txt)
        blob_path = f"{CLOUD_FOLDER_PATH}/{filename}"
        blob = bucket.blob(blob_path)

        print(f"[{index + 1}/{total_files}] Uploading {filename}...")
        
        try:
            blob.upload_from_filename(local_file)
            # Optional: Make public if you want direct HTTP links, 
            # otherwise keep private and use the Flutter SDK to download.
            # blob.make_public() 
        except Exception as e:
            print(f"❌ Failed to upload {filename}: {e}")

    print("\n✅ Upload Complete!")

if __name__ == '__main__':
    upload_files()