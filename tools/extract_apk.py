"""Recover the serialized Unity scenes and managed code payload without modifying the APK."""
import json
import pathlib
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / '.tools/python'))
import UnityPy
from UnityPy.helpers.TypeTreeGenerator import TypeTreeGenerator

destination = ROOT / 'recovery/apk'
destination.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(ROOT / 'Project-Firefight.apk') as archive:
    for item in archive.infolist():
        if not (item.filename.startswith('assets/') or item.filename == 'AndroidManifest.xml'):
            continue
        target = (destination / item.filename).resolve()
        if not target.is_relative_to(destination.resolve()):
            raise ValueError('Invalid archive member: ' + item.filename)
        archive.extract(item, destination)

env = UnityPy.load(str(destination / 'assets/bin/Data'))
generator = TypeTreeGenerator(env.assets[0].unity_version)
generator.load_local_dll_folder(str(destination / 'assets/bin/Data/Managed'))
env.typetree_generator = generator
output = ROOT / 'recovery/trees'
output.mkdir(exist_ok=True)
failures = []
for asset in env.assets:
    records = {}
    for obj in asset.objects.values():
        if obj.type.name in ['Texture2D', 'Mesh', 'Shader', 'AnimationClip', 'Font', 'AudioClip', 'Cubemap']:
            continue
        try:
            node = obj.generate_monobehaviour_node() if obj.type.name == 'MonoBehaviour' else None
            data = obj.read_typetree(nodes=node)
            record = {'type': obj.type.name, 'data': data}
            if obj.type.name == 'MonoBehaviour':
                head = obj.parse_monobehaviour_head()
                record['script'] = head.m_Script.deref_parse_as_object().m_ClassName
                data['m_Script'] = {'m_FileID': head.m_Script.m_FileID, 'm_PathID': head.m_Script.m_PathID}
            records[str(obj.path_id)] = record
        except Exception as error:
            failures.append({'asset': asset.name, 'id': obj.path_id, 'type': obj.type.name, 'reason': str(error)})
    (output / (asset.name + '.json')).write_text(json.dumps(records, ensure_ascii=True, default=str), encoding='utf8')
(ROOT / 'recovery/extraction_report.json').write_text(json.dumps({'unity_version': env.assets[0].unity_version, 'exceptions': failures}, indent=2))
print('Recovered', len(env.assets), 'serialized files;', len(failures), 'exceptions recorded.')
print('TutorialTextSO is recovered directly from its string arrays by tools/recover.py.')
