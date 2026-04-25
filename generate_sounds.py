import wave
import struct
import math
import os

def generate_tone(filename, freq, duration_ms, volume=0.5):
    sample_rate = 44100
    num_samples = int(sample_rate * (duration_ms / 1000.0))
    
    # Envelope to avoid clicking
    attack = int(sample_rate * 0.01)
    decay = int(sample_rate * 0.1)
    
    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        
        for i in range(num_samples):
            # Simple envelope
            env = 1.0
            if i < attack:
                env = i / attack
            elif i > num_samples - decay:
                env = (num_samples - i) / decay
                
            value = int(volume * env * 32767.0 * math.sin(2.0 * math.pi * freq * i / sample_rate))
            data = struct.pack('<h', value)
            wav_file.writeframesraw(data)

# pop: short low frequency
generate_tone('frontend/voiceguru_app/assets/sounds/pop.wav', 400, 100)
# chime: medium frequency
generate_tone('frontend/voiceguru_app/assets/sounds/chime.wav', 800, 300)
# levelup: arpeggio-like (just a longer higher tone for placeholder)
generate_tone('frontend/voiceguru_app/assets/sounds/levelup.wav', 1200, 600)

print("Generated wav files.")
