"""Build a real installable native .nxvapp and its ABI-matched NRO in the isolated stage.
Run build.py first. No reference source, Store, commit or remote is modified.
"""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
from build import STAGE,OUT

def main():
    if not (STAGE/'NexvynOS.elf').exists(): raise SystemExit('Run build.py first')
    config={'modules':[{'id':'tiktok','sources':['source/apps/app_tiktok.cpp','source/apps/tiktok_parse.cpp','source/apps/tiktok_account.cpp'],'permissions':['network']}]}
    (STAGE/'tools/modules.json').write_text(json.dumps(config,indent=2)+'\n',encoding='utf-8')
    tool=STAGE/'tools/build_modules.py'
    subprocess.run([sys.executable,str(tool),'prepare'],check=True)
    # The reused native-loader object was compiled without this stage's ABI salt.
    # Remove only that generated object; the original build is untouched.
    obj=(STAGE/'build/nxvmod.o').resolve()
    if STAGE.resolve() not in obj.parents: raise SystemExit('Object outside stage')
    obj.unlink(missing_ok=True)
    bash=Path('C:/devkitPro/msys2/usr/bin/bash.exe')
    stage='/'+str(STAGE)[0].lower()+str(STAGE).replace('\\','/')[2:]
    quoted="'"+stage.replace("'","'\"'\"'")+"'"
    with (OUT/'package-build.log').open('w',encoding='utf-8') as log:
        def make(args):
            result=subprocess.run([str(bash),'-lc','export DEVKITPRO=/opt/devkitpro; cd '+quoted+' && make -j8 '+args],stdout=log,stderr=subprocess.STDOUT)
            log.flush()
            if result.returncode: raise SystemExit((OUT/'package-build.log').read_text(encoding='utf-8',errors='replace')[-9000:])
        make('modules')
        subprocess.run([sys.executable,str(tool),'exports'],check=True)
        subprocess.run([sys.executable,str(tool),'romfs'],check=True)
        make('ROMFS=build/romfs')
    subprocess.run([sys.executable,str(tool),'package'],check=True)
    package=OUT/'TikTo-NX.nxvapp';nro=OUT/'NexvynOS-TikTo-NX.nro'
    shutil.copy2(STAGE/'build/modules/tiktok.nxvapp',package)
    shutil.copy2(STAGE/'NexvynOS.nro',nro)
    catalog=json.loads((STAGE/'build/modules/catalog.json').read_text(encoding='utf-8'))
    report={'app':'TikTo-NX','version':'0.1.0','abi':catalog['abi'],'artifacts':[],
            'device_verified':False,'live_login_verified':False}
    for file in [package,nro]: report['artifacts'].append({'file':file.name,'size':file.stat().st_size,'sha256':hashlib.sha256(file.read_bytes()).hexdigest()})
    (OUT/'package.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print('Native package and matching NRO ready:',catalog['abi'])
if __name__=='__main__':main()
