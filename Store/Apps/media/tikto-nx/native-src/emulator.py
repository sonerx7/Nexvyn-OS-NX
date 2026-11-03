"""Prepare an isolated Ryujinx profile and launch the built native app.
Only system firmware/key files and emulator configuration are copied; user SD
card contents, accounts and Nexvyn settings stay outside this profile.
"""
from pathlib import Path
import os
import shutil
import subprocess
import argparse
import json

WORKSPACE=Path(__file__).resolve().parents[1]
PROFILE=WORKSPACE/'.local/tiktok-emulator'
def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--script',type=Path)
    parser.add_argument('--module',action='store_true')
    args=parser.parse_args()
    source=Path(os.environ['APPDATA'])/'Ryujinx'
    PROFILE.mkdir(parents=True,exist_ok=True)
    for name in ['system','bis/system/Contents/registered']:
        if (source/name).exists() and not (PROFILE/name).exists(): shutil.copytree(source/name,PROFILE/name)
    if not (PROFILE/'Config.json').exists(): shutil.copy2(source/'Config.json',PROFILE/'Config.json')
    config=json.loads((PROFILE/'Config.json').read_text(encoding='utf-8-sig'))
    config['enable_internet_access']=True
    (PROFILE/'Config.json').write_text(json.dumps(config,ensure_ascii=False,indent=2),encoding='utf-8')
    sd=PROFILE/'sdcard/NexvynOS'; sd.mkdir(parents=True,exist_ok=True)
    settings_path=sd/'System/Config/settings.json'
    if settings_path.exists():
        settings=json.loads(settings_path.read_text(encoding='utf-8-sig'))
        settings.setdefault('system',{})['reopenWindows']=False
        settings.setdefault('session',{})['windows']=[]
        settings.setdefault('privacy',{})['telemetry']=False
        settings.setdefault('updates',{})['autoCheck']=False
        if args.module:
            trusted=settings.setdefault('apps',{}).setdefault('trustedNative',[])
            if 'tiktok' not in trusted: trusted.append('tiktok')
        settings_path.write_text(json.dumps(settings,ensure_ascii=False,indent=2),encoding='utf-8')
    if args.module:
        shutil.copytree(WORKSPACE/'.local/tiktok-native-build/build/modules/tiktok',sd/'Applications/TikTo-NX.nxvapp',dirs_exist_ok=True)
    script=args.script.read_text(encoding='utf-8') if args.script else 'wait 2\nsetup tr\nwait 2\ncloseall\nlaunch tiktok\nwait 3\nwinframe\nshot tiktok-home\n'
    (sd/'autorun.txt').write_text(script,encoding='utf-8')
    original=Path('C:/Users/soned/OneDrive/Masaüstü/ryujinx')
    runtime=WORKSPACE/'.local/tiktok-emulator-runtime';runtime.mkdir(exist_ok=True)
    # Separate process name prevents unrelated Ryujinx test sessions interfering.
    for file in original.iterdir():
        if file.is_file():
            target=runtime/('TikTokPreview.exe' if file.name=='Ryujinx.exe' else file.name)
            if not target.exists(): shutil.copy2(file,target)
    exe=runtime/'TikTokPreview.exe'
    nro=WORKSPACE/('dist/tiktok/NexvynOS-TikTo-NX.nro' if args.module else 'dist/tiktok/NexvynOS-TikTok.nro')
    log=(WORKSPACE/'dist/tiktok/emulator.log').open('w',encoding='utf-8')
    startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow=7 # SW_SHOWMINNOACTIVE: no desktop activation or input injection
    proc=subprocess.Popen([str(exe),'--root-data-dir',str(PROFILE),str(nro)],stdout=log,stderr=subprocess.STDOUT,
                          startupinfo=startup,creationflags=subprocess.CREATE_NO_WINDOW)
    (WORKSPACE/'dist/tiktok/emulator.pid').write_text(str(proc.pid),encoding='ascii')
    print('Isolated emulator PID',proc.pid)
if __name__=='__main__':main()
