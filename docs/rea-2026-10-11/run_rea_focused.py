"""Owned REA stdio session using already installed prerequisites. No config edits."""
import subprocess, os, json, sys
from pathlib import Path

out = Path(__file__).parent
env = os.environ.copy()
env['GHIDRA_INSTALL_DIR'] = 'C:/Users/12733/AppData/Local/Programs/Ghidra/ghidra_12.1.4_PUBLIC'
env['JAVA_HOME'] = 'C:/Users/12733/AppData/Local/Programs/Java/jdk-25.0.4.1+1'
node = 'C:/Users/12733/AppData/Local/Microsoft/WinGet/Packages/OpenJS.NodeJS.LTS_Microsoft.Winget.Source_8wekyb3d8bbwe/node-v24.20.0-win-x64/node.exe'
entry = 'C:/Users/12733/AppData/Local/Programs/REA/node_modules/rea-agents/scripts/rea.mjs'
counter = 0
with (out/'rea-run.stderr.txt').open('w', encoding='utf-8') as log:
    process = subprocess.Popen([node, entry, 'mcp'], env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=log, text=True, encoding='utf-8', creationflags=subprocess.CREATE_NO_WINDOW)
    def request(method, params):
        global counter
        counter += 1
        process.stdin.write(json.dumps(dict(jsonrpc='2.0', id=counter, method=method, params=params))+'\n')
        process.stdin.flush()
        while True:
            line = process.stdout.readline()
            if not line:
                raise RuntimeError('REA stopped; see rea-run.stderr.txt')
            message = json.loads(line)
            if message.get('id') == counter:
                if 'error' in message:
                    raise RuntimeError(message['error'])
                return message['result']
    def call(name, args):
        return request('tools/call', dict(name=name, arguments=args))
    try:
        request('initialize',dict(protocolVersion='2024-11-05',capabilities={},clientInfo=dict(name='rich6-readonly-research',version='1')))
        process.stdin.write(json.dumps(dict(jsonrpc='2.0',method='notifications/initialized'))+'\n'); process.stdin.flush()
        result = call('open_binary',dict(path='D:/Projects/reference/Rich6/rich6.exe',provider_id='ghidra'))
        (out/'rea-ghidra-open.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
        print('Opened original via installed Ghidra', flush=True)
        procedures = sys.argv[1:] or ['0x439bf0','0x431f50','0x4321b0','0x4323c0','0x41ee80','0x41f110','0x41e110','0x436230','0x4364a0','0x436810']
        for address in procedures:
            result = call('analyze_function',dict(procedure=address))
            file = out / ('rea-function-'+address+'.json')
            file.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
            if result.get('isError'):
                print(address,'ERROR',str(result)[:500],flush=True); continue
            record = result.get('structuredContent')
            if not record:
                record = json.loads(next(c['text'] for c in result['content'] if c['type']=='text'))
            evidence = record.get('result',record)
            code = evidence.get('normalized_result',{}).get('pseudocode')
            if code:
                (out/('rea-function-'+address+'.c')).write_text(code.replace('\r',''),encoding='utf-8')
            print(address,evidence.get('evidence_id'), 'pseudocode',bool(code),flush=True)
        call('export_evidence_bundle',dict(path=str((out/'rea-ghidra-evidence.json').resolve()),overwrite=True))
    finally:
        try: call('close_binary',{})
        finally:
            process.stdin.close()
            try: process.wait(timeout=20)
            except subprocess.TimeoutExpired: process.terminate()
