# English Voice-Over Generator (Female-style)

This toolkit transcribes your audio/video and produces a **smooth English MP3 narration** (female-style accent) using Whisper + gTTS.

## Files
- `voiceover.py` — main script
- `requirements.txt` — Python deps

## Prereqs
1. **ffmpeg** (required by pydub and Whisper).  
   - macOS: `brew install ffmpeg`
   - Ubuntu/Debian: `sudo apt install ffmpeg`
   - Windows (choco): `choco install ffmpeg`
2. **Python 3.9+**

## Install
```bash
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

> Tip: First run downloads Whisper model; it may take time depending on size.

## Usage
```bash
python voiceover.py --input "/path/to/20250925_165426.m4a" --out "voiceover.mp3" --accent uk --speed 1.0
```
- `--accent`: `uk` (default), `us`, `in`, `au`
- `--model`: `tiny`/`base`/`small`/`medium`/`large` (default: `small`)
- `--speed`: 1.0 is normal; e.g., 1.05 slightly faster

The script will:
1. Transcribe & translate to English (Whisper, offline).
2. Generate natural narration in a female-style accent (gTTS).
3. Save a final `voiceover.mp3`.

## Notes
- gTTS needs internet access; gender isn't explicitly controllable, but UK accent often yields a female-like voice.
- If you want fully offline TTS, consider `pyttsx3`, but quality varies by OS voices.
