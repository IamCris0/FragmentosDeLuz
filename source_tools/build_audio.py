import math, wave, struct, random
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1] if Path(__file__).parent.name == 'source_tools' else Path(__file__).parent/'production'
OUT=ROOT/'godot/assets/audio'
OUT.mkdir(parents=True,exist_ok=True)
RATE=22050
rng=random.Random(491)


def write(name, values):
    peak=max(abs(x) for x in values) or 1
    values=[x/max(peak/0.86,1) for x in values]
    with wave.open(str(OUT/(name+'.wav')),'wb') as stream:
        stream.setnchannels(1);stream.setsampwidth(2);stream.setframerate(RATE)
        stream.writeframes(struct.pack('<'+'h'*len(values),*[int(x*32767) for x in values]))


def hz(midi):return 440*2**((midi-69)/12)


def tone(time,freq):
    return math.sin(math.tau*freq*time)+.25*math.sin(math.tau*freq*2*time)+.08*math.sin(math.tau*freq*3*time)


duration=48
song=[0.0]*(RATE*duration)
for bar,chord in enumerate([[50,57,62,65],[46,53,58,62],[53,60,65,69],[48,55,60,64]]*2):
    start=bar*6
    for tick in range(12):
        midi=chord[[0,2,1,3,2,1][tick%6]]+12
        offset=int((start+tick*.5)*RATE)
        for j in range(int(RATE*2.2)):
            t=j/RATE
            envelope=min(t/.015,1)*math.exp(-t*2.5)
            value=tone(t,hz(midi))*envelope*.11
            song[(offset+j)%len(song)]+=value
    for j in range(6*RATE):
        t=j/RATE
        envelope=math.sin(math.pi*t/6)**2
        value=sum(math.sin(math.tau*hz(m)*t) for m in chord)*.028*envelope
        song[(start*RATE+j)%len(song)]+=value
for i in range(len(song)):
    song[i]*=min(i/(RATE*.15),1,(len(song)-1-i)/(RATE*.15))
write('auralia_theme',song)

noise=[];filtered=0
for i in range(RATE*12):
    filtered=.985*filtered+.015*rng.uniform(-1,1)
    t=i/RATE
    noise.append(filtered*(.6+.2*math.sin(math.tau*t/12))*min(t/.2,1,(12-t)/.2))
write('wind',noise)
specs={'jump':([64,71],.25),'pickup':([81,88,93],.9),'rune':([74,81],.7),
       'wrong':([46,47],.45),'solved':([62,69,74,77,81],1.8), 'lever':([48,55],.2),
       'chest':([57,64,69],1.2),'portal':([50,57,62,65,69,74],2.5),
       'story':([74,81],.65),'respawn':([81,77,74,69],1.3)}
for name,(notes,length) in specs.items():
    data=[0.0]*int(RATE*length)
    for k,note in enumerate(notes):
        begin=k*length*.1
        for i in range(int(begin*RATE),len(data)):
            t=i/RATE-begin
            envelope=min(t/.02,1)*math.exp(-t*4/max(length,.2))
            data[i]+=tone(t,hz(note))*.16*envelope*min((length-i/RATE)/.04,1)
    write(name,data)
step=[]
for i in range(int(.17*RATE)):
    t=i/RATE
    step.append((rng.uniform(-1,1)*.6+math.sin(math.tau*110*t)*.3)*math.exp(-t*35)*min(t/.003,1))
write('step',step)
print('AUDIO_COMPLETE',len(list(OUT.glob('*.wav'))))
