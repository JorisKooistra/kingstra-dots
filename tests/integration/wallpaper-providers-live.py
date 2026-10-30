#!/usr/bin/env python3
"""Explicit live public-source check. Private downloads only; never applies."""
import argparse
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('picker',ROOT/'config/quickshell/wallpaper/backend.py')
p=importlib.util.module_from_spec(spec)
spec.loader.exec_module(p)


def main():
    cli=argparse.ArgumentParser(description=__doc__)
    cli.add_argument('--output',type=Path,required=True,help='New private test directory')
    cli.add_argument('--query',default='nature')
    cli.add_argument('--sources',nargs='+',default=['wallpaperscom','alphacoders','backiee','wallpaperscraft','goodfon','wallpaperswide'])
    args=cli.parse_args()
    base=args.output.resolve()
    base.mkdir(parents=True,exist_ok=False)
    p.CACHE=base/'cache/kingstra/wallpaper-picker'
    p.CONFIG=base/'config'
    p.CREDENTIALS=base/'config/kingstra/wallpaper-sources.json'
    os.environ['KINGSTRA_WALLPAPER_DIR']=str(base/'library')
    results=[]
    for source in args.sources:
        assert source in p.providers.SOURCES and not p.providers.SOURCES[source].get('needsKey'), 'This check never reads personal keys'
        def fetch(url,**kwargs):return p.provider_fetch(source,url,**kwargs)
        query=argparse.Namespace(query=args.query,page=1,color='')
        response=p.providers.search(source,query,fetch)
        assert response['records'],source+' has no results'
        first=response['records'][0]
        assert all(p.valid_url(item['url'],p.providers.PAGE_HOSTS[source]) and p.valid_url(item['thumb_url'],p.providers.IMAGE_HOSTS[source]) for item in response['records']),source
        p.atomic_json(p.CACHE/'metadata'/(first['id']+'.json'),first)
        events=[]
        for preview in [True,False]:
            with contextlib.redirect_stdout(io.StringIO()) as output:p.download(first['id'],preview)
            events.extend(json.loads(line) for line in output.getvalue().splitlines() if json.loads(line)['event']!='progress')
        preview,saved=events
        assert preview['event']=='preview' and saved['event']=='download'
        path=Path(saved['path'])
        assert path.parent==base/'library'
        metadata=p.read_json(p.metadata_file(path))
        assert metadata['source']==source and metadata['uploader'] and metadata['url']
        with Image.open(path) as image:
            image.verify()
            size=image.size
        result=dict(source=source,count=len(response['records']),lastPage=response['lastPage'],size=size,
                    preview=preview['path'],saved=str(path),tags=metadata['tag_names'],credit=metadata['uploader'])
        results.append(result)
        print(json.dumps(result,ensure_ascii=False),flush=True)
        if response['lastPage']>1 and source in {'alphacoders','backiee','goodfon','wallpaperswide'}:
            query.page=2
            page=p.providers.search(source,query,fetch)
            assert page['records'] and [i['id'] for i in page['records']] != [i['id'] for i in response['records']],source+' repeats first page'
    (base/'results.json').write_text(json.dumps(results,indent=2,ensure_ascii=False))


if __name__=='__main__':main()
