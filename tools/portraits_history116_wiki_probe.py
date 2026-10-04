from portraits_history116_more_refs import get
from urllib.parse import quote
import re,html
for name in ['古田重然','千葉親胤']:
    try:
        t=get('https://ja.wikipedia.org/wiki/'+quote(name)).decode()
        links=re.findall(r'href="([^"]+)"[^>]*class="mw-file-description"',t)
        print(name.encode('ascii','backslashreplace').decode(),[html.unescape(x) for x in links[:8]])
    except Exception as e:print(str(e))
