import subprocess, os
FONT="/usr/share/fonts/Adwaita/AdwaitaSans-Regular.ttf"
scenes=["01_find_top","03_record_top","04_record_ledger","05_record_coverage","06_gap_chart","09_brief","10_method"]
inp=[]
for s in scenes:
    inp += ["-loop","1","-t","4.4","-i",f"/tmp/scenes/{s}.png"]
title = ["-f","lavfi","-i","color=c=0x0B1B3A:s=1280x720:d=1.6"]
# inputs order: title first then scenes
cmd=["ffmpeg","-y","-v","error"]+title
for s in scenes: cmd += ["-loop","1","-t","4.4","-i",f"/tmp/scenes/{s}.png"]
fc=[
 f"[0:v]drawtext=fontfile={FONT}:text='ROAMER':fontcolor=0xFFD200:fontsize=104:x=(w-text_w)/2:y=235,"
 f"drawtext=fontfile={FONT}:text='Find the Moon on Earth. Prove it with data.':fontcolor=0xE8EEFC:fontsize=34:x=(w-text_w)/2:y=365,"
 f"drawtext=fontfile={FONT}:text='NASA Space Apps 2026  ·  Bhaktapur':fontcolor=0x9FB0D0:fontsize=22:x=(w-text_w)/2:y=425,"
 f"format=yuv420p[v0]"
]
for i in range(1,8):
    fc.append(f"[{i}:v]scale=1280:720,format=yuv420p[v{i}]")
offs=[1.2,5.2,9.2,13.2,17.2,21.2,25.2]
prev="v0"
for i in range(1,8):
    out=f"x{i}"
    fc.append(f"[{prev}][v{i}]xfade=transition=fade:duration=0.4:offset={offs[i-1]}[{out}]")
    prev=out
caps=[(0,5,"Name a place on Earth"),(5,9.5,"A case file, not a score"),(9.5,14,"Where the analogy breaks, quantified"),
      (14,18.5,"Provenance on every number"),(18.5,23,"Ranked by what nobody has studied"),(23,27,"A field brief from real data"),
      (27,29.6,"Find the Moon on Earth. Prove it with data.")]
filt=[f"[{prev}]drawtext=fontfile={FONT}:text='':x=0:y=0"]
for a,b,t in caps:
    filt.append(f"drawtext=fontfile={FONT}:text='{t}':fontcolor=white:fontsize=38:box=1:boxcolor=0x0B1B3A@0.72:boxborderw=16:x=(w-text_w)/2:y=h-120:enable='between(t,{a},{b})'")
filt.append("format=yuv420p[vo]")
fc.append(",".join(filt))
cmd += ["-filter_complex",";".join(fc),"-map","[vo]","-t","29.6","-r","30","-c:v","libx264","-pix_fmt","yuv420p","-movflags","+faststart","docs/video/roamer_demo_30s.mp4"]
subprocess.run(cmd,check=True)
print("built")
