#!/usr/bin/env python3
"""
voiceover.py
-------------
Transcribe an audio/video file and generate a smooth, natural English voice-over (female-style) MP3.

Usage:
  python voiceover.py --input /path/to/your_audio_or_video.m4a --out voiceover.mp3 --accent uk --speed 1.0

Dependencies:
  - ffmpeg (system package)
  - Python packages in requirements.txt

Notes:
  - Uses OpenAI Whisper (CPU is fine; "small" model by default).
  - Uses gTTS for TTS (internet required) with UK/US/IN accents via tld.
  - Splits long text into chunks and stitches them with pydub.
"""

import argparse
import os
import re
import sys
import tempfile
from pathlib import Path

# --- Transcription (Whisper) ---
def transcribe_to_english(input_path: str, model_size: str = "small") -> str:
    try:
        import whisper
    except ImportError:
        print("ERROR: openai-whisper is not installed. Run: pip install openai-whisper", file=sys.stderr)
        sys.exit(1)

    print(f"[1/3] Loading Whisper model: {model_size} (this can take a bit on first run)...")
    model = whisper.load_model(model_size)
    print(f"[2/3] Transcribing & translating to English...")
    # task='translate' will translate non-English to English and leave English as-is
    result = model.transcribe(input_path, task='translate', verbose=False)
    text = (result.get("text") or "").strip()
    if not text:
        raise RuntimeError("Transcription produced empty text.")
    print(f"[2/3] Transcription complete. Characters: {len(text)}")
    return text

# --- Basic sentence chunking ---
def chunk_text(text: str, max_chars: int = 400) -> list[str]:
    # Split on sentence boundaries; then merge smaller parts up to max_chars
    import re
    sentences = re.split(r'(?<=[.!?])\s+', text.strip())
    chunks = []
    current = ""
    for s in sentences:
        if len(current) + len(s) + 1 <= max_chars:
            current = (current + " " + s).strip() if current else s
        else:
            if current:
                chunks.append(current)
            current = s
    if current:
        chunks.append(current)
    return chunks

# --- TTS with gTTS ---
def synthesize_tts(chunks: list[str], out_mp3: str, accent: str = "uk", speed: float = 1.0):
    try:
        from gtts import gTTS
        from pydub import AudioSegment
    except ImportError:
        print("ERROR: gTTS/pydub not installed. Run: pip install gTTS pydub", file=sys.stderr)
        sys.exit(1)

    # Map accent -> tld (influences accent; gender is not directly controllable but many 'UK' voices sound more female)
    tld_map = {
        "uk": "co.uk",
        "us": "com",
        "in": "co.in",
        "au": "com.au",
    }
    tld = tld_map.get(accent.lower(), "co.uk")

    print(f"[3/3] Generating MP3 with gTTS (accent={accent}, tld={tld}, speed={speed})...")
    segs = []
    with tempfile.TemporaryDirectory() as td:
        for i, chunk in enumerate(chunks, start=1):
            temp_mp3 = os.path.join(td, f"part_{i:03d}.mp3")
            tts = gTTS(chunk, lang="en", tld=tld)
            tts.save(temp_mp3)
            seg = AudioSegment.from_file(temp_mp3, format="mp3")
            # Adjust speed if requested (simple time-scale via frame_rate)
            if abs(speed - 1.0) > 1e-3:
                seg = seg._spawn(seg.raw_data, overrides={"frame_rate": int(seg.frame_rate * speed)}).set_frame_rate(seg.frame_rate)
            segs.append(seg)

        if not segs:
            raise RuntimeError("No audio segments were generated.")
        final = segs[0]
        for seg in segs[1:]:
            final += AudioSegment.silent(duration=150)  # small pause between chunks
            final += seg
        final.export(out_mp3, format="mp3")
    print(f"[DONE] Voice-over saved to: {out_mp3}")

def main():
    parser = argparse.ArgumentParser(description="Generate English voice-over MP3 from an audio/video file.")
    parser.add_argument("--input", "-i", required=True, help="Path to input audio/video (mp3, m4a, wav, mp4, etc.)")
    parser.add_argument("--out", "-o", default="voiceover.mp3", help="Output MP3 path (default: voiceover.mp3)")
    parser.add_argument("--model", default="small", help="Whisper model size: tiny/base/small/medium/large (default: small)")
    parser.add_argument("--accent", choices=["uk","us","in","au"], default="uk", help="Accent for female-style voice (default: uk)")
    parser.add_argument("--speed", type=float, default=1.0, help="Playback speed (1.0 = normal)")
    parser.add_argument("--max-chars", type=int, default=400, help="Max characters per TTS chunk (default: 400)")
    args = parser.parse_args()

    inp = Path(args.input)
    if not inp.exists():
        print(f"ERROR: input file not found: {inp}", file=sys.stderr)
        sys.exit(1)

    text = transcribe_to_english(str(inp), model_size=args.model)
    chunks = chunk_text(text, max_chars=args.max_chars)
    synthesize_tts(chunks, args.out, accent=args.accent, speed=args.speed)

if __name__ == "__main__":
    main()
