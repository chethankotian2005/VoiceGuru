import sys

filepath = r'D:\VoiceGuru\frontend\voiceguru_app\lib\screens\onboarding_screen.dart'
try:
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
except:
    sys.exit(1)

content = content.replace(r"\'", "'")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print("done")
