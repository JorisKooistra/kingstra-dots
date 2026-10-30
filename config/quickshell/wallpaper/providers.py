"""Extra wallpaper sources. Only public pages/APIs; no accounts or challenge bypass.

Each adapter returns provider-neutral records. The worker owns all caching,
downloads, credentials and image validation. HTML and React data are parsed,
never executed.
"""
import hashlib
import html
from html.parser import HTMLParser
import json
import re
from urllib.error import HTTPError
from urllib.parse import quote, urlencode, urljoin, urlparse

SOURCES = {
    "wallpaperscom": dict(label="Wallpapers.com", url="https://wallpapers.com/", keyUrl="https://wallpapers.com/account/api-keys/", optionalKey=True, kind="api"),
    "alphacoders": dict(label="Alpha Coders", url="https://alphacoders.com/", kind="site"),
    "backiee": dict(label="backiee", url="https://backiee.com/", kind="site"),
    "wallpaperscraft": dict(label="WallpapersCraft", url="https://wallpaperscraft.com/", kind="site"),
    "goodfon": dict(label="GoodFon", url="https://www.goodfon.com/", kind="site"),
    "hdqwalls": dict(label="HDQwalls", url="https://hdqwalls.com/", kind="external", externalOnly=True,
                     notice="HDQwalls vraagt een browsercontrole. Open de website om daar wallpapers te bekijken en te downloaden."),
    "wallpaperswide": dict(label="WallpapersWide", url="https://wallpaperswide.com/", kind="site", tagSearch=True),
    "pexels": dict(label="Pexels", url="https://www.pexels.com/", keyUrl="https://www.pexels.com/api/", needsKey=True, kind="api"),
    "pixabay": dict(label="Pixabay", url="https://pixabay.com/", keyUrl="https://pixabay.com/api/docs/", needsKey=True, kind="api"),
}
# Preserve the metadata of images already saved from a removed source.
LEGACY_SOURCES = {"zedge"}
PIXABAY_CATEGORIES = ["backgrounds", "fashion", "nature", "science", "education", "feelings", "health", "people", "religion", "places", "animals", "industry", "computer", "food", "sports", "transportation", "travel", "buildings", "business", "music"]
SOURCES["pixabay"]["categories"] = PIXABAY_CATEGORIES
IMAGE_HOSTS = {
    "wallpaperscom": {"wallpapers.com"},
    "alphacoders": {"images.alphacoders.com", *{f"images{i}.alphacoders.com" for i in range(1, 10)}},
    "backiee": {"backiee.com"},
    "wallpaperscraft": {"images.wallpaperscraft.com"},
    "goodfon": {"img.goodfon.com"},
    "hdqwalls": set(),
    "wallpaperswide": {"wallpaperswide.com", "hd.wallpaperswide.com"},
    "pexels": {"images.pexels.com"},
    "pixabay": {"pixabay.com", "cdn.pixabay.com"},
}
PAGE_HOSTS = {
    "wallpaperscom": {"wallpapers.com"},
    "alphacoders": {"alphacoders.com", "wall.alphacoders.com"},
    "backiee": {"backiee.com"},
    "wallpaperscraft": {"wallpaperscraft.com"},
    "goodfon": {"www.goodfon.com", "goodfon.com"},
    "hdqwalls": {"hdqwalls.com", "www.hdqwalls.com"},
    "wallpaperswide": {"wallpaperswide.com", "www.wallpaperswide.com"},
    "pexels": {"www.pexels.com", "api.pexels.com"},
    "pixabay": {"pixabay.com"},
}


class Node:
    def __init__(self, tag="", attrs=(), parent=None):
        self.tag, self.attrs, self.parent = tag, dict(attrs), parent
        self.children, self.parts = [], []

    def all(self, tag=None, cls=None):
        for child in self.children:
            if (tag is None or child.tag == tag) and (cls is None or cls in child.attrs.get("class", "").split()):
                yield child
            yield from child.all(tag, cls)

    def text(self):
        return " ".join(" ".join(self.parts + [child.text() for child in self.children]).split())


class Document(HTMLParser):
    VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"}
    def __init__(self, body):
        super().__init__(convert_charrefs=True)
        self.root = Node()
        self.stack = [self.root]
        self.feed(body)

    def handle_starttag(self, tag, attrs):
        node = Node(tag, attrs, self.stack[-1])
        self.stack[-1].children.append(node)
        if tag not in self.VOID: self.stack.append(node)

    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)
        if tag not in self.VOID: self.handle_endtag(tag)

    def handle_endtag(self, tag):
        for i in range(len(self.stack) - 1, 0, -1):
            if self.stack[i].tag == tag:
                self.stack = self.stack[:i]
                break

    def handle_data(self, data):
        self.stack[-1].parts.append(data)


def meta(doc, name):
    return next((node.attrs.get("content", "") for node in doc.all("meta")
                 if node.attrs.get("name") == name or node.attrs.get("property") == name), "")


def tags(doc):
    return list(dict.fromkeys(node.text() for node in doc.all("a")
                              if re.search(r"/(?:tag|tags)/", node.attrs.get("href", "")) and node.text()))[:24]


def record(source, raw_id, name, page, thumb, full="", **extra):
    identifier = source + "-" + hashlib.sha256(str(raw_id).encode()).hexdigest()[:24]
    return dict(source=source, id=identifier, remote_id=str(raw_id), name=html.unescape(name or str(raw_id)),
                url=page, thumb_url=html.unescape(thumb or ""), download_url=html.unescape(full or ""),
                tag_names=[], uploader=SOURCES[source]["label"], resolution="", **extra)


def dimension(width, height):
    return f"{width} × {height}" if width and height else ""


def is_ai(item):
    """Use explicit provider flags/labels, never guess from an art style."""
    for name in ["is_ai", "isAI", "IsAI", "AI", "ai_generated", "AIGenerated"]:
        if str(item.get(name, "")).lower() in {"1", "true", "yes"}: return True
    values = [item.get("name", "")]
    for field in ["tags", "tag_names", "categories"]:
        parts = item.get(field, [])
        if isinstance(parts, str): parts = [parts]
        values.extend(part.get("name", "") if isinstance(part, dict) else str(part) for part in parts)
    return bool(re.search(r"\b(?:ai[-_ ]+(?:art|generated|generat(?:ed|ive)?|wallpapers?)|generative[-_ ]+ai|midjourney|stable[-_ ]*diffusion|dall[-_ ]?e)\b", " ".join(values), re.I))


def slug(query):
    return re.sub(r"[^a-z0-9]+", "-", query.lower()).strip("-")


def page_has_next(doc, page):
    for link in doc.all("a"):
        href = html.unescape(link.attrs.get("href", ""))
        if link.attrs.get("rel") == "next" or re.search(r"(?:[?&]page=|/page/?|(?:^|/)index-)" + str(page + 1) + r"(?=$|[&#/.])", href):
            return True
    return False


def search(source, args, fetch, key=""):
    page = max(1, args.page)
    query = args.query.strip()
    records, notice, more = [], "", False
    if source == "wallpaperscom":
        headers = {"X-API-Key": key} if key else {}
        topic = slug(query) or "desktop"
        data = fetch("https://wallpapers.com/api/v1/keyword/" + quote(topic) + "?limit=60", headers=headers, ttl=3600)
        rows = data.get("items", [])
        for row in rows[(page - 1) * 24:page * 24]:
            records.append(record(source, row["id"], row.get("title", ""), row.get("url", ""), row.get("thumb", ""),
                                  row.get("high") or row.get("webp", "")))
        more = page * 24 < len(rows)
        notice = "Tot 60 resultaten per onderwerp · Wallpapers.com"
    elif source == "pexels":
        params = dict(page=page, per_page=24, orientation="landscape")
        params["query"] = query or "wallpaper"
        if args.color: params["color"] = "#" + args.color.lstrip("#")
        if getattr(args, "size", ""): params["size"] = args.size
        data = fetch("https://api.pexels.com/v1/search?" + urlencode(params), headers={"Authorization": key}, ttl=3600)
        for row in data.get("photos", []):
            item = record(source, row["id"], row.get("alt") or "Pexels " + str(row["id"]), row.get("url", ""),
                          row.get("src", {}).get("large", ""), row.get("src", {}).get("original", ""))
            item.update(uploader=row.get("photographer", ""), resolution=dimension(row.get("width"), row.get("height")))
            records.append(item)
        more = bool(data.get("next_page"))
        notice = "Foto’s van Pexels · fotograaf en bron bij elke afbeelding"
    elif source == "pixabay":
        params = dict(key=key, q=(query or "wallpaper")[:100], page=page, per_page=24, orientation="horizontal",
                      image_type="all", safesearch="true" if getattr(args, "purity", "100") == "100" else "false",
                      order="latest" if getattr(args, "sort", "") == "date_added" else "popular")
        if getattr(args, "category", "") in PIXABAY_CATEGORIES: params["category"] = args.category
        minimum = re.fullmatch(r"([0-9]{2,5})[x×]([0-9]{2,5})", getattr(args, "atleast", "").strip())
        if minimum: params.update(min_width=int(minimum[1]), min_height=int(minimum[2]))
        # Pixabay accepts named colours, unlike Wallhaven/Pexels' hex values.
        if args.color:
            names = dict(cc0000="red", ff6600="orange", ffcc33="yellow", **{"77cc33":"green", "669900":"green", "66cccc":"turquoise", "0099cc":"blue", "0066cc":"blue", "333399":"blue", "663399":"lilac", "993399":"lilac", "ea4c88":"pink", "999999":"gray"})
            if args.color in names: params["colors"] = names[args.color]
        data = fetch("https://pixabay.com/api/?" + urlencode(params), ttl=86400)
        limited = False
        for row in data.get("hits", []):
            full = row.get("imageURL") or row.get("fullHDURL") or row.get("largeImageURL", "")
            item = record(source, row["id"], row.get("tags") or "Pixabay " + str(row["id"]), row.get("pageURL", ""),
                          row.get("webformatURL", ""), full)
            item.update(tag_names=[part.strip() for part in row.get("tags", "").split(",") if part.strip()],
                        uploader=row.get("user", ""), resolution=dimension(row.get("imageWidth"), row.get("imageHeight")))
            if not row.get("imageURL") and not row.get("fullHDURL"):
                limited = True
                item["resolution"] = "Max. 1280 px via deze API-sleutel"
            records.append(item)
        more = page * 24 < min(500, data.get("totalHits", 0))
        notice = "Pixabay · origineel/Full HD vereist volledige API-toegang" if limited else "Foto’s van Pixabay"
    elif source == "alphacoders":
        url = "https://alphacoders.com/" + (quote(slug(query)) + "-wallpapers" if query else "resolution/4k-wallpapers") + "?" + urlencode({"page": page})
        body = fetch(url, as_json=False)
        doc = Document(body).root
        downloads = {m[1]: (m[0], m[2]) for m in re.findall(r"downloadContentModal\(['\"](images[0-9]?)['\"],\s*([0-9]+),\s*['\"]([a-z0-9]+)['\"]", body)}
        seen = set()
        for image in doc.all("img"):
            thumb = image.attrs.get("src", "")
            match = re.search(r"/([0-9]+)/thumbbig-([0-9]+)\.[a-z0-9]+", thumb)
            if not match or match[2] in seen: continue
            seen.add(match[2])
            server, ext = downloads.get(match[2], ("", ""))
            full = f"https://{server}.alphacoders.com/{match[1]}/{match[2]}.{ext}" if server and ext else ""
            records.append(record(source, match[2], image.attrs.get("alt", ""), "https://wall.alphacoders.com/big.php?i=" + match[2], thumb, full))
        more = page_has_next(doc, page) or (bool(records) and "loadNextPage" in body)
        notice = "Alpha Coders · openbare websitebron"
    elif source == "wallpaperscraft":
        url = "https://wallpaperscraft.com/search/?" + urlencode({"query": query, "page": page}) if query else f"https://wallpaperscraft.com/all/page{page}"
        doc = Document(fetch(url, as_json=False)).root
        for link in doc.all("a", "wallpapers__link"):
            image = next(link.all("img"), None)
            if image is None: continue
            href = urljoin("https://wallpaperscraft.com", link.attrs.get("href", ""))
            records.append(record(source, href.rsplit("/", 1)[-1], image.attrs.get("alt", "").removeprefix("Preview wallpaper "),
                                  href, image.attrs.get("src", "")))
        more = page_has_next(doc, page)
        notice = "WallpapersCraft · openbare websitebron"
    elif source == "backiee":
        if not query:
            params = dict(action="paging_list", list_type="latest", page=page - 1, page_size=24, category="all",
                          is_ai="no" if getattr(args, "exclude_ai", False) else "all", sort_by="popularity", status="active", args="")
            params.update({"4k": "false", "5k": "false", "8k": "false"})
            data = fetch("https://backiee.com/api/wallpaper/list.php?" + urlencode(params))
            rows = data if isinstance(data, list) else []
            for row in rows:
                if row.get("PhotoPrivate") or row.get("Adult"): continue
                item = record(source, row["ID"], row.get("Title", ""), row.get("WallpaperUrl", ""),
                              row.get("MediumPhotoUrl") or row.get("MiniPhotoUrl", ""), row.get("FullPhotoUrl", ""))
                item.update(resolution=row.get("Resolution", ""), tag_names=[row["ThemeCat"]] if row.get("ThemeCat") else [])
                item["is_ai"] = is_ai(row)
                records.append(item)
            more = len(rows) == 24
        else:
            doc = Document(fetch("https://backiee.com/search/" + quote(query, safe="") + "?" + urlencode({"page": page}), as_json=False)).root
            seen = set()
            for link in doc.all("a", "wall-link"):
                href = link.attrs.get("href", "")
                match = re.search(r"/wallpaper/[^/]+/([0-9]+)", href)
                image = next(link.all("img"), None)
                if not match or image is None or match[1] in seen: continue
                seen.add(match[1])
                records.append(record(source, match[1], image.attrs.get("alt", "").removesuffix(" wallpaper"),
                                      href, image.attrs.get("src", "")))
            more = page_has_next(doc, page)
        notice = "backiee · openbare websitebron"
    elif source == "goodfon":
        url = "https://www.goodfon.com/search/?" + urlencode(dict(q=query, page=page)) if query else ("https://www.goodfon.com/" if page == 1 else f"https://www.goodfon.com/index-{page}.html")
        doc = Document(fetch(url, as_json=False)).root
        for tile in doc.all("div", "wallpapers__item__wall"):
            image = next(tile.all("img", "wallpapers__item__img"), None)
            if image is None: continue
            link = image.parent
            href = urljoin(url, link.attrs.get("href", ""))
            if not re.search(r"/wallpaper-[^/]+\.html$", urlparse(href).path): continue
            item = record(source, href, image.attrs.get("alt") or link.attrs.get("title", ""), href, urljoin(url, image.attrs.get("src", "")))
            size = next(tile.all("div", "wallpapers__item__size"), None)
            match = re.search(r"([0-9]+)x([0-9]+)", size.text()) if size else None
            if match: item["resolution"] = dimension(match[1], match[2])
            author = next(tile.all("a", "wallpapers__item__user_block"), None)
            if author: item["uploader"] = author.attrs.get("title") or item["uploader"]
            item["is_ai"] = urlparse(href).path.startswith("/ai-art/")
            records.append(item)
        more = page_has_next(doc, page)
        notice = "GoodFon · originele wallpaper en brongegevens via de openbare website"
    elif source == "wallpaperswide":
        term = quote(query.lower(), safe="").replace("%20", "+")
        if query: url = f"https://wallpaperswide.com/tag/{term}.html" if page == 1 else f"https://wallpaperswide.com/tag/{term}/page/{page}"
        else: url = "https://wallpaperswide.com/" if page == 1 else f"https://wallpaperswide.com/page/{page}"
        try: body = fetch(url, as_json=False)
        except HTTPError as error:
            if error.code != 404: raise
            error.close()
            body = ""
        doc = Document(body).root
        for image in doc.all("img", "thumb_img"):
            link = image.parent
            href = urljoin(url, link.attrs.get("href", ""))
            if not re.search(r"/[^/]+-wallpapers\.html$", urlparse(href).path): continue
            name = re.split(r" (?:4K UHD|UltraHD|HD) Wallpaper", image.attrs.get("alt", ""))[0]
            records.append(record(source, href, name, href, urljoin(url, image.attrs.get("src", ""))))
        more = page_has_next(doc, page)
        notice = "WallpapersWide · zoeken op de eigen brontags · gepubliceerde HD-downloads"
    else:
        raise ValueError("Onbekende bron")
    # Preserve pagination even when a whole page consists of excluded labels.
    last_page = page + int(more and bool(records))
    if getattr(args, "exclude_ai", False): records = [item for item in records if not is_ai(item)]
    return dict(records=records, page=page, lastPage=last_page, notice=notice)


def details(item, fetch):
    source = item["source"]
    if source not in {"wallpaperscom", "alphacoders", "backiee", "wallpaperscraft", "goodfon", "wallpaperswide"}: return item
    body = fetch(item["url"], as_json=False, ttl=3600)
    doc = Document(body).root
    result = dict(item)
    result["tag_names"] = tags(doc) or item.get("tag_names", [])
    keywords = [tag.strip() for tag in meta(doc, "keywords").split(",") if tag.strip() and len(tag.strip()) < 80]
    if keywords and not result["tag_names"]: result["tag_names"] = keywords[:24]
    if source == "wallpaperscom":
        published = meta(doc, "og:image")
        if urlparse(published).hostname == "wallpapers.com" and urlparse(published).path.startswith("/images/hd/"):
            result["download_url"] = published
        author = next(doc.all("span", "cd-author-name"), None)
        if author: result["uploader"] = author.text()
        related = next(doc.all("section", "cd-rs-block"), None)
        if related:
            result["tag_names"] = list(dict.fromkeys(link.text().removesuffix(" Wallpapers") for link in related.all("a") if link.text()))[:24]
        attribution = next((node for node in doc.all("input") if node.attrs.get("id") == "cd-attribution"), None)
        if attribution: result["attribution"] = attribution.attrs.get("value", "")
    elif source == "alphacoders":
        match = re.search(r"downloadContentModal\(['\"](images[0-9]?)['\"],\s*" + re.escape(item["remote_id"]) + r",\s*['\"]([a-z0-9]+)['\"]", body)
        image = next((node for node in doc.all("img") if node.attrs.get("id") == "main-content"), None)
        if image and match:
            folder = urlparse(image.attrs.get("src", "")).path.split("/")[1]
            result["download_url"] = f"https://{match[1]}.alphacoders.com/{folder}/{item['remote_id']}.{match[2]}"
            result["name"] = image.attrs.get("title") or item["name"]
            result["resolution"] = dimension(image.attrs.get("width"), image.attrs.get("height"))
            # The head's keyword list also contains site-wide SEO terms. The
            # main image publishes its own tags/author before related images.
            for field, target in [("keywords", "tag_names"), ("author", "uploader")]:
                value = next((node.attrs.get("content", "") for node in doc.all("meta") if node.attrs.get("itemprop") == field), "")
                if value: result[target] = [part.strip() for part in value.split(",") if part.strip()] if field == "keywords" else value
    elif source == "wallpaperscraft":
        image_tags = next(doc.all("div", "wallpaper__tags"), None)
        if image_tags: result["tag_names"] = tags(image_tags)
        original = next((node for node in doc.all("a") if "Original Resolution:" in node.text()), None)
        image = next(doc.all("img", "wallpaper__image"), None)
        if original and image:
            match = re.search(r"([0-9]+)x([0-9]+)", original.attrs.get("href", ""))
            if match:
                result["download_url"] = re.sub(r"_[0-9]+x[0-9]+(?=\.[a-z]+$)", "_" + match[0], image.attrs["src"])
                result["resolution"] = dimension(match[1], match[2])
        for node in doc.all("div", "author__row"):
            text = node.text()
            if text.startswith("Author:"): result["uploader"] = text.removeprefix("Author:").strip()
            if text.startswith("License:"): result["license"] = text.removeprefix("License:").strip()
    elif source == "backiee":
        for node in doc.all("script"):
            if node.attrs.get("type") != "application/ld+json": continue
            try: data = json.loads("".join(node.parts))
            except ValueError: continue
            if isinstance(data, dict) and data.get("@type") == "ImageObject":
                # Use the published source, not the generic 5K/8K option list:
                # those options can exist in the markup but return 404.
                result["download_url"] = data.get("contentUrl") or data.get("url") or result.get("download_url", "")
                result["resolution"] = dimension(data.get("width"), data.get("height"))
                result["uploader"] = data.get("creditText", result["uploader"])
                result["license_url"] = data.get("license", "")
                result["tag_names"] = [part.strip() for part in str(data.get("keywords", "")).split(",") if part.strip()] or result["tag_names"]
                author = data.get("author", {})
                if isinstance(author, dict): result["uploader"] = author.get("name", result["uploader"])
    elif source == "goodfon":
        image_tags = next(doc.all("div", "wallpaper__tags"), None)
        if image_tags: result["tag_names"] = tags(image_tags)
        for node in doc.all("script"):
            if node.attrs.get("type") != "application/ld+json": continue
            try: data = json.loads("".join(node.parts))
            except ValueError: continue
            if not isinstance(data, dict) or data.get("@type") != "ImageObject": continue
            result["download_url"] = data.get("contentUrl", "")
            result["license_url"] = data.get("license", "")
            result["resolution"] = dimension(data.get("width"), data.get("height"))
            if data.get("keywords"):
                result["tag_names"] = [part.strip() for part in data["keywords"].split(",") if part.strip()][:24]
            creator = data.get("creator", {})
            if isinstance(creator, dict): result["uploader"] = creator.get("name", result["uploader"])
        if not result.get("download_url"): raise ValueError("De originele GoodFon-download ontbreekt op de bronpagina")
    elif source == "wallpaperswide":
        published = next((node for node in doc.all("a") if "contentUrl" in node.attrs.get("itemprop", "").split()), None)
        if not published or not re.search(r"/download/[^/]+-wallpaper-[0-9]+x[0-9]+\.[a-z]+$", published.attrs.get("href", "")):
            raise ValueError("De HD-download ontbreekt op de WallpapersWide-bronpagina")
        result["download_url"] = urljoin(item["url"], published.attrs["href"])
        author = next((node for node in doc.all("a") if node.attrs.get("rel") == "author"), None)
        if author: result["uploader"] = author.text().removeprefix("More wallpapers posted by ")
        result["tag_names"] = list(dict.fromkeys(node.text() for node in doc.all("a") if node.attrs.get("rel") == "tag" and "/tag/" in node.attrs.get("href", "")))[:24]
    result["details_ready"] = True
    return result
