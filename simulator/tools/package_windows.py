"""Package the already-exported Godot Windows app. No third-party Python packages."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

root = Path(__file__).resolve().parents[1]
source = root / 'source/fpv-trainer'
parser = argparse.ArgumentParser()
parser.add_argument('--output', default=str(root / 'FPVTrainer-Windows-Prototype.zip'))
args = parser.parse_args()
output = Path(args.output)
output.parent.mkdir(parents=True, exist_ok=True)
files = {
    'AlJehadFPV.exe': source / 'build/al-jehad-windows/AlJehadFPV.exe',
    'AlJehadFPV.pck': source / 'build/al-jehad-windows/AlJehadFPV.pck',
    'course.json': source / 'data/course.json',
    'GUIDE.md': root / 'README.md',
    'REMOTE-SETUP.txt': root / 'REMOTE-SETUP.txt',
    'GOGGLES-SETUP.txt': root / 'GOGGLES-SETUP.txt',
    'EDITING-GUIDE.md': root / 'EDITING-GUIDE.md',
    'RADIO-TEST.html': root / 'RADIO-TEST.html',
    'GODOT-LICENSE.txt': source / 'assets/GODOT-LICENSE.txt',
    'FONT-LICENSE.txt': source / 'assets/FONT-LICENSE.txt',
}
data = {name: path.read_bytes() for name, path in files.items()}
data['START-HERE.txt'] = b'''AL JEHAD FPV - VERSION 0.8.2
Extract the whole folder and open AlJehadFPV.exe.
Ask the owner for the one-time activation key for this PC/account.
Choose Easy - Basic Guided for your first flight.
F11 toggles fullscreen. V toggles attitude. R restarts. Esc opens menu.
Read EDITING-GUIDE.md to learn how to change and rebuild the source.
No Internet, VS Code, SQL or Godot installation needed to PLAY this export.
'''
info = {'version': '0.8.2', 'engine': 'Godot 4.6.3', 'platform': 'Windows x86-64',
        'sha256': {n: hashlib.sha256(v).hexdigest() for n, v in data.items()}}
data['build-info.json'] = json.dumps(info, indent=2).encode()
with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for name, content in data.items():
        archive.writestr('AL-JEHAD-FPV/' + name, content)
with zipfile.ZipFile(output) as archive:
    assert archive.testzip() is None
output.with_suffix('.zip.sha256').write_text(hashlib.sha256(output.read_bytes()).hexdigest() + '  ' + output.name + '\n')
print(f'Verified package: {output} ({output.stat().st_size / 1048576:.1f} MiB)')
