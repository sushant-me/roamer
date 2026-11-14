import subprocess, os
FONT="/usr/share/fonts/Adwaita/AdwaitaSans-Regular.ttf"
scenes=["01_find_top","11_coord","03_record_top","04_record_ledger","05_record_coverage","06_gap_chart","09_brief"]
TMP="/tmp/vclip4"; os.makedirs(TMP, exist_ok=True)
def run(cmd): subprocess.run(cmd,check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
run(["ffmpeg","-y","-v","error","-f","lavfi","-i","color=c=0x0B1B3A:s=1280x720:d=1.6","-vf",
 f"drawtext=fontfile={FONT}:text='ROAMER':fontcolor=0xFFD200:fontsize=104:x=(w-text_w)/2:y=235,"
 f"drawtext=fontfile={FONT}:text='Find the Moon on Earth. Prove it with data.':fontcolor=0xE8EEFC:fontsize=34:x=(w-text_w)/2:y=365,"
 f"drawtext=fontfile={FONT}:text='NASA Space Apps 2026  ·  Bhaktapur':fontcolor=0x9FB0D0:fontsize=22:x=(w-text_w)/2:y=425,"
 f"fade=t=in:st=0:d=0.4,format=yuv420p","-t","1.6","-r","30","-c:v","libx264","-pix_fmt","yuv420p",f"{TMP}/00_title.mp4"])
for i,s in enumerate(scenes,1):
    run(["ffmpeg","-y","-v","error","-loop","1","-t","3.6","-r","30","-i",f"/tmp/scenes/{s}.png","-vf",
     f"scale=1408:792,zoompan=z='1+0.02*on/108':d=1:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s=1280x720:fps=30,"
     f"fade=t=in:st=0:d=0.2,fade=t=out:st=3.4:d=0.2,format=yuv420p",
     "-t","3.6","-c:v","libx264","-pix_fmt","yuv420p",f"{TMP}/{i:02d}_{s}.mp4"])
run(["ffmpeg","-y","-v","error","-f","lavfi","-i","color=c=0x0B1B3A:s=1280x720:d=2.2","-vf",
 f"drawtext=fontfile={FONT}:text='ROAMER':fontcolor=0xFFD200:fontsize=92:x=(w-text_w)/2:y=250,"
 f"drawtext=fontfile={FONT}:text='sushant-me.github.io/roamer':fontcolor=0xE8EEFC:fontsize=30:x=(w-text_w)/2:y=390,"
 f"drawtext=fontfile={FONT}:text='Source + APK — github.com/sushant-me/roamer':fontcolor=0x9FB0D0:fontsize=21:x=(w-text_w)/2:y=440,"
 f"drawtext=fontfile={FONT}:text='A shortlist with its evidence attached.':fontcolor=0x9FB0D0:fontsize=24:x=(w-text_w)/2:y=490,"
 f"fade=t=in:st=0:d=0.3,format=yuv420p","-t","2.2","-r","30","-c:v","libx264","-pix_fmt","yuv420p",f"{TMP}/99_end.mp4"])
files=sorted(f for f in os.listdir(TMP) if f.endswith('.mp4'))
with open(f"{TMP}/list.txt","w") as fh:
    for f in files: fh.write(f"file '{TMP}/{f}'\n")
run(["ffmpeg","-y","-v","error","-f","concat","-safe","0","-i",f"{TMP}/list.txt","-c","copy",f"{TMP}/silent.mp4"])
run(["ffmpeg","-y","-v","error","-i",f"{TMP}/silent.mp4","-i","/tmp/vo2/audio.mp3","-filter_complex",
     "[1:a]atempo=0.95,adelay=400|400,apad=pad_dur=2[a]","-map","0:v","-map","[a]","-c:v","copy","-c:a","aac","-b:a","128k",
     "-t","29.0","-movflags","+faststart","docs/video/roamer_demo_30s.mp4"])
print("built")
