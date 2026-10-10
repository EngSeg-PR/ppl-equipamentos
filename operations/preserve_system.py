"""Backup administrativo local. Nunca execute com saída dentro do repositório.
Credenciais somente no ambiente local; nunca no código ou na conversa.
"""
import argparse, hashlib, json, os, shutil, subprocess, sys, time
from datetime import datetime, timezone
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlparse

def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda:f.read(1024*1024),b''): h.update(chunk)
    return h.hexdigest()

def verify(folder):
    manifest=json.loads((folder/'manifest.json').read_text(encoding='utf-8'))
    if manifest.get('format')!='prs-system-preservation' or manifest.get('complete') is not True:
        raise ValueError('Pacote incompleto ou incompatível.')
    for item in manifest['files']:
        path=(folder/item['local']).resolve()
        if not path.is_relative_to(folder.resolve()) or not path.is_file(): raise ValueError('Arquivo ausente ou caminho inválido.')
        if path.stat().st_size!=item['size'] or sha(path)!=item['sha256']: raise ValueError('Integridade inválida: '+item['local'])
    return manifest

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--output',type=Path)
    parser.add_argument('--verify',type=Path)
    args=parser.parse_args()
    if args.verify:
        manifest=verify(args.verify.resolve());print('Verificação concluída:',len(manifest['files']),'arquivos íntegros.');return
    if not args.output: parser.error('Informe --output ou --verify.')
    repo=Path(__file__).resolve().parents[1];out=args.output.resolve()
    if out.is_relative_to(repo) or out==repo: raise ValueError('Guarde o backup fora do repositório para evitar publicação acidental.')
    if out.exists(): raise ValueError('Escolha uma pasta nova; backups anteriores não serão sobrescritos.')
    base=os.environ.get('PRS_SUPABASE_URL','').rstrip('/');key=os.environ.get('PRS_SUPABASE_SERVICE_KEY','')
    parsed=urlparse(base)
    if parsed.scheme!='https' or not parsed.hostname or parsed.path not in ('','/') or not key:
        raise ValueError('Configure PRS_SUPABASE_URL e PRS_SUPABASE_SERVICE_KEY no ambiente local seguro.')
    project=parsed.hostname.split('.')[0]
    linked=repo/'supabase/.temp/project-ref'
    if not linked.exists() or linked.read_text().strip()!=project: raise ValueError('Vincule a CLI Supabase ao projeto correto antes de executar o backup.')
    if not shutil.which('supabase') or not shutil.which('git'): raise ValueError('CLI Supabase e Git precisam estar instalados.')
    if subprocess.check_output(['git','status','--porcelain'],cwd=repo,text=True).strip():
        raise ValueError('Salve e versione as alterações do sistema antes do backup administrativo.')
    def api(path,data=None,binary=False):
        payload=None if data is None else json.dumps(data).encode()
        request=Request(base+path,data=payload,headers={'apikey':key,'Authorization':'Bearer '+key,'Content-Type':'application/json'})
        for attempt in range(3):
            try:
                with urlopen(request,timeout=60) as response: raw=response.read()
                return raw if binary else json.loads(raw)
            except HTTPError as e:
                if e.code not in (429,500,502,503,504) or attempt==2: raise RuntimeError('Falha no serviço de backup, HTTP '+str(e.code)) from None
            except URLError:
                if attempt==2: raise RuntimeError('Falha de conexão durante o backup.') from None
            time.sleep(2**attempt)
    out.mkdir(parents=True);marker=out/'INCOMPLETE.txt';marker.write_text('Backup em andamento. Não migrar usando este pacote.\n',encoding='utf-8')
    try:
        for name,extra in [('roles.sql',['--role-only']),('schema.sql',[]),('data.sql',['--data-only','--use-copy','--schema','public']),('auth-data.sql',['--data-only','--use-copy','--schema','auth']),('storage-data.sql',['--data-only','--use-copy','--schema','storage'])]:
            result=subprocess.run(['supabase','db','dump','--linked','--file',str(out/name),*extra],cwd=repo,capture_output=True)
            if result.returncode: raise RuntimeError('Dump do banco falhou. Consulte a CLI local; não há backup completo.')
        edge=out/'edge-functions';edge.mkdir();result=subprocess.run(['supabase','functions','download','ppl-api-','--project-ref',project],cwd=edge,capture_output=True)
        if result.returncode: raise RuntimeError('Não foi possível preservar a função implantada. Backup incompleto.')
        subprocess.run(['git','bundle','create',str(out/'repository.bundle'),'--all'],cwd=repo,check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip()
        paths=subprocess.check_output(['git','ls-files','-z'],cwd=repo).decode().split('\0')
        for name in filter(None,paths):
            src=(repo/name).resolve()
            if not src.is_relative_to(repo) or src.is_symlink() or not src.is_file(): raise ValueError('Arquivo de projeto inválido.')
            target=out/'site'/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,target)
        objects=[];buckets=api('/storage/v1/bucket')
        def walk(bucket,prefix=''):
            offset=0
            while True:
                rows=api('/storage/v1/object/list/'+quote(bucket,safe=''),{'prefix':prefix,'limit':100,'offset':offset,'sortBy':{'column':'name','order':'asc'}})
                for row in rows:
                    remote=prefix+row['name']
                    if row.get('id') is None: walk(bucket,remote+'/');continue
                    raw=api('/storage/v1/object/authenticated/'+quote(bucket,safe='')+'/'+quote(remote,safe='/'),binary=True)
                    local='objects/'+hashlib.sha256((bucket+'\0'+remote).encode()).hexdigest()+'.bin'
                    path=out/local;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(raw)
                    objects.append({'bucket':bucket,'path':remote,'local':local,'metadata':row.get('metadata',{})})
                if len(rows)<100: break
                offset+=100
        for bucket in buckets: walk(bucket['id'])
        manifest={'format':'prs-system-preservation','schema':1,'complete':True,'createdAt':datetime.now(timezone.utc).isoformat(),'project':project,'commit':commit,'buckets':buckets,'objects':objects,'files':[],'notice':'Contém dados pessoais e dados administrativos. Armazene protegido. Exportação requer janela sem alterações para consistência.'}
        for path in sorted(out.rglob('*')):
            if path.is_file() and path!=marker: manifest['files'].append({'local':path.relative_to(out).as_posix(),'size':path.stat().st_size,'sha256':sha(path)})
        (out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
        verify(out);marker.unlink();print('Pacote completo e verificado:',len(manifest['files']),'arquivos; objetos centrais:',len(objects))
    except Exception:
        marker.write_text('Backup incompleto. Preserve o projeto atual e repita em uma nova pasta.\n',encoding='utf-8');raise

if __name__=='__main__':
    try: main()
    except Exception as e: print('Preservação interrompida:',str(e),file=sys.stderr);sys.exit(1)
