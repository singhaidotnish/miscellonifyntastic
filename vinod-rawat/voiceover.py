#!/usr/bin/env python3
"""
voiceover.py
-------------
Generate smooth, natural English voice-over (female-style) MP3.

Modes:
1) Audio/Video input (mp4, mp3, wav, m4a, etc.)
   -> Transcribe/translate with Whisper -> English text -> TTS -> MP3
2) Text input (.txt)
   -> Reads English script directly -> TTS -> MP3
"""

import argparse
import os
import sys
import tempfile
from pathlib import Path

def chunk_text(text: str, max_chars: int = 400) -> list[str]:
    import re
    sentences = re.split(r'(?<=[.!?])\s+', text.strip())
    chunks, current = [], ""
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

def synthesize_tts(chunks: list[str], out_mp3: str, accent: str = "uk", speed: float = 1.0):
    from gtts import gTTS
    from pydub import AudioSegment

    tld_map = {"uk": "co.uk", "us": "com", "in": "co.in", "au": "com.au"}
    tld = tld_map.get(accent.lower(), "co.uk")

    print(f"[TTS] Generating MP3 (accent={accent}, tld={tld}, speed={speed})...")
    segs = []
    with tempfile.TemporaryDirectory() as td:
        for i, chunk in enumerate(chunks, start=1):
            temp_mp3 = os.path.join(td, f"part_{i:03d}.mp3")
            tts = gTTS(chunk, lang="en", tld=tld)
            tts.save(temp_mp3)
            seg = AudioSegment.from_file(temp_mp3, format="mp3")
            if abs(speed - 1.0) > 1e-3:
                seg = seg._spawn(seg.raw_data, overrides={"frame_rate": int(seg.frame_rate * speed)}).set_frame_rate(seg.frame_rate)
            segs.append(seg)

        final = segs[0]
        for seg in segs[1:]:
            final += AudioSegment.silent(duration=150)
            final += seg
        final.export(out_mp3, format="mp3")
    print(f"[DONE] Saved: {out_mp3}")

def transcribe_audio(input_path: str, model_size: str = "small") -> str:
    import whisper
    print(f"[Whisper] Loading model: {model_size}")
    model = whisper.load_model(model_size)
    result = model.transcribe(input_path, task="translate", verbose=False)
    text = (result.get("text") or "").strip()
    if not text:
        raise RuntimeError("Transcription failed.")
    print(f"[Whisper] Got {len(text)} characters of English text")
    return text

def main():
    parser = argparse.ArgumentParser(description="Generate English voice-over MP3")
    parser.add_argument("--input", "-i", required=True, help="Input file (audio/video/text)")
    parser.add_argument("--out", "-o", default="voiceover.mp3", help="Output MP3 path")
    parser.add_argument("--model", default="small", help="Whisper model size (default: small)")
    parser.add_argument("--accent", choices=["uk","us","in","au"], default="uk", help="Accent for voice")
    parser.add_argument("--speed", type=float, default=1.0, help="Voice speed (default 1.0)")
    parser.add_argument("--max-chars", type=int, default=400, help="Max characters per TTS chunk")
    args = parser.parse_args()

    inp = Path(args.input)
    if not inp.exists():
        print(f"ERROR: File not found: {inp}", file=sys.stderr)
        sys.exit(1)

    # If input is text file, skip Whisper
    if inp.suffix.lower() == ".txt":
        print("[Mode] Text input detected")
        text = inp.read_text(encoding="utf-8")
    else:
        print("[Mode] Audio/Video input detected")
        text = transcribe_audio(str(inp), model_size=args.model)

    chunks = chunk_text(text, max_chars=args.max_chars)
    synthesize_tts(chunks, args.out, accent=args.accent, speed=args.speed)

if __name__ == "__main__":
    main()
