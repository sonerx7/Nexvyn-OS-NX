"""Build a separate Nexvyn OS NRO with the TikTok app embedded; original source is never edited.

Usage: python TikTok.native/build.py [--source ../SnxOS-NX] [--prepare-only]
The current public SDK cannot play videos. This app uses internal C++ media APIs,
so an ordinary Lua/JS .nxvapp cannot provide the same behavior.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

APP=Path(__file__).resolve().parent
WORKSPACE=APP.parent
STAGE=WORKSPACE/'.local/tiktok-native-build'
OUT=WORKSPACE/'dist/tiktok'

def linked(src,dst):
    try: os.link(src,dst)
    except OSError: shutil.copy2(src,dst)
    return str(dst)

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source',type=Path,default=WORKSPACE.parent/'SnxOS-NX')
    p.add_argument('--prepare-only',action='store_true')
    args=p.parse_args(); src=args.source.resolve()
    if not (src/'source/core/media.h').is_file(): raise SystemExit('Native source tree not found')
    STAGE.mkdir(parents=True,exist_ok=True); OUT.mkdir(parents=True,exist_ok=True)
    # Copies preserve timestamps, allowing the existing build objects to be reused.
    for name in ['source','romfs','tools','data']:
        if (src/name).is_dir(): shutil.copytree(src/name,STAGE/name,dirs_exist_ok=True,ignore=shutil.ignore_patterns('__pycache__'))
    for name in ['Makefile','icon.jpg','LICENSE']:
        if (src/name).is_file(): shutil.copy2(src/name,STAGE/name)
    # Immutable dependency files are hardlinked. We call make directly, never the
    # dependency build scripts, so the reference libraries are never changed.
    if not (STAGE/'lib').exists():
        shutil.copytree(src/'lib',STAGE/'lib',copy_function=linked,
                        ignore=shutil.ignore_patterns('.git','__pycache__','*.pyc'))
    (STAGE/'build').mkdir(exist_ok=True)
    for item in (src/'build').iterdir():
        if item.is_file() and item.suffix in ['.o','.d','.h','.bin'] and not (STAGE/'build'/item.name).exists():
            shutil.copy2(item,STAGE/'build'/item.name)
    subprocess.run([sys.executable,str(APP/'prepare_assets.py')],check=True)
    shutil.copytree(APP/'source/apps',STAGE/'source/apps',dirs_exist_ok=True)
    shutil.copytree(APP/'bundle',STAGE/'romfs/Applications/tiktok.app',dirs_exist_ok=True)
    if args.prepare_only: print(STAGE); return
    # Reset a previous native-module build before producing the embedded variant.
    subprocess.run([sys.executable,str(STAGE/'tools/build_modules.py'),'prepare'],check=True)
    (STAGE/'NexvynOS.elf').unlink(missing_ok=True)
    bash=Path('C:/devkitPro/msys2/usr/bin/bash.exe')
    if not bash.exists(): raise SystemExit('devkitPro MSYS2 not found')
    def msys(path):
        path=str(path).replace('\\','/')
        return '/'+path[0].lower()+path[2:] if len(path)>1 and path[1]==':' else path
    # Paths are from resolved local directories; quote single quotes for POSIX shell.
    quoted="'"+msys(STAGE).replace("'","'\"'\"'")+"'"
    cmd='export DEVKITPRO=/opt/devkitpro; cd '+quoted+' && make -j8'
    with (OUT/'build.log').open('w',encoding='utf-8') as log:
        result=subprocess.run([str(bash),'-lc',cmd],stdout=log,stderr=subprocess.STDOUT)
    if result.returncode:
        print((OUT/'build.log').read_text(encoding='utf-8',errors='replace')[-12000:]); raise SystemExit(result.returncode)
    target=OUT/'NexvynOS-TikTok.nro'; shutil.copy2(STAGE/'NexvynOS.nro',target)
    data={'app':'TikTo-NX','version':'0.1.0','native_source':str(src),
          'native_source_commit':subprocess.check_output(['git','-C',str(src),'rev-parse','HEAD'],text=True).strip(),
          'artifact':target.name,'size':target.stat().st_size,'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),
          'device_verified':False,'live_login_verified':False}
    (OUT/'build.json').write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
    print(f'Built {target} ({target.stat().st_size:,} bytes)')

if __name__=='__main__': main()
