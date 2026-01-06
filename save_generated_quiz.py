import json
import os
import re  # <--- Added for text cleaning

OUTPUT_DIR = "assets/progression_quizzes"

def main():
    # flush=True ensures the text appears immediately in all IDEs
    print("\n===================================", flush=True)
    print("      🧠 AI QUIZ PASTER ", flush=True)
    print("===================================\n", flush=True)
    
    try:
        lang = input("1. Lang Code (es, fr): ").strip().lower()
        if not lang: return
        
        unit = input("2. Unit Number (1, 2...): ").strip()
        if not unit: return
        
        topic = input("3. Topic (Basics): ").strip()
        if not topic: return
    except KeyboardInterrupt:
        return

    print(f"\n4. PASTE JSON BELOW.", flush=True)
    print("   Type 'DONE' (all caps) on a new line and press ENTER to finish:", flush=True)
    print("---------------------------------------------------------------", flush=True)

    lines = []
    while True:
        try:
            line = input()
            # The Magic Word to stop the loop
            if line.strip() == 'DONE':
                break
            lines.append(line)
        except EOFError:
            break
            
    raw_json = "\n".join(lines)

    # Naming and Saving
    try:
        data = json.loads(raw_json)
        
        unit_str = f"{int(unit):02d}"
        
        # --- FIX START ---
        # 1. Lowercase
        # 2. Regex: Remove anything that is NOT a letter, number, whitespace, or hyphen
        #    This effectively removes '?', ':', '*', etc.
        safe_topic = re.sub(r'[^\w\s-]', '', topic.lower())
        
        # 3. Replace spaces with underscores
        topic_slug = safe_topic.strip().replace(" ", "_")
        # --- FIX END ---
        
        filename = f"{lang}_u{unit_str}_{topic_slug}.json"
        
        if not os.path.exists(OUTPUT_DIR):
            os.makedirs(OUTPUT_DIR)
            
        full_path = os.path.join(OUTPUT_DIR, filename)
        
        with open(full_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            
        print(f"\n✅ Saved: {full_path}")
        
    except json.JSONDecodeError:
        print("\n❌ Invalid JSON pasted.")
    except Exception as e:
        print(f"\n❌ Error: {e}")

if __name__ == "__main__":
    main()