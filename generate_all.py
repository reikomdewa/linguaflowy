import subprocess
import sys
import time
import os

# List of scripts to run in order.
SCRIPTS = [
    # 1. GENERATION PHASE (Creates local JSONs)
    # "generate_guided_courses.py",           
    "generate_audio_library.py",   
    "generate_audio_lessons.py",
    # "generate_beginner_books.py",   
     "generate_books.py",            
    "generate_course_content.py",   
    "generate_native_content.py",   
     "generate_yt_audiobooks.py",
    
    # 2. UPLOAD PHASE (Syncs to Firebase)
    "sync_to_firebase.py" 
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
        subprocess.run([sys.executable, script_name], check=True)
        
        elapsed = time.time() - start_time
        minutes = int(elapsed // 60)
        seconds = int(elapsed % 60)
        print(f"\n✅ COMPLETED: {script_name} in {minutes}m {seconds}s")
        
    except subprocess.CalledProcessError:
        print(f"\n❌ FAILED: {script_name} exited with an error.")
        # Optional: Stop entire pipeline on failure?
        # sys.exit(1) 
    except KeyboardInterrupt:
        print(f"\n🛑 STOPPED: Process interrupted by user.")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ ERROR: An unexpected error occurred: {e}")

def main():
    total_start = time.time()
    
    print("--- 📦 STARTING GENERATION & SYNC PIPELINE ---")
    print(f"--- Queue: {len(SCRIPTS)} scripts ---\n")

    for script in SCRIPTS:
        run_script(script)
        time.sleep(1) 

    total_elapsed = time.time() - total_start
    total_mins = int(total_elapsed // 60)
    
    print(f"\n{'='*60}")
    print(f"🎉 ALL TASKS FINISHED")
    print(f"⏱️  Total Runtime: {total_mins} minutes")
    print(f"{'='*60}")

if __name__ == "__main__":
    main()