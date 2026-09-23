import urllib.request
import json
req = urllib.request.urlopen("https://pub.dev/api/packages/record/versions/6.0.0")
data = json.loads(req.read())
print(data['pubspec']['environment'])
