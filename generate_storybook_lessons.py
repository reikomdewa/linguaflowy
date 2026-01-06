import os
import json
import re
import datetime

# ==============================================================================
# CONFIGURATION
# ==============================================================================

# 1. PATH TO DOWNLOADED REPO
REPO_ROOT_PATH = "asp-source" 

# 2. OUTPUT DIRECTORY
OUTPUT_DIR = "assets/storybooks_lessons"

# 3. LEVEL MAPPING
# Global Storybooks uses numerical levels 1-5.
LEVEL_MAP = {
    '1': 'beginner',
    '2': 'beginner',
    '3': 'intermediate',
    '4': 'intermediate',
    '5': 'advanced'
}

# ==============================================================================
# LOGIC
# ==============================================================================

def clean_text_line(text):
    """Removes markdown formatting (*, _, #) and image links."""
    # Remove image links like ![alt text](url)
    text = re.sub(r'!\[.*?\]\(.*?\)', '', text)
    # Remove bold/italic markers
    text = text.replace('*', '').replace('_', '').replace('#', '')
    return text.strip()

def parse_markdown(file_path):
    """
    Robustly parses a Global Storybooks markdown file.
    Strategies for Title Finding:
    1. YAML Frontmatter (title:)
    2. First Markdown Header (# Title)
    3. Filename (the-story-name.md -> The Story Name)
    """
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    metadata = {
        'title': 'Unknown',
        'level': '3', # Default to intermediate
        'author': 'Global Storybooks'
    }
    
    content_lines = []
    is_frontmatter = False
    frontmatter_found = False
    
    # --- PASS 1: Read File Line by Line ---
    for line in lines:
        stripped = line.strip()
        
        # Detect YAML block start/end
        if stripped == '---':
            is_frontmatter = not is_frontmatter
            if is_frontmatter: frontmatter_found = True
            continue
            
        if is_frontmatter:
            # Parse YAML loosely
            lower_line = stripped.lower()
            if lower_line.startswith('title:'):
                # Split only on first colon
                parts = stripped.split(':', 1)
                if len(parts) > 1:
                    metadata['title'] = parts[1].strip().strip('"').strip("'")
            elif lower_line.startswith('level:'):
                parts = stripped.split(':', 1)
                if len(parts) > 1:
                    metadata['level'] = parts[1].strip()
            elif lower_line.startswith('author:'):
                parts = stripped.split(':', 1)
                if len(parts) > 1:
                    metadata['author'] = parts[1].strip()
        else:
            # This is content (or a header)
            if stripped:
                clean = clean_text_line(stripped)
                if clean: 
                    content_lines.append(clean)

    # --- PASS 2: Fallback Strategies for Title ---
    
    # Strategy A: If title is still Unknown, look for the first header in content
    if metadata['title'] == 'Unknown':
        for line in lines:
            stripped = line.strip()
            # If line starts with # but is NOT in frontmatter block
            if stripped.startswith('# ') and not stripped.startswith('---'):
                metadata['title'] = stripped.replace('#', '').strip()
                break

    # Strategy B: Use Filename
    if metadata['title'] == 'Unknown':
        filename = os.path.basename(file_path)
        # remove extension
        base = os.path.splitext(filename)[0]
        # replace dashes/underscores with spaces and Capitalize
        metadata['title'] = base.replace('-', ' ').replace('_', ' ').title()

    full_content = "\n\n".join(content_lines)
    return metadata, full_content

def get_all_language_folders(root_path):
    """
    Scans the directory and returns a list of all subfolders 
    that are likely language codes.
    """
    try:
        all_items = os.listdir(root_path)
    except FileNotFoundError:
        return []

    lang_folders = []
    for item in all_items:
        item_path = os.path.join(root_path, item)
        
        # We only want directories
        if os.path.isdir(item_path):
            # Ignore hidden folders like .git
            if item.startswith('.'):
                continue
            # Assume the folder name is the language code (e.g., 'ach', 'fr', 'tw-asan')
            lang_folders.append(item)
            
    return sorted(lang_folders)

def process_languages():
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

    total_books = 0

    print(f"🚀 Starting processing from repo: {REPO_ROOT_PATH}")
    
    # Dynamically get list of folders
    language_folders = get_all_language_folders(REPO_ROOT_PATH)
    
    if not language_folders:
        print("❌ No folders found! Check your REPO_ROOT_PATH.")
        return

    print(f"🌍 Found {len(language_folders)} language folders.")

    for lang_code in language_folders:
        lang_path = os.path.join(REPO_ROOT_PATH, lang_code)
        
        print(f"📂 Processing {lang_code}...")
        
        lessons = []
        # Get all markdown files in the specific language folder
        files = [f for f in os.listdir(lang_path) if f.endswith('.md')]

        for filename in files:
            file_path = os.path.join(lang_path, filename)
            
            try:
                meta, content = parse_markdown(file_path)
                
                # Skip files that are essentially empty
                if len(content) < 20: 
                    continue

                # Map Level to App Difficulty
                raw_level = meta.get('level', '3').replace('Level', '').strip()
                difficulty = LEVEL_MAP.get(raw_level, 'intermediate')

                # Create Sentences for UI (Split by punctuation)
                sentences = re.split(r'(?<=[.!?])\s+', content)
                sentences = [s.strip() for s in sentences if s.strip()]

                # Build Lesson Model
                lesson = {
                    "id": f"story_{lang_code}_{filename.replace('.md', '')}",
                    "userId": "system_storybooks",
                    "title": meta['title'],
                    "language": lang_code, # Uses folder name as language code
                    "content": content,
                    "sentences": sentences,
                    "transcript": [],
                    "createdAt": datetime.datetime.now().isoformat(),
                    "imageUrl": "assets/images/book_cover_placeholder.png", 
                    "type": "text",
                    "difficulty": difficulty,
                    "videoUrl": None,
                    "isFavorite": False,
                    "progress": 0,
                    "author": meta['author'],
                    "genre": "short_story" 
                }
                
                lessons.append(lesson)

            except Exception as e:
                print(f"   ❌ Error parsing {filename}: {e}")

        # Save to JSON if we found books
        if lessons:
            output_file = os.path.join(OUTPUT_DIR, f"storybooks_{lang_code}.json")
            try:
                with open(output_file, 'w', encoding='utf-8') as f:
                    # Use separators to minify JSON size
                    json.dump(lessons, f, ensure_ascii=False, separators=(',', ':'))
                print(f"   ✅ Saved {len(lessons)} stories to {output_file}")
                total_books += len(lessons)
            except Exception as e:
                print(f"   ❌ Error saving JSON: {e}")
        else:
            print(f"   ⚠️ No valid stories found in {lang_code}")

    print(f"\n🎉 DONE! Processed {total_books} stories across {len(language_folders)} languages.")

if __name__ == "__main__":
    if not os.path.exists(REPO_ROOT_PATH):
        print(f"❌ ERROR: Could not find the repository folder: '{REPO_ROOT_PATH}'")
        print("   Please edit line 11 of this script to match your folder name.")
    else:
        process_languages()