import sys
import datetime

def create_prompt():
    print("--- VIDEO QUIZ GENERATOR (WITH TIMESTAMP) ---\n")
    
    # 1. Collect Inputs
    try:
        target_lang = input("1. Enter Target Language (Learning) [e.g., Spanish]: ").strip()
        native_lang = input("2. Enter Native Language (User Speaks) [e.g., English]: ").strip()
        topic = input("3. Enter Topic/Unit [e.g., ordering coffee]: ").strip()
        level = input("4. Enter Proficiency Level [e.g., A1]: ").strip()
        count = input("5. Enter Question Count [e.g., 5]: ").strip()
        
        print("\n(Optional) Paste specific vocabulary words separated by commas.")
        vocab_input = input("6. Context/Vocab List [Press Enter to skip]: ").strip()
        
        vocab_list = vocab_input if vocab_input else "General vocabulary appropriate for this level."

    except KeyboardInterrupt:
        print("\n\nExited by user.")
        sys.exit()

    # Get current time for the prompt example
    current_iso = datetime.datetime.utcnow().isoformat() + "Z"

    # 2. Construct the Prompt with FIXED Timestamp Logic + CreatedAt
    
    full_prompt = f"""**ROLE:**
You are an advanced Content Generator for a video-based language learning app.
Your Output must be RAW JSON. Do not write explanations. Do not use markdown blocks.

**PARAMETERS:**
Target Language: {target_lang}
Native Language: {native_lang}
Topic: {topic}
Level: {level}
Question Count: {count}

**INSTRUCTIONS:**
1. Generate {count} quiz questions based on the Topic.
2. **VIDEO CONTEXT**: Identify a real YouTube video (vlog, TedTalk, news, or movie clip) where this sentence is naturally spoken.
3. **TIMESTAMPS**: You must estimate the `videoStart` and `videoEnd` accurately.
4. **TIMESTAMP**: Include a "createdAt" field in every object with the current UTC timestamp: {current_iso}

**CRITICAL RULES FOR 'options' ARRAY:**
1. The 'options' array is for a drag-and-drop sentence builder.
2. Take the 'correctAnswer'. Split it into words.
3. Add 3-5 "Distractor" words (grammatically plausible but wrong).
4. Combine and SHUFFLE the list.
5. If type is "native_to_target", 'options' are in {target_lang}.
6. If type is "target_to_native", 'options' are in {native_lang}.

**TIMESTAMP ACCURACY RULES (VERY IMPORTANT):**
1. **Format**: Use Floating Point Seconds (e.g., 90.5).
2. **Start Time**: When the first word is spoken.
3. **End Time Calculation**: 
   - Estimate when the sentence finishes.
   - **ADD 1.5 SECONDS BUFFER**: You MUST add +1.5 seconds to your calculated end time. It is better to have a slightly longer clip than to cut off the audio.
4. **Verification**: Ensure (`videoEnd` - `videoStart`) is NOT less than 3.0 seconds.

**OUTPUT JSON STRUCTURE:**
[
  {{
    "id": "unique_id_1",
    "createdAt": "{current_iso}",
    "type": "target_to_native", 
    "targetSentence": "Sentence in {target_lang} as heard in the video",
    "correctAnswer": "Translation in {native_lang}",
    "options": ["word", "word", "distractor", "distractor"],
    "videoUrl": "https://www.youtube.com/watch?v=VIDEO_ID",
    "videoStart": 12.0,
    "videoEnd": 16.5
  }}
]

**CONTEXT (Vocabulary to use):**
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