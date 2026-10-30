#!/usr/bin/env python3
"""Source contracts, key isolation and full-image cache regression checks."""
import argparse
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from urllib.parse import parse_qs, urlparse
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('picker', ROOT / 'config/quickshell/wallpaper/backend.py')
picker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(picker)
p = picker.providers


def args(source, page=1, query='nature'):
    return argparse.Namespace(source=source, page=page, query=query, color='0066cc')


class ProviderTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        for name, path in dict(CACHE=self.base/'cache/kingstra/wallpaper-picker', CONFIG=self.base/'config',
                               CREDENTIALS=self.base/'config/kingstra/wallpaper-sources.json', SETTINGS=self.base/'config/kingstra/wallpaper-picker.json').items():
            replacement = patch.object(picker, name, path)
            replacement.start()
            self.addCleanup(replacement.stop)
        replacement = patch.dict(picker.os.environ, KINGSTRA_WALLPAPER_DIR=str(self.base/'library'))
        replacement.start()
        self.addCleanup(replacement.stop)

    def capture(self, function, *arguments):
        with contextlib.redirect_stdout(io.StringIO()) as output:
            function(*arguments)
        return [json.loads(line) for line in output.getvalue().splitlines() if json.loads(line)['event'] != 'progress']

    def test_keys_are_private_never_echoed_and_can_be_removed(self):
        for source in ['wallhaven', 'wallpaperscom', 'pixabay', 'pexels']:
            events = self.capture(picker.credential, dict(provider=source, key='private-test-secret-123'))
            self.assertNotIn('private-test-secret', json.dumps(events))
            self.assertTrue(next(row for row in events[0]['sources'] if row['id']==source)['configured'])
        self.assertEqual(picker.CREDENTIALS.stat().st_mode & 0o777, 0o600)
        self.capture(picker.credential, dict(provider='pixabay', key=''))
        self.assertNotIn('pixabay', picker.provider_keys())
        for payload in [dict(provider='zedge',key='secret-123'), dict(provider='pexels',key='a\nb'), dict(provider='../evil',key='secret-123')]:
            with self.assertRaises(ValueError): picker.credential(payload)

    def test_missing_key_makes_no_network_request(self):
        with patch.object(picker, 'provider_fetch') as fetch:
            for source in ['pixabay','pexels']:
                event=self.capture(picker.search, args(source))[0]
                self.assertEqual(event['event'], 'error')
                self.assertTrue(event['needsKey'])
            fetch.assert_not_called()

    def test_authenticated_redirect_cannot_send_key_to_other_host(self):
        request=picker.urllib.request.Request('https://api.pexels.com/v1/search',headers={'Authorization':'private-key'})
        handler=picker.SafeRedirect({'api.pexels.com'})
        with self.assertRaises(ValueError): handler.redirect_request(request,None,302,'',{},'https://www.pexels.com/other')
        with self.assertRaises(ValueError): picker.provider_fetch('pexels','https://evil.test/?key=secret')
        self.assertFalse(picker.valid_url('http://api.pexels.com/',p.PAGE_HOSTS['pexels']))

    def test_pexels_uses_original_author_header_and_real_pagination(self):
        def fetch(url, **kwargs):
            self.assertEqual(urlparse(url).hostname,'api.pexels.com')
            self.assertEqual(kwargs['headers'], {'Authorization':'private-test-key'})
            self.assertEqual(parse_qs(urlparse(url).query)['orientation'],['landscape'])
            return dict(photos=[dict(id=7,alt='Blue sea',url='https://www.pexels.com/photo/7/',photographer='Alice',width=6000,height=4000,
                                    src=dict(large='https://images.pexels.com/thumb.jpeg',original='https://images.pexels.com/full.jpeg'))],next_page='next')
        result=p.search('pexels',args('pexels'),fetch,'private-test-key')
        item=result['records'][0]
        self.assertTrue(item['download_url'].endswith('/full.jpeg'))
        self.assertEqual(item['uploader'],'Alice')
        self.assertEqual(result['lastPage'],2)

    def test_pixabay_24_hour_cache_original_tags_and_resolution_limit(self):
        for original in [False,True]:
            def fetch(url, **kwargs):
                self.assertEqual(kwargs['ttl'],86400)
                self.assertEqual(parse_qs(urlparse(url).query)['key'],['private-key'])
                row=dict(id=3,tags='sea, blue',pageURL='https://pixabay.com/photos/sea-3/',user='Bob',imageWidth=6000,imageHeight=4000,
                         webformatURL='https://cdn.pixabay.com/thumb.jpg',largeImageURL='https://cdn.pixabay.com/1280.jpg')
                if original: row['imageURL']='https://cdn.pixabay.com/original.jpg'
                return dict(hits=[row],totalHits=99)
            result=p.search('pixabay',args('pixabay'),fetch,'private-key')
            item=result['records'][0]
            self.assertEqual(item['tag_names'],['sea','blue'])
            self.assertEqual(item['download_url'].endswith('/original.jpg'),original)
            self.assertEqual('1280' in item['resolution'],not original)
            self.assertEqual(result['lastPage'],2)

    def test_pixabay_safety_category_colour_resolution_and_order_contract(self):
        query=args('pixabay')
        query.category='nature';query.atleast='2560x1440';query.sort='date_added';query.purity='100'
        calls=[]
        def fetch(url,**kwargs):
            calls.append(parse_qs(urlparse(url).query))
            return dict(hits=[],totalHits=0)
        p.search('pixabay',query,fetch,'private-key')
        self.assertEqual({name:calls[-1][name][0] for name in ['safesearch','category','colors','min_width','min_height','order']},
                         dict(safesearch='true',category='nature',colors='blue',min_width='2560',min_height='1440',order='latest'))
        query.purity='111'
        p.search('pixabay',query,fetch,'private-key')
        self.assertEqual(calls[-1]['safesearch'],['false'])

    def test_pexels_default_search_honours_size_and_hex_colour(self):
        query=args('pexels',query='');query.size='large'
        calls=[]
        p.search('pexels',query,lambda url,**kwargs:calls.append(url) or dict(photos=[]),'private-key')
        params=parse_qs(urlparse(calls[0]).query)
        self.assertEqual(params['query'],['wallpaper'])
        self.assertEqual(params['color'],['#0066cc'])
        self.assertEqual(params['size'],['large'])

    def test_no_ai_uses_explicit_labels_and_keeps_human_art(self):
        for value in [dict(AIGenerated=1),dict(tags=['AI art']),dict(tag_names=['Midjourney']),dict(name='AI-generated landscape')]:
            self.assertTrue(p.is_ai(value),value)
        for value in [dict(AIGenerated=0),dict(tags=['digital art','anime','fantasy']),dict(name='Portrait by Mai'),dict(tags=['AI research'])]:
            self.assertFalse(p.is_ai(value),value)
        query=args('backiee',query='');query.exclude_ai=True
        calls=[]
        def fetch(url,**kwargs):
            calls.append(url)
            return [dict(ID=1,Title='Portrait',WallpaperUrl='https://backiee.com/wallpaper/portrait/1',AIGenerated=1),
                    dict(ID=2,Title='Digital artwork',WallpaperUrl='https://backiee.com/wallpaper/art/2',AIGenerated=0)]
        result=p.search('backiee',query,fetch)
        self.assertEqual([r['remote_id'] for r in result['records']],['2'])
        self.assertEqual(parse_qs(urlparse(calls[0]).query)['is_ai'],['no'])

    def test_no_ai_blocks_full_transfer_before_publishing_to_library(self):
        item=p.record('backiee',123,'Portrait','https://backiee.com/wallpaper/portrait/123','https://backiee.com/thumb.jpg','https://backiee.com/full.jpg')
        item.update(details_ready=True,is_ai=True)
        pth=picker.CACHE/'metadata'/(item['id']+'.json')
        picker.atomic_json(pth,item)
        with patch.object(picker,'transfer_image') as transfer:
            with self.assertRaises(picker.ExcludedAI): picker.download(item['id'],exclude_ai=True)
            transfer.assert_not_called()
        self.capture(picker.preferences,'excludeAi','true')
        self.assertTrue(picker.read_json(picker.SETTINGS).get('excludeAi'))

    def test_wallhaven_no_ai_excludes_verified_tag_without_replacing_query(self):
        query=args('wallhaven');query.exclude_ai=True;query.categories='111';query.purity='101';query.sort='toplist';query.atleast='';query.ratios=''
        with patch.object(picker,'remote_json',return_value=dict(data=[],meta={})) as request:
            self.capture(picker.search,query)
        params=parse_qs(urlparse(request.call_args.args[0]).query)
        self.assertEqual(params['q'],['nature -id:133451'])
        self.assertEqual(params['purity'],['101'])

    def test_wallpapers_com_batches_60_without_fake_infinite_pages(self):
        rows=[dict(id=i,title=f'Image {i}',url=f'https://wallpapers.com/wallpapers/{i}.html',thumb=f'https://wallpapers.com/{i}.jpg',high=f'https://wallpapers.com/{i}-high.jpg') for i in range(60)]
        results=[p.search('wallpaperscom',args('wallpaperscom',page),lambda url,**kwargs:dict(items=rows)) for page in [1,2,3]]
        self.assertEqual([len(d['records']) for d in results],[24,24,12])
        self.assertEqual([d['lastPage'] for d in results],[2,3,3])
        self.assertEqual(len({r['id'] for d in results for r in d['records']}),60)
        item=results[0]['records'][0]
        detail=p.details(item,lambda url,**kwargs:'<meta property="og:image" content="https://wallpapers.com/images/hd/original.jpg">')
        self.assertTrue(detail['download_url'].endswith('/hd/original.jpg'))

    def test_alpha_uses_published_extension_not_thumbnail_guess(self):
        body='''<img src="https://images8.alphacoders.com/136/thumbbig-1363709.webp" alt="Nature">
        <script>downloadContentModal('images8', 1363709, 'png', 0); function loadNextPage(){}</script>'''
        result=p.search('alphacoders',args('alphacoders'),lambda url,**kwargs:body)
        self.assertEqual(result['records'][0]['download_url'],'https://images8.alphacoders.com/136/1363709.png')
        self.assertEqual(result['lastPage'],2)

    def test_craft_reads_original_resolution_and_credit(self):
        item=p.record('wallpaperscraft','nature','Nature','https://wallpaperscraft.com/wallpaper/nature','https://images.wallpaperscraft.com/nature_300x200.jpg')
        body='''<a href="/download/nature/4912x7360">Original Resolution: 4912x7360</a><img class="wallpaper__image" src="https://images.wallpaperscraft.com/nature_1280x720.jpg">
        <a href="/tag/forest">forest</a><div class="author__row">Author: Alice</div><div class="author__row">License: CC0</div>'''
        detail=p.details(item,lambda url,**kwargs:body)
        self.assertTrue(detail['download_url'].endswith('_4912x7360.jpg'))
        self.assertEqual(detail['tag_names'],['forest'])
        self.assertEqual(detail['uploader'],'Alice')
        self.assertEqual(detail['license'],'CC0')

    def test_backiee_uses_published_image_not_broken_generic_8k_option(self):
        item=p.record('backiee','123','Forest','https://backiee.com/wallpaper/forest/123','https://backiee.com/123.jpg')
        data=dict(**{'@type':'ImageObject'},contentUrl='https://backiee.com/static/wallpapers/3840x2160/123.jpg',width=3840,height=2160,keywords='forest, green',creditText='Alice')
        body='<script type="application/ld+json">'+json.dumps(data)+'</script><a href="/static/wallpapers/7680x4320/123.jpg">8K</a>'
        detail=p.details(item,lambda url,**kwargs:body)
        self.assertIn('/3840x2160/',detail['download_url'])
        self.assertEqual(detail['tag_names'],['forest','green'])
        calls=[]
        p.search('backiee',args('backiee',2),lambda url,**kwargs:calls.append(url) or '')
        self.assertIn('page=2',calls[0])

    def test_removed_zedge_source_preserves_saved_image_metadata(self):
        self.assertNotIn('zedge',p.SOURCES)
        path=self.base/'library/zedge-old.jpg'
        path.parent.mkdir()
        Image.new('RGB',(100,100),'blue').save(path)
        picker.atomic_json(picker.metadata_file(path),dict(source='zedge',tag_names=['sky'],uploader='Creator',name='Old wallpaper'))
        metadata=picker.local_metadata(path,{})
        self.assertEqual(metadata['tags'],['sky'])
        self.assertEqual(metadata['displayName'],'Old wallpaper')
        self.assertTrue(path.is_file())

    def test_hdqwalls_external_fallback_has_no_network_or_fake_results(self):
        self.assertTrue(p.SOURCES['hdqwalls']['externalOnly'])
        with patch.object(picker,'provider_fetch') as request:
            result=self.capture(picker.search,args('hdqwalls'))[0]
            request.assert_not_called()
        self.assertEqual(result['items'],[])
        self.assertEqual(result['lastPage'],1)
        self.assertIn('browsercontrole',result['notice'])

    def test_goodfon_search_pagination_original_credit_tags_and_ai_marker(self):
        body='''<div class="wallpapers__item__wall"><a href="/nature/wallpaper-forest.html"><img class="wallpapers__item__img" alt="Forest" src="https://img.goodfon.com/wallpaper/big/forest.webp"></a>
        <div class="wallpapers__item__size">3840x2160</div><a class="wallpapers__item__user_block" title="Alice"></a></div>
        <div class="wallpapers__item__wall"><a href="/ai-art/wallpaper-other.html"><img class="wallpapers__item__img" alt="Forest" src="https://img.goodfon.com/wallpaper/big/other.webp"></a></div><a href="index-2.html">Next</a>'''
        query=args('goodfon',query='');query.exclude_ai=True
        result=p.search('goodfon',query,lambda url,**kwargs:body)
        self.assertEqual(len(result['records']),1)
        self.assertEqual(result['lastPage'],2)
        item=result['records'][0]
        self.assertEqual(item['resolution'],'3840 × 2160')
        original=dict(**{'@type':'ImageObject'},contentUrl='https://img.goodfon.com/original/3840x2160/forest.jpg',creator=dict(name='Bob'),width=3840,height=2160,license='https://creativecommons.org/licenses/by-nc/4.0/')
        detail='<script type="application/ld+json">'+json.dumps(original)+'</script><div class="wallpaper__tags"><a href="/tags/forest/">forest</a></div><a href="/tags/unrelated/">unrelated</a>'
        enriched=p.details(item,lambda url,**kwargs:detail)
        self.assertEqual(enriched['tag_names'],['forest'])
        self.assertIn('/original/',enriched['download_url'])
        self.assertEqual(enriched['uploader'],'Bob')
        with self.assertRaisesRegex(ValueError,'originele'):p.details(item,lambda url,**kwargs:'<p>not found</p>')

    def test_wallpaperswide_native_tag_search_pages_and_published_hd(self):
        calls=[]
        body='''<a href="/forest-wallpapers.html"><img class="thumb_img" alt="Forest 4K UHD Wallpaper for Desktop" src="https://hd.wallpaperswide.com/thumbs/forest-t1.jpg"></a><a href="/tag/dark+contrast/page/2">Next</a>'''
        def fetch(url,**kwargs):calls.append(url);return body
        result=p.search('wallpaperswide',args('wallpaperswide',query='dark contrast'),fetch)
        self.assertEqual(calls[0],'https://wallpaperswide.com/tag/dark+contrast.html')
        self.assertEqual(result['lastPage'],2)
        item=result['records'][0]
        self.assertEqual(item['name'],'Forest')
        p.search('wallpaperswide',args('wallpaperswide',2,'dark contrast'),fetch)
        self.assertTrue(calls[-1].endswith('/tag/dark+contrast/page/2'))
        detail='''<a itemprop="url contentUrl" href="/download/forest-wallpaper-3840x2160.jpg">4K</a><a rel="author">More wallpapers posted by Alice</a><a rel="tag" href="/nature-desktop-wallpapers.html">Seasons/Autumn</a><a rel="tag" href="/tag/forest.html">Forest</a>'''
        enriched=p.details(item,lambda url,**kwargs:detail)
        self.assertEqual(enriched['download_url'],'https://wallpaperswide.com/download/forest-wallpaper-3840x2160.jpg')
        self.assertEqual(enriched['uploader'],'Alice')
        self.assertEqual(enriched['tag_names'],['Forest'])
        with self.assertRaisesRegex(ValueError,'HD-download'):p.details(item,lambda url,**kwargs:'<img src="small.jpg">')

    def test_wallpaperswide_unknown_tag_is_empty_but_network_failures_are_not_hidden(self):
        def request(url,**kwargs):raise picker.urllib.error.HTTPError(url,404,'not found',{},None)
        self.assertEqual(p.search('wallpaperswide',args('wallpaperswide'),request)['records'],[])
        error=picker.urllib.error.HTTPError('https://wallpaperswide.com/',403,'forbidden',{},io.BytesIO())
        self.addCleanup(error.close)
        def forbidden(url,**kwargs):raise error
        with self.assertRaises(picker.urllib.error.HTTPError):p.search('wallpaperswide',args('wallpaperswide'),forbidden)

    def test_search_refresh_preserves_enriched_credit_license_and_ai_metadata(self):
        item=p.record('goodfon',1,'Forest','https://www.goodfon.com/nature/wallpaper-forest.html','https://img.goodfon.com/thumb.jpg')
        enriched=dict(item,details_ready=True,detail_time=picker.time.time(),download_url='https://img.goodfon.com/original/forest.jpg',
                      license_url='https://creativecommons.org/licenses/by-nc/4.0/',tag_names=['forest'],uploader='Alice',attribution='By Alice',is_ai=False)
        picker.atomic_json(picker.CACHE/'metadata'/(item['id']+'.json'),enriched)
        with patch.object(p,'search',return_value=dict(records=[item],page=1,lastPage=1)),patch.object(picker,'remote_thumbnail',return_value=dict(path=item['id'],thumb='file:///thumb.jpg')):
            self.capture(picker.search,args('goodfon'))
        record=picker.read_json(picker.CACHE/'metadata'/(item['id']+'.json'))
        for field in ['license_url','attribution','uploader','is_ai','tag_names','download_url']:self.assertEqual(record[field],enriched[field])

    def test_repeated_site_page_stops_pagination(self):
        item=p.record('alphacoders',1,'Image','https://wall.alphacoders.com/big.php?i=1','https://images8.alphacoders.com/thumb.jpg')
        def search(source,arg,*arguments): return dict(records=[dict(item)],page=arg.page,lastPage=arg.page+1)
        with patch.object(p,'search',side_effect=search),patch.object(picker,'remote_thumbnail',return_value=dict(path=item['id'],thumb='file:///thumb.jpg')):
            self.assertEqual(len(self.capture(picker.search,args('alphacoders'))[0]['items']),1)
            repeated=self.capture(picker.search,args('alphacoders',2))[0]
            self.assertEqual(repeated['items'],[])
            self.assertEqual(repeated['lastPage'],2)

    def test_all_sources_save_cached_full_preview_and_metadata_without_second_request(self):
        for source in p.SOURCES:
            if p.SOURCES[source].get('externalOnly'):continue
            with self.subTest(source=source):
                host=sorted(p.IMAGE_HOSTS[source])[0]
                item=p.record(source,123,'Image','https://'+sorted(p.PAGE_HOSTS[source])[0]+'/image','https://'+host+'/thumb.jpg','https://'+host+'/full.jpg')
                item.update(details_ready=True,tag_names=['landscape'],uploader='Alice')
                cached=picker.CACHE/'previews'/(item['id']+'.jpg')
                cached.parent.mkdir(parents=True,exist_ok=True)
                Image.new('RGB',(1600,1000),'blue').save(cached)
                item['path']=str(cached)
                picker.atomic_json(picker.CACHE/'metadata'/(item['id']+'.json'),item)
                with patch.object(picker.urllib.request,'urlopen') as request:
                    event=self.capture(picker.download,item['id'])[0]
                    request.assert_not_called()
                target=Path(event['path'])
                self.assertEqual(target.parent,self.base/'library')
                record=picker.read_json(picker.metadata_file(target))
                self.assertEqual(record['source'],source)
                self.assertEqual(record['tag_names'],['landscape'])
                self.assertEqual(record['resolution'],'1600 × 1000')
                self.assertEqual(picker.saved_wallhaven(item['id']),str(target))


if __name__ == '__main__': unittest.main()
