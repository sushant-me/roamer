import subprocess
FONT="/usr/share/fonts/Adwaita/AdwaitaSans-Regular.ttf"
scenes=["01_find_top","03_record_top","04_record_ledger","05_record_coverage","06_gap_chart","09_brief","10_method"]
D=4.1; F=0.4; TITLE=1.6; END=2.2
cmd=["ffmpeg","-y","-v","error","-f","lavfi","-i",f"color=c=0x0B1B3A:s=1280x720:d={TITLE}"]
for s in scenes: cmd += ["-loop","1","-t",str(D),"-i",f"/tmp/scenes/{s}.png"]
cmd += ["-f","lavfi","-i",f"color=c=0x0B1B3A:s=1280x720:d={END}"]
fc=[f"[0:v]drawtext=fontfile={FONT}:text='ROAMER':fontcolor=0xFFD200:fontsize=104:x=(w-text_w)/2:y=235,"
    f"drawtext=fontfile={FONT}:text='Find the Moon on Earth. Prove it with data.':fontcolor=0xE8EEFC:fontsize=34:x=(w-text_w)/2:y=365,"
    f"drawtext=fontfile={FONT}:text='NASA Space Apps 2026  ·  Bhaktapur':fontcolor=0x9FB0D0:fontsize=22:x=(w-text_w)/2:y=425,fps=30,settb=1/30,format=yuv420p[v0]"]
n=len(scenes)
for i in range(1,n+1):
    fc.append(f"[{i}:v]scale=1408:792,zoompan=z='1+0.055*on/123':d=1:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s=1280x720:fps=30,settb=1/30,format=yuv420p[v{i}]")
fc.append(f"[{n+1}:v]drawtext=fontfile={FONT}:text='ROAMER':fontcolor=0xFFD200:fontsize=92:x=(w-text_w)/2:y=250,"
          f"drawtext=fontfile={FONT}:text='sushant-me.github.io/roamer':fontcolor=0xE8EEFC:fontsize=30:x=(w-text_w)/2:y=390,"
          f"drawtext=fontfile={FONT}:text='Source + APK — github.com/sushant-me/roamer':fontcolor=0x9FB0D0:fontsize=21:x=(w-text_w)/2:y=440,"
          f"drawtext=fontfile={FONT}:text='A shortlist with its evidence attached.':fontcolor=0x9FB0D0:fontsize=24:x=(w-text_w)/2:y=490,fps=30,settb=1/30,format=yuv420p[vend]")
offs=[]
prev=0.0; dur=TITLE
for i in range(1,n+1):
    off=prev+dur-F; offs.append(round(off,2)); prev=off; dur=D
off=prev+dur-F; offs.append(round(off,2))
prev="v0"
for i in range(1,n+1):
    fc.append(f"[{prev}][v{i}]xfade=transition=fade:duration={F}:offset={offs[i-1]}[x{i}]"); prev=f"x{i}"
fc.append(f"[{prev}][vend]xfade=transition=fade:duration={F}:offset={offs[-1]}[xe]")
total=round(offs[-1]+END,2)
caps=[(0,4.6,"Name a place on Earth"),(4.6,9,"A case file, not a score"),(9,13.4,"Where the analogy breaks, quantified"),
      (13.4,17.8,"Provenance on every number"),(17.8,22.2,"Ranked by what nobody has studied"),
      (22.2,26.6,"A field brief from real data"),(26.6,29.3,"Find the Moon on Earth. Prove it with data.")]
filt=[f"[xe]drawtext=fontfile={FONT}:text='':x=0:y=0"]
for a,b,t in caps:
    filt.append(f"drawtext=fontfile={FONT}:text='{t}':fontcolor=white:fontsize=38:box=1:boxcolor=0x0B1B3A@0.72:boxborderw=16:x=(w-text_w)/2:y=h-120:enable='between(t,{a},{b})'")
filt.append("format=yuv420p[vo]")
fc.append(",".join(filt))
cmd += ["-filter_complex",";".join(fc),"-map","[vo]","-t",str(total),"-r","30","-c:v","libx264","-pix_fmt","yuv420p","-movflags","+faststart","docs/video/roamer_demo_30s.mp4"]
subprocess.run(cmd,check=True); print("built",total)
