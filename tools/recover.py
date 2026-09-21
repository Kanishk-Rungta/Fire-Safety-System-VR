"""Rebuild portable assets and scene metadata from the supplied Unity APK.
Run from workspace: python tools/recover.py. Dependencies live in .tools/python.
"""
import sys, json, struct, pathlib, re, io, collections
ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / '.tools/python'))
import UnityPy
from UnityPy.helpers.MeshHelper import MeshHandler

OUT = ROOT / 'GodotProject'
E = UnityPy.load(str(ROOT / 'recovery/apk/assets/bin/Data'))
FILES = {f.name: f for f in E.assets}
TREES = {p.stem: json.loads(p.read_text()) for p in (ROOT/'recovery/trees').glob('*.json')}
ERRORS = []
def ref(f, p):
    if not p or not p.get('m_PathID'): return None
    if p['m_FileID']: f = FILES[f.externals[p['m_FileID']-1].path.replace('\\','/').split('/')[-1]]
    return f.objects[p['m_PathID']]
def key(o): return o.assets_file.name.replace('.','_')+'_'+str(o.path_id)
def vec(d): return [d['x'],d['y'],-d['z']]
def clean(s): return re.sub(r'[^\w-]', '_', s)
def linear(v): return v/12.92 if v<=0.04045 else ((v+0.055)/1.055)**2.4

# Recover all textures, original fonts, and sounds independently of scene use.
textures = {}
for o in E.objects:
    if o.type.name not in ('Texture2D','AudioClip','Font'): continue
    try:
        d=o.read(); name=clean(d.m_Name)+'_'+key(o)
        if o.type.name=='Texture2D' and d.m_Width and d.m_Height:
            dest='assets/'+name+'.png'; d.image.save(OUT/dest); textures[key(o)]=dest
        elif o.type.name=='Font' and d.m_FontData:
            (OUT/('assets/'+name+'.ttf')).write_bytes(bytes(d.m_FontData))
        elif o.type.name=='AudioClip':
            for n,b in d.samples.items(): (OUT/('assets/'+clean(d.m_Name)+pathlib.Path(n).suffix)).write_bytes(b)
    except Exception as ex: ERRORS.append([key(o),str(ex)])

# ScriptableObject's serialized strings (the generic metadata generator cannot read List<string> here).
raw=FILES['sharedassets0.assets'].objects[21].get_raw_data(); pos=28
def read_int():
    global pos
    n=struct.unpack_from('<i',raw,pos)[0];pos+=4;return n
def read_string():
    global pos
    n=read_int();s=raw[pos:pos+n].decode('utf8').rstrip('\0');pos=(pos+n+3)&~3;return s
read_string()
tutorial={}
for name in ['de_city','en_city','de_forest','en_forest']:
    strings=[read_string() for _ in range(read_int())]
    if name.startswith("en_"): tutorial[name[3:]]=strings
(OUT/'data/tutorial.json').write_text(json.dumps(tutorial,ensure_ascii=False,indent=2),encoding='utf8')

class GLB:
    def __init__(self):
        self.j={'asset':{'version':'2.0','generator':'Project Firefight APK recovery'},'scene':0,'scenes':[{'nodes':[]}], 'nodes':[], 'meshes':[], 'materials':[], 'textures':[], 'images':[], 'samplers':[{'magFilter':9729,'minFilter':9987,'wrapS':10497,'wrapT':10497}], 'accessors':[], 'bufferViews':[], 'buffers':[]}
        self.b=bytearray();self.mats={};self.tex={};self.meshes={}
    def blob(self,b):
        while len(self.b)%4:self.b.append(0)
        i=len(self.j['bufferViews']);self.j['bufferViews'].append({'buffer':0,'byteOffset':len(self.b),'byteLength':len(b)});self.b.extend(b);return i
    def acc(self, rows, typ, integer=False, bounds=False):
        n={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[typ]
        flat=rows if n==1 else [v for row in rows for v in row]
        v=self.blob(struct.pack('<'+('I' if integer else 'f')*len(flat),*flat))
        a={'bufferView':v,'componentType':5125 if integer else 5126,'count':len(rows),'type':typ}
        if bounds:a.update(min=[min(r[k] for r in rows) for k in range(n)],max=[max(r[k] for r in rows) for k in range(n)])
        i=len(self.j['accessors']);self.j['accessors'].append(a);return i
    def material(self,o):
        if not o:return None
        k=key(o)
        if k in self.mats:return self.mats[k]
        d=o.read_typetree(); props=d['m_SavedProperties'];colors=dict(props['m_Colors']);floats=dict(props['m_Floats']);tex=dict(props['m_TexEnvs'])
        c=colors.get('_BaseColor',colors.get('_Color',dict(r=1,g=1,b=1,a=1)))
        m={'name':d['m_Name'],'doubleSided':floats.get('_Cull',2)==0,'pbrMetallicRoughness':{'baseColorFactor':[linear(c[x]) for x in 'rgb']+[c['a']],'metallicFactor':floats.get('_Metallic',0),'roughnessFactor':1-floats.get('_Smoothness',floats.get('_Glossiness',0))}}
        t=tex.get('_BaseMap',tex.get('_MainTex'))
        if t:
            obj=ref(o.assets_file,t['m_Texture'])
            if obj and key(obj) in textures:
                tk=key(obj)
                if tk not in self.tex:
                    img=len(self.j['images']);self.j['images'].append({'bufferView':self.blob((OUT/textures[tk]).read_bytes()),'mimeType':'image/png'})
                    self.tex[tk]=len(self.j['textures']);self.j['textures'].append({'source':img,'sampler':0})
                m['pbrMetallicRoughness']['baseColorTexture']={'index':self.tex[tk]}
                scale=t['m_Scale'];offset=t['m_Offset']
                if scale!={'x':1.0,'y':1.0} or offset!={'x':0.0,'y':0.0}:
                    self.j['extensionsUsed']=['KHR_texture_transform']
                    m['pbrMetallicRoughness']['baseColorTexture']['extensions']={'KHR_texture_transform':{'scale':[scale['x'],scale['y']],'offset':[offset['x'],1-scale['y']-offset['y']]}}
        if floats.get('_AlphaClip',0) or floats.get('_Mode',0)==1 or ('_Cutoff' in floats and '_Surface' not in floats):m.update(alphaMode='MASK',alphaCutoff=floats.get('_Cutoff',0.5),doubleSided=True)
        elif floats.get('_Surface',0) or floats.get('_Mode',0)>1 or c['a']<0.99:m.update(alphaMode='BLEND',doubleSided=True)
        i=len(self.j['materials']);self.mats[k]=i;self.j['materials'].append(m);return i
    def mesh(self,o,renderer):
        if not o:return None
        batch=renderer.get('m_StaticBatchInfo',{});start=batch.get('firstSubMesh',0) if batch.get('subMeshCount',0) else 0
        mats=[ref(renderer['_file'],p) for p in renderer['m_Materials']]
        cache=(key(o),start,batch.get('subMeshCount',0),tuple(key(m) if m else '' for m in mats))
        if cache in self.meshes:return self.meshes[cache]
        d=o.read();h=MeshHandler(d);h.process();prims=[]
        count=batch.get('subMeshCount',0) or len(d.m_SubMeshes)
        for subindex in range(start,min(start+count,len(d.m_SubMeshes))):
            sub=d.m_SubMeshes[subindex]
            if sub.topology!=0:continue
            off=sub.firstByte//(2 if h.m_Use16BitIndices else 4)
            ix=list(h.m_IndexBuffer[off:off+sub.indexCount]);ix=[v+(sub.baseVertex or 0) for v in ix]
            used=sorted(set(ix));lookup={v:i for i,v in enumerate(used)}
            vertices=[(h.m_Vertices[i][0],h.m_Vertices[i][1],-h.m_Vertices[i][2]) for i in used]
            att={'POSITION':self.acc(vertices,'VEC3',bounds=True)}
            if h.m_Normals:att['NORMAL']=self.acc([(h.m_Normals[i][0],h.m_Normals[i][1],-h.m_Normals[i][2]) for i in used],'VEC3')
            if h.m_UV0:att['TEXCOORD_0']=self.acc([(h.m_UV0[i][0],1-h.m_UV0[i][1]) for i in used],'VEC2')
            indices=[]
            for a,b,c in zip(ix[0::3],ix[1::3],ix[2::3]):indices.extend([lookup[a],lookup[c],lookup[b]])
            prim={'attributes':att,'indices':self.acc(indices,'SCALAR',True)}
            if mats:
                mi=self.material(mats[min(subindex-start,len(mats)-1)])
                if mi is not None:prim['material']=mi
            prims.append(prim)
        if not prims:return None
        i=len(self.j['meshes']);self.j['meshes'].append({'name':d.m_Name,'primitives':prims});self.meshes[cache]=i;return i
    def save(self,path):
        while len(self.b)%4:self.b.append(0)
        self.j['buffers']=[{'byteLength':len(self.b)}]
        for k in ['meshes','materials','textures','images','accessors','bufferViews']:
            if not self.j[k]:del self.j[k]
        j=json.dumps(self.j,separators=(',',':')).encode();j+=b' '*((-len(j))%4)
        path.write_bytes(struct.pack('<III',0x46546C67,2,28+len(j)+len(self.b))+struct.pack('<II',len(j),0x4E4F534A)+j+struct.pack('<II',len(self.b),0x004E4942)+self.b)

for number,label in [(0,'menu'),(1,'city'),(2,'forest'),('sharedassets1.assets','equipment')]:
    f=FILES['level'+str(number) if isinstance(number,int) else number];tree=TREES[f.name];g=GLB();nodes={};transforms={};components=collections.defaultdict(list)
    for sid,o in tree.items():
        d=o['data']
        if 'm_GameObject' in d:components[d['m_GameObject']['m_PathID']].append((int(sid),o))
        if o['type'] in ['Transform','RectTransform']:transforms[int(sid)]=d
    metadata={'objects':{},'components':tree,'scene':label}
    for tid,t in transforms.items():
        go=t['m_GameObject']['m_PathID'];obj=tree[str(go)]['data'];q=t['m_LocalRotation']
        nd={'name':'U'+str(go)+'_'+clean(obj['m_Name']),'translation':vec(t['m_LocalPosition']),'rotation':[-q['x'],-q['y'],q['z'],q['w']],'scale':[t['m_LocalScale'][v] for v in 'xyz'],'extras':{'unity_id':go,'unity_name':obj['m_Name'],'active':bool(obj['m_IsActive'])}}
        nodes[tid]=len(g.j['nodes']);g.j['nodes'].append(nd)
        metadata['objects'][str(go)]={'name':obj['m_Name'],'transform':tid,'active':bool(obj['m_IsActive']),'node_name':nd['name']}
    for tid,t in transforms.items():
        idx=nodes[tid];nd=g.j['nodes'][idx];parent=t['m_Father']['m_PathID']
        if parent in nodes:g.j['nodes'][nodes[parent]].setdefault('children',[]).append(idx)
        else:g.j['scenes'][0]['nodes'].append(idx)
        go=t['m_GameObject']['m_PathID'];cs=components[go]
        filters=[o['data'] for _,o in cs if o['type']=='MeshFilter'];renders=[o['data'] for _,o in cs if o['type']=='MeshRenderer']
        if filters and renders:
            r=dict(renders[0]);r['_file']=f
            try:
                mi=g.mesh(ref(f,filters[0]['m_Mesh']),r)
                if mi is not None:
                    if r.get('m_StaticBatchInfo',{}).get('subMeshCount',0):
                        # Unity static batches store vertices in scene space.
                        bi=len(g.j['nodes']);g.j['nodes'].append({'name':'Batch_'+nd['name'],'mesh':mi,'extras':{'unity_owner':go}});g.j['scenes'][0]['nodes'].append(bi)
                    else:nd['mesh']=mi
            except Exception as ex:ERRORS.append([label,go,str(ex)])
        for _,component in cs:
            if component['type']=='MeshCollider' and component['data'].get('m_Enabled'):
                collider=component['data']
                mi=g.mesh(ref(f,collider['m_Mesh']),{'_file':f,'m_Materials':[]})
                if mi is not None:
                    ci=len(g.j['nodes']);g.j['nodes'].append({'name':'CollisionSource_U'+str(go),'mesh':mi})
                    nd.setdefault('children',[]).append(ci)
    if label != 'menu': g.save(OUT/('assets/'+label+'.glb'))
    (OUT/('data/'+label+'.json')).write_text(json.dumps(metadata,separators=(',',':')),encoding='utf8')
    print(label,len(nodes),'nodes',len(g.j.get('meshes',[])),'mesh instances',flush=True)
(OUT/'data/fire_rules.json').write_text(json.dumps(TREES['sharedassets1.assets']['207']['data'],indent=2))
(ROOT/'recovery/export_report.json').write_text(json.dumps({'errors':ERRORS,'textures':textures},indent=2))
print('Export errors:',ERRORS)
