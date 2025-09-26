# 1) Create a virtualenv (optional but recommended)
python -m venv venv
source venv/bin/activate   # on Windows: venv\Scripts\activate

# 2) Install system ffmpeg if you don't have it yet
# macOS: brew install ffmpeg
sudo apt install ffmpeg   # Ubuntu/Debian
# Windows (Chocolatey): choco install ffmpeg

# 3) Install Python deps
pip install -r requirements.txt

# 4) Run: points to your audio/video file and outputs an MP3
python voiceover.py --input audio-only.mp4 --out voiceover.mp3 --accent uk --speed 1.0
