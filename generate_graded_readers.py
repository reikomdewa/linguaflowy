import json
import os
import datetime
from datasets import load_dataset # pip install datasets

# --- CONFIGURATION ---
OUTPUT_DIR = "assets/storybooks_lessons"

# Language Pairs (App Code -> OPUS Pair)
# Note: OPUS books are usually English <-> Target
LANG_PAIRS = {
    'fr': 'en-fr',
    'es': 'en-es',
    'de': 'en-de',
    'pt': 'en-pt',
    'it': 'en-it',
    'nl': 'en-nl',
    'ru': 'en-ru',
    'pl': 'en-pl',
    # 'tr': 'en-tr', # Add if you downloaded Turkish
    # 'ar': 'en-ar', # Add if you downloaded Arabic
}

# Settings
SENTENCES_PER_LESSON = 15  # How many pairs per "Book"
MAX_LESSONS = 20           # Max number of practice sets to generate

def generate_opus_lessons(app_lang, opus_pair):
    print(f"  📚 Loading OPUS Books for {app_lang.upper()} ({opus_pair})...")
    new_lessons = []
    
    try:
        # Load from HuggingFace cache (FAST)
        dataset = load_dataset("opus_books", opus_pair, split="train")
        
        current_text_block = []
        current_sentences = []
        lesson_count = 0
        
        for i, item in enumerate(dataset):
            if lesson_count >= MAX_LESSONS: break
            
            # Extract text
            pair = item['translation']
            src_txt = pair.get('en', '').strip()
            tgt_txt = pair.get(app_lang, '').strip()
            
            # Filter bad data (too short/long)
            if len(tgt_txt) < 10 or len(tgt_txt) > 200: continue
            
            # Format: Target Language \n (English Meaning)
            # This allows the user to read the target, but see the meaning below.
            formatted_pair = f"{tgt_txt}\n({src_txt})"
            
            current_text_block.append(formatted_pair)
            current_sentences.append(tgt_txt) # For TTS/Logic, only use target lang
            
            # If batch is full, package it as a "Lesson"
            if len(current_text_block) >= SENTENCES_PER_LESSON:
                lesson_count += 1
                
                full_content = "\n\n".join(current_text_block)
                
                lesson_obj = {
                    "id": f"opus_{app_lang}_{lesson_count}",
                    "userId": "system_opus",
                    "title": f"Sentence Practice {lesson_count}",
                    "language": app_lang,
                    "content": full_content,
                    "sentences": current_sentences, # Array of target strings
                    "transcript": [],
                    "createdAt": datetime.datetime.now().isoformat(),
                    "imageUrl": "assets/images/book_cover_placeholder.png", 
                    "type": "text",
                    "difficulty": "advanced", # Books are usually literary
                    "videoUrl": None,
                    "isFavorite": False,
                    "progress": 0,
                    "author": "OPUS Books",
                    "genre": "sentences"
                }
                
                new_lessons.append(lesson_obj)
                
                # Reset batch
                current_text_block = []
                current_sentences = []
                
        print(f"     ✅ Generated {len(new_lessons)} OPUS practice sets.")
        return new_lessons

    except Exception as e:
        print(f"     ⚠️ Error loading OPUS {opus_pair}: {e}")
        return []

def main():
    if not os.path.exists(OUTPUT_DIR):
        print(f"❌ Error: Directory {OUTPUT_DIR} does not exist.")
        return

    for lang_code, opus_pair in LANG_PAIRS.items():
        filename = f"storybooks_{lang_code}.json"
        filepath = os.path.join(OUTPUT_DIR, filename)
        
        print(f"\nProcessing {lang_code.upper()}...")
        
        # 1. Load Existing Data (ASP Stories)
        existing_data = []
        if os.path.exists(filepath):
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    existing_data = json.load(f)
                print(f"     📂 Loaded {len(existing_data)} existing stories.")
            except:
                print("     ⚠️ Could not read existing file, starting fresh.")
        
        # 2. Filter out OLD Opus data (to avoid duplicates if you run script twice)
        # We keep everything that does NOT start with "opus_"
        clean_data = [item for item in existing_data if not item['id'].startswith("opus_")]
        
        # 3. Generate NEW Opus Data
        opus_lessons = generate_opus_lessons(lang_code, opus_pair)
        
        # 4. Merge
        final_list = clean_data + opus_lessons
        
        # 5. Save
        if final_list:
            with open(filepath, 'w', encoding='utf-8') as f:
                json.dump(final_list, f, ensure_ascii=False, indent=None)
            print(f"     💾 Saved total {len(final_list)} lessons to {filename}")

if __name__ == "__main__":
    main()