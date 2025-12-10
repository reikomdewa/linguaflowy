import sys
import datetime

def create_prompt():
    print("--- STANDARD TEXT LESSON GENERATOR (WITH TIMESTAMP) ---\n")
    
    # 1. Collect Inputs
    try:
        target_lang = input("1. Enter Target Language (Learning) [e.g., Spanish]: ").strip()
        native_lang = input("2. Enter Native Language (User Speaks) [e.g., English]: ").strip()
        topic = input("3. Enter Topic/Unit [e.g., Past Tense Verbs]: ").strip()
        level = input("4. Enter Proficiency Level [e.g., A2]: ").strip()
        count = input("5. Enter Question Count [e.g., 10]: ").strip()
        
        print("\n(Optional) Paste specific vocabulary words separated by commas.")
        vocab_input = input("6. Context/Vocab List [Press Enter to skip]: ").strip()
        
        vocab_list = vocab_input if vocab_input else "General vocabulary appropriate for this level."

    except KeyboardInterrupt:
        print("\n\nExited by user.")
        sys.exit()

    # Get current time for the prompt example, though Gemini will generate its own
    current_iso = datetime.datetime.utcnow().isoformat() + "Z"

    # 2. Construct the Prompt
    full_prompt = f"""**ROLE:**
You are a strict Data Generator for a language learning app.
Your Output must be RAW JSON. Do not write explanations. Do not use markdown blocks.

**PARAMETERS:**
Target Language: {target_lang}
Native Language: {native_lang}
Topic: {topic}
Proficiency Level: {level}
Question Count: {count}

**INSTRUCTIONS:**
1. Generate {count} quiz questions based on the Topic.
2. Mix the question types: 50% "target_to_native" and 50% "native_to_target".
3. Use natural sentences appropriate for the Level.
4. **TIMESTAMP**: Include a "createdAt" field in every object with the current UTC timestamp in ISO 8601 format (e.g., {current_iso}).

**CRITICAL RULES FOR 'options' ARRAY:**
1. The 'options' array is used for a drag-and-drop sentence builder.
2. Step A: Take the 'correctAnswer'. Split it into individual words.
3. Step B: Generate 3 to 5 "Distractor" words (wrong words that look grammatically plausible but are incorrect).
4. Step C: Combine the correct words and distractor words.
5. Step D: SHUFFLE the list completely.
6. LANGUAGE CHECK:
   - If type is "native_to_target", 'options' MUST be in {target_lang}.
   - If type is "target_to_native", 'options' MUST be in {native_lang}.

**OUTPUT JSON STRUCTURE:**
[
  {{
    "id": "unique_id_1",
    "createdAt": "{current_iso}",
    "type": "target_to_native", 
    "targetSentence": "Sentence in {target_lang}",
    "correctAnswer": "Sentence in {native_lang}",
    "options": ["word", "word", "word", "distractor", "distractor"]
  }}
]

**CONTEXT (Vocabulary to include):**
{vocab_list}

**GENERATE NOW:**"""

    # 3. Output
    print("\n" + "="*60)
    print("COPY THE TEXT BELOW INTO GEMINI:")
    print("="*60 + "\n")
    print(full_prompt)
    print("\n" + "="*60)

if __name__ == "__main__":
    create_prompt()