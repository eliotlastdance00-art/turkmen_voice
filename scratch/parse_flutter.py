import urllib.request
import json
req = urllib.request.urlopen("https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json")
data = json.loads(req.read())
print(data['current_release']['stable'])
for rel in data['releases']:
    if rel['hash'] == data['current_release']['stable']:
        print("Latest stable:", rel['version'])
