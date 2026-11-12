"""Three actual Godot processes over ENet loopback; no mocked transport."""
from pathlib import Path
import json, os, socket, subprocess, tempfile, time
project = Path(__file__).resolve().parents[1]
with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
    sock.bind(('127.0.0.1', 0))
    port = str(sock.getsockname()[1])
processes = []
with tempfile.TemporaryDirectory(prefix='fpv-lan-network-') as temporary:
    try:
        for role, switch in [('host','--server'),('client1','--client1'),('client2','--client2')][:int(os.environ.get('FPV_TEST_PLAYERS','3'))]:
            Path('/tmp/al-jehad-lan-'+role+'.json').unlink(missing_ok=True)
            env = dict(os.environ, XDG_DATA_HOME=temporary+'/'+role, FPV_TEST_PORT=port)
            log = open(temporary+'/'+role+'.log','w+')
            process = subprocess.Popen(['godot','--headless','--path',str(project),'--script','res://tests/lan_process.gd','--',switch],env=env,stdout=log,stderr=subprocess.STDOUT)
            processes.append((role,process,log))
            if role=='host': time.sleep(0.6)
        for role,process,log in processes:
            code = process.wait(timeout=35)
            log.seek(0)
            output = log.read()
            print(output,flush=True)
            assert code==0 and 'PASS:' in output, role+' failed'
            result = json.loads(Path('/tmp/al-jehad-lan-'+role+'.json').read_text())
            if os.environ.get('FPV_TEST_MODE')=='disconnect':
                assert result.get('withdrawn') or (result['phase']=='finished' and result['history']>=1)
            else:
                assert result['leg']==(0 if os.environ.get('FPV_TEST_MODE')=='obstacle' else 3) and len(result['players'])==int(os.environ.get('FPV_TEST_PLAYERS','3')) and result['history']>=1
        print('PASS: real-process LAN '+os.environ.get('FPV_TEST_MODE','relay')+' integration and result agreement')
    finally:
        for _,process,log in processes:
            if process.poll() is None: process.terminate()
            process.wait(timeout=5)
            log.close()
