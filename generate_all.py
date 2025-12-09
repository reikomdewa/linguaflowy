import subprocess
import sys
import time
import os

# List of scripts to run in order.
# These match the filenames in your screenshot.
SCRIPTS = [
    "generate_assets.py",           # General video lessons
    "generate_audio_library.py",    # LibriVox audio
    "generate_beginner_books.py",   # Simple Gutenberg texts
    "generate_books.py",            # Classic/Advanced Gutenberg texts
    "generate_course_content.py",   # Structured video courses
    "generate_native_content.py",   # Trending/Native videos
    "generate_yt_audiobooks.py"     # YouTube Synced Audiobooks
]

def run_script(script_name):
    """Runs a single python script and tracks time/errors."""
    
    if not os.path.exists(script_name):
        print(f"\n❌ SKIPPING: {script_name} (File not found)")
        return

    print(f"\n{'='*60}")
    print(f"🚀 STARTING: {script_name}")
    print(f"{'='*60}\n")

    start_time = time.time()

    try:
        # sys.executable ensures we use the same Python environment 
        # that is currently running this script
        subprocess.run([sys.executable, script_name], check=True)
        
        elapsed = time.time() - start_time
        minutes = int(elapsed // 60)
        seconds = int(elapsed % 60)
        print(f"\n✅ COMPLETED: {script_name} in {minutes}m {seconds}s")
        
    except subprocess.CalledProcessError:
        print(f"\n❌ FAILED: {script_name} exited with an error.")
    except KeyboardInterrupt:
        print(f"\n🛑 STOPPED: Process interrupted by user.")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ ERROR: An unexpected error occurred: {e}")

def main():
    total_start = time.time()
    
    print("--- 📦 STARTING CONTENT GENERATION PIPELINE ---")
    print(f"--- Queue: {len(SCRIPTS)} scripts ---\n")

    for script in SCRIPTS:
        run_script(script)
        # Small pause between scripts to ensure file I/O operations close properly
        time.sleep(1) 

    total_elapsed = time.time() - total_start
    total_mins = int(total_elapsed // 60)
    
    print(f"\n{'='*60}")
    print(f"🎉 ALL TASKS FINISHED")
    print(f"⏱️  Total Runtime: {total_mins} minutes")
    print(f"{'='*60}")

if __name__ == "__main__":
    main()