import firebase_admin
from firebase_admin import credentials, remote_config
import subprocess
import os

# --- 1. CONFIGURATION (Update these values) ---
NEW_LIVEKIT_URL = "wss://linguaflow-dev-coc00fgm.livekit.cloud"
NEW_LIVEKIT_API_KEY = "API6C5BUWD28NMh"
NEW_LIVEKIT_API_SECRET = "5SE5TVytIq8z6SwASEi26LPoUnB7wiEBz5eecAq16nt"
SERVICE_ACCOUNT_PATH = "../serviceAccountKey.json"

def update_firebase():
    print(f"--- Firebase Sync (SDK Version: {firebase_admin.__version__}) ---")
    try:
        # Initialize Firebase if not already initialized
        if not firebase_admin._apps:
            if not os.path.exists(SERVICE_ACCOUNT_PATH):
                print(f"❌ Error: {SERVICE_ACCOUNT_PATH} not found!")
                return
            cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
            firebase_admin.initialize_app(cred)
        
        print("Fetching Remote Config template...")
        # Accessing the template directly from the remote_config module
        template = remote_config.get_template()
        
        # Update or create the parameter
        # Note: Ensure 'livekit_url' matches the key used in your Flutter code
        template.parameters['livekit_url'] = remote_config.Parameter(
            default_value=NEW_LIVEKIT_URL,
            value_type=remote_config.ParameterValueType.STRING
        )
        
        print("Publishing template to Firebase...")
        remote_config.publish_template(template)
        print("✅ Firebase Remote Config updated successfully.")

    except AttributeError:
        print("❌ Firebase Error: 'get_template' not found. Please run: pip install --upgrade firebase-admin")
    except Exception as e:
        print(f"❌ Firebase Error: {e}")

def update_netlify():
    print("\n--- Netlify Sync ---")
    env_vars = {
        "LIVEKIT_API_KEY": NEW_LIVEKIT_API_KEY,
        "LIVEKIT_API_SECRET": NEW_LIVEKIT_API_SECRET,
        "LIVEKIT_URL": NEW_LIVEKIT_URL
    }
    
    try:
        for key, value in env_vars.items():
            print(f"Setting {key} (forcing overwrite)...")
            # Added --force to skip the (y/N) confirmation prompt
            subprocess.run(
                f'netlify env:set {key} "{value}" --force', 
                shell=True, 
                check=True
            )
        
        print("Triggering new Production Deploy...")
        subprocess.run("netlify deploy --prod", shell=True, check=True)
        print("✅ Netlify environment updated and deployment started.")

    except subprocess.CalledProcessError as e:
        print(f"❌ Netlify CLI Error: {e}")
        print("Tip: Ensure you have run 'netlify link' in this folder and are logged in.")
    except Exception as e:
        print(f"❌ General Error: {e}")

if __name__ == "__main__":
    # Safety check: Ensure we aren't using placeholder strings
    if "your_" in NEW_LIVEKIT_API_KEY:
        print("⚠️ Warning: You are using placeholder API keys. Please update the CONFIGURATION section.")
    
    update_firebase()
    update_netlify()
    
    print("\n🚀 All systems synced! Wait ~1 min for Netlify to finish building before testing your app.")