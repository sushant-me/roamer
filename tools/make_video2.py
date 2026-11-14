import subprocess, os
FONT="/usr/share/fonts/Adwaita/AdwaitaSans-Regular.ttf"
scenes=["01_find_top","03_record_top","04_record_ledger","05_record_coverage","06_gap_chart","09_brief","10_method"]
TMP="/tmp/vclip2"; os.makedirs(TMP, exist_ok=True)
def run(cmd): subprocess.run(cmd,check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
# title
run(["ffmpeg","-y","-v","error","-f","lavfi","-i","color=c=0x0B1B3A:s=1280x720:d=1.6","-vf",
 f"drawtext=fontfile={FONT}:text='ROAMER':fontcolor=0xFFD200:fontsize=104:x=(w-text_w)/2:y=235,"
 f"drawtext=fontfile={FONT}:text='Find the Moon on Earth. Prove it with data.':fontcolor=0xE8EEFC:fontsize=34:x=(w-text_w)/2:y=365,"
 f"drawtext=fontfile={FONT}:text='NASA Space Apps 2026  ·  Bhaktapur':fontcolor=0x9FB0D0:fontsize=22:x=(w-text_w)/2:y=425,format=yuv420p",
 "-t","1.6","-r","30","-c:v","libx264","-pix_fmt","yuv420p",f"{TMP}/00_title.mp4"])
for i,s in enumerate(scenes,1):
    run(["ffmpeg","-y","-v","error","-loop","1","-t","3.6","-r","30","-i",f"/tmp/scenes/{s}.png","-vf",
     f"scale=1408:792,zoompan=z='1+0.02*on/108':d=1:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s=1280x720:fps=30,format=yuv420p",
     "-t","3.6","-c:v","libx264","-pix_fmt","yuv420p",f"{TMP}/{i:02d}_{s}.mp4"])
# end card
run(["ffmpeg","-y","-v","error","-f","lavfi","-i","color=c=0x0B1B3A:s=1280x720:d=2.2","-vf",
 f"drawtext=fontfile={FONT}:text='ROAMER':fontcolor=0xFFD200:fontsize=92:x=(w-text_w)/2:y=250,"
 f"drawtext=fontfile={FONT}:text='sushant-me.github.io/roamer':fontcolor=0xE8EEFC:fontsize=30:x=(w-text_w)/2:y=390,"
 f"drawtext=fontfile={FONT}:text='Source + APK — github.com/sushant-me/roamer':fontcolor=0x9FB0D0:fontsize=21:x=(w-text_w)/2:y=440,"
 f"drawtext=fontfile={FONT}:text='A shortlist with its evidence attached.':fontcolor=0x9FB0D0:fontsize=24:x=(w-text_w)/2:y=490,format=yuv420p",
 "-t","2.2","-r","30","-c:v","libx264","-pix_fmt","yuv420p",f"{TMP}/99_end.mp4"])
files=sorted(os.listdir(TMP))
files=[f for f in files if f.endswith('.mp4')]
with open(f"{TMP}/list.txt","w") as fh:
    for f in files: fh.write(f"file '{TMP}/{f}'\n")
run(["ffmpeg","-y","-v","error","-f","concat","-safe","0","-i",f"{TMP}/list.txt","-c","copy",f"{TMP}/concat.mp4"])
caps=[(1.9,5.1,"Name a place on Earth"),(5.3,8.7,"A case file, not a score"),(8.9,12.3,"Where the analogy breaks, quantified"),
      (12.5,15.9,"Provenance on every number"),(16.1,19.5,"Ranked by what nobody has studied"),
      (19.7,23.1,"A field brief from real data"),(23.3,26.6,"Every number traceable")]
vf=[]
for a,b,t in caps:
    vf.append(f"drawtext=fontfile={FONT}:text='{t}':fontcolor=white:fontsize=38:box=1:boxcolor=0x0B1B3A@0.72:boxborderw=16:x=(w-text_w)/2:y=h-120:enable='between(t,{a},{b})'")
vf.append("format=yuv420p")
run(["ffmpeg","-y","-v","error","-i",f"{TMP}/concat.mp4","-vf",",".join(vf),"-t","29.0","-r","30","-c:v","libx264","-pix_fmt","yuv420p","-movflags","+faststart","docs/video/roamer_demo_30s.mp4"])
print("built")
