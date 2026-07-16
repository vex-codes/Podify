import wave
import struct
import random
import math

def generate_tick(filename="tick.wav"):
    sample_rate = 44100
    duration = 0.015 # 15ms
    num_samples = int(sample_rate * duration)
    
    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        
        for i in range(num_samples):
            # Mechanical tick: quick burst of noise mixed with a low frequency thump, decaying fast
            t = i / sample_rate
            decay = math.exp(-t * 400) # Fast decay
            
            # Mix a 100Hz thump with some noise for texture
            thump = math.sin(2 * math.pi * 150 * t)
            noise = random.uniform(-1.0, 1.0)
            
            sample = (thump * 0.4 + noise * 0.6) * decay
            
            # Scale to 16-bit integer
            int_sample = int(sample * 32767.0)
            # Clamp
            int_sample = max(-32768, min(32767, int_sample))
            
            wav_file.writeframes(struct.pack('<h', int_sample))

generate_tick("/Volumes/vex/VSCode/Podify/Podia/Resources/tick.wav")
