"""Compile and execute the real C++ parser with MSVC; no browser is used."""
from pathlib import Path
import subprocess
import re
import sys
import os
import shutil

ROOT=Path(__file__).resolve().parents[1]
APP=ROOT/'TikTok.native'
STAGE=ROOT/'.local/tiktok-native-build'
OUT=ROOT/'dist/tiktok/tests'
def main():
    OUT.mkdir(parents=True,exist_ok=True)
    source=STAGE/'source'
    compat=STAGE/'tools/tests/msvc_compat.h'
    args=['cl','/nologo','/std:c++17','/EHsc','/utf-8',f'/FI{compat}',f'/I{source / "apps"}',
          str(APP/'tests/parser_test.cpp'),str(source/'apps/tiktok_parse.cpp'),str(source/'core/json.cpp'),
          f'/Fe:{OUT / "parser_test.exe"}',f'/Fo:{OUT}/']
    vcvars=Path('C:/Program Files (x86)/Microsoft Visual Studio/2019/BuildTools/VC/Auxiliary/Build/vcvars64.bat')
    env=os.environ.copy()
    if vcvars.exists():
        result=subprocess.run(f'call "{vcvars}" >nul && set',shell=True,capture_output=True,check=True)
        for line in result.stdout.decode('mbcs',errors='replace').splitlines():
            if '=' in line and not line.startswith('='):
                key,value=line.split('=',1);env[key]=value
    subprocess.run(args,cwd=OUT,env=env,check=True)
    subprocess.run([str(OUT/'parser_test.exe'),*sys.argv[1:]],check=True)
    account_args=['cl','/nologo','/std:c++17','/EHsc','/utf-8',f'/FI{compat}',f'/I{APP / "tests/host"}',f'/I{source / "apps"}',
                  str(APP/'tests/account_test.cpp'),str(source/'apps/tiktok_account.cpp'),str(source/'apps/tiktok_parse.cpp'),str(source/'core/json.cpp'),
                  f'/Fe:{OUT / "account_test.exe"}',f'/Fo:{OUT}/']
    subprocess.run(account_args,cwd=OUT,env=env,check=True)
    subprocess.run([str(OUT/'account_test.exe')],check=True)
    import json
    lang=[json.loads((APP/'bundle/lang'/f'{code}.json').read_text(encoding='utf-8')) for code in ['tr','en']]
    keys=set(re.findall(r'L\("([a-z_]+)"\)',(APP/'source/apps/app_tiktok.cpp').read_text(encoding='utf-8')))
    assert set(lang[0])==set(lang[1]) and keys<=set(lang[0])
    print('PASS: native bundle translation keys')
if __name__=='__main__':main()
