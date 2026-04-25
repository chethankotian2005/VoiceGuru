import sys
import codecs

chat_path = r'D:\VoiceGuru\frontend\voiceguru_app\lib\screens\chat_screen.dart'
diag_path = r'D:\VoiceGuru\frontend\voiceguru_app\lib\widgets\diagram_widget.dart'

def fix_mojibake(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        print(f"Failed to read {filepath}: {e}")
        return
            
    replacements = {
        'ðŸ‘‹': '👋',
        'ðŸ“Š': '📊',
        'ðŸŽ¥': '🎥',
        'â˜€ï¸ ': '☀️ ',
        'ðŸŒ±': '🌱',
        'ðŸ °': '🐇',
        'ðŸ¦ ': '🦁',
        'â†“': '↓',
        'â†‘': '↑',
        'â†’': '→',
        'â–²': '▲',
        'â”€â”€â”€': '───' # comments
    }
    
    for k, v in replacements.items():
        content = content.replace(k, v)
        
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

fix_mojibake(chat_path)
fix_mojibake(diag_path)
print('Fixed mojibake')
