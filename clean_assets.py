import os

# --- 🔒 SAFETY CONFIGURATION ---

# 1. DIRECTORIES TO CLEAN
# These are the folders the script will look inside.
TARGET_DIRECTORIES = [
    "assets/guided_courses",
    "assets/native_videos",
    "assets/audio_library",
    "assets/youtube_audio_library",
    "assets/text_lessons",
    "assets/beginner_books"
]

# 2. THE "STARTER PACK" (WHITELIST)
# These files will NEVER be deleted. 
# Keep your "Lesson 1" or "Intro" files here so new users have something offline.
FILES_TO_KEEP = [
    # Guided Courses
    "lessons_en.json", "lessons_es.json", 
    "lessons_fr.json", "lessons_de.json",
    
    # Native Content (Maybe keep one trending list per language)
    "trending_en.json", "trending_es.json",

    # Beginner Books (Keep the list so they can see titles, even if content loads later)
    "beginner_en.json", "beginner_es.json"
]

def clean_directory(directory):
    if not os.path.exists(directory):
        print(f"⚠️  Skipping missing folder: {directory}")
        return

    print(f"\n🧹 Cleaning: {directory}")
    deleted_count = 0
    kept_count = 0

    for filename in os.listdir(directory):
        if not filename.endswith(".json"):
            continue

        filepath = os.path.join(directory, filename)

        if filename in FILES_TO_KEEP:
            print(f"   🛡️  KEPT: {filename}")
            kept_count += 1
        else:
            # --- THE DELETION HAPPENS HERE ---
            os.remove(filepath)
            # print(f"   🗑️  Deleted: {filename}") # Uncomment to see details
            deleted_count += 1

    print(f"   📊 Result: Deleted {deleted_count} | Kept {kept_count}")

def main():
    print(f"\n{'='*60}")
    print("🗑️  ASSET CLEANUP STARTED")
    print("   (Only files in FILES_TO_KEEP will survive)")
    print(f"{'='*60}")

    # Safety confirmation
    confirm = input("\n⚠️  Are you sure you want to delete local JSONs not in the whitelist? (y/n): ")
    if confirm.lower() != 'y':
        print("🛑 Operation cancelled.")
        return

    for folder in TARGET_DIRECTORIES:
        clean_directory(folder)

    print(f"\n{'='*60}")
    print("✨ CLEANUP COMPLETE. Your 'assets' folder is ready for build.")
    print(f"{'='*60}")

if __name__ == "__main__":
    main()