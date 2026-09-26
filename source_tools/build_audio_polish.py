import json
import wave
from pathlib import Path
import numpy as np

ROOT=Path(__file__).resolve().parents[1] if Path(__file__).parent.name == 'source_tools' else Path(__file__).parent/'production'
OUT=ROOT/'godot/assets/audio'
RATE=32000
rng=np.random.default_rng(7302)
metrics={}


def save(name, audio, loop=False):
    peak=float(np.max(np.abs(audio)))
    audio=audio/max(1.,peak/.72)
    pcm=(np.clip(audio,-.99,.99)*32767).astype('<i2')
    with wave.open(str(OUT/(name+'.wav')),'wb') as f:
        f.setnchannels(2 if audio.ndim==2 else 1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(pcm.tobytes())
    metrics[name]={'seconds':len(audio)/RATE,'peak_db':round(20*np.log10(max(np.max(np.abs(audio)),1e-8)),2),'loop_boundary_delta':float(np.max(np.abs(audio[0]-audio[-1]))) if loop else None}


def hz(n):return 440*2**((n-69)/12)


def add_wrap(dest, source, offset):
    indices=(np.arange(len(source))+int(offset*RATE))%len(dest)
    dest[indices]+=source


duration=64
count=duration*RATE
chords=[[50,57,62,65],[46,53,58,62],[53,60,65,69],[48,55,60,64],[50,57,62,69],[46,53,60,65],[55,62,67,70],[45,52,57,61]]
pad=np.zeros((count,2))
harp=np.zeros((count,2))
choir=np.zeros((count,2))
for bar,chord in enumerate(chords):
    t=np.arange(10*RATE)/RATE
    envelope=np.sin(np.pi*np.minimum(t/10,1))**2
    for note in chord:
        phase=rng.uniform(0,np.pi*2)
        f=hz(note)
        voice=np.column_stack([np.sin(2*np.pi*f*.999*t+phase),np.sin(2*np.pi*f*1.001*t+phase)])
        voice+=.15*np.column_stack([np.sin(2*np.pi*f*2*t),np.sin(2*np.pi*f*2.001*t)])
        add_wrap(pad,voice*envelope[:,None]*.022,bar*8-1)
    for tick,note_index in enumerate([0,2,1,3,2,1]):
        note=chord[note_index]+12
        t=np.arange(4*RATE)/RATE
        attack=1-np.exp(-t*70)
        sound=(np.sin(2*np.pi*hz(note)*t)*np.exp(-t*1.8)+.28*np.sin(2*np.pi*hz(note)*2.003*t)*np.exp(-t*3.8))*attack*.09
        pan=.35+.3*(tick%3)/2
        note_audio=np.column_stack([sound*(1-pan),sound*pan])
        add_wrap(harp,note_audio,bar*8+tick*1.25)
        add_wrap(harp,note_audio[:,::-1]*.27,bar*8+tick*1.25+.42)
    t=np.arange(8*RATE)/RATE
    for note in chord[1:]:
        f=hz(note+12)
        tone=np.sin(2*np.pi*f*t+0.015*np.sin(2*np.pi*4.2*t))
        envelope=np.sin(np.pi*t/8)**3
        add_wrap(choir,np.column_stack([tone,np.sin(2*np.pi*f*1.0003*t)])*envelope[:,None]*.012,bar*8)
save('music_exploration',pad+harp,True)
save('music_garden',pad*.8+harp*.45+choir,True)
save('music_sanctuary',pad+harp*.5+choir*1.6,True)

# Periodic noise in the frequency domain keeps wind and water loops continuous.
def ambience(name, seconds, power, level):
    n=int(RATE*seconds)
    frequency=np.fft.rfftfreq(n,1/RATE)
    spectrum=(rng.normal(size=len(frequency))+1j*rng.normal(size=len(frequency)))
    spectrum*=np.maximum(frequency,30)**(-power)*np.exp(-frequency/6500)
    spectrum[frequency<35]=0
    samples=np.fft.irfft(spectrum,n=n)
    samples/=max(np.max(np.abs(samples)),1e-6)
    t=np.arange(n)/RATE
    samples*=level*(.8+.2*np.sin(2*np.pi*t/seconds))
    save(name,np.column_stack([samples,np.roll(samples,int(.09*RATE))]),True)
ambience('wind_soft',16,1.2,.28)
ambience('waterfall',16,.35,.4)
ambience('crystal_hum',12,1.7,.12)
for i in range(4):
    t=np.arange(int(.22*RATE))/RATE
    noise=rng.normal(size=len(t))
    noise=np.convolve(noise,np.ones(7)/7,mode='same')
    sole=np.sin(2*np.pi*(86+i*7)*t)*np.exp(-t*36)
    scrape=noise*np.exp(-t*21)*.32
    save('step_%d'%i,(sole*.18+scrape)*(1-np.exp(-t*600)))
t=np.arange(int(.45*RATE))/RATE
save('land',(.28*np.sin(2*np.pi*66*t)+rng.normal(size=len(t))*.13)*np.exp(-t*18)*(1-np.exp(-t*450)))
save('lever',(np.sin(2*np.pi*(110*t+60*t*t))*.06+rng.normal(size=len(t))*.08)*np.exp(-t*10)*(1-np.exp(-t*300)))
t=np.arange(int(.62*RATE))/RATE
rise=np.sin(2*np.pi*(180+520*t)*t)*np.exp(-t*3.4)
spark=np.sin(2*np.pi*hz(84)*t)*np.exp(-t*5.8)
save('pulse',np.column_stack([rise*.18+spark*.12,np.roll(rise,int(.014*RATE))*.18+spark*.10])*(1-np.exp(-t*90))[:,None])
t=np.arange(int(.35*RATE))/RATE
save('hit',(np.sin(2*np.pi*(92-45*t)*t)*.18+rng.normal(size=len(t))*.075)*np.exp(-t*9)*(1-np.exp(-t*260)))
t=np.arange(int(.48*RATE))/RATE
crack=np.sign(np.sin(2*np.pi*380*t))*np.exp(-t*8)*.08
glint=np.sin(2*np.pi*(hz(91)+140*t)*t)*np.exp(-t*6)*.16
save('enemy_hit',np.column_stack([crack+glint,np.roll(crack,int(.02*RATE))+glint*.8]))
t=np.arange(int(.85*RATE))/RATE
save('enemy_alert',np.column_stack([np.sin(2*np.pi*(hz(55)+12*np.sin(2*np.pi*4*t))*t),np.sin(2*np.pi*(hz(56)+8*np.sin(2*np.pi*4.3*t))*t)])*.07*np.exp(-t*1.4)[:,None])
(OUT/'audio_metrics.json').write_text(json.dumps(metrics,indent=2),encoding='utf8')
print('AUDIO_POLISH_COMPLETE',metrics)
