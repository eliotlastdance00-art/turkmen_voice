import urllib.request
import json
req = urllib.request.urlopen("https://pub.dev/api/packages/record")
data = json.loads(req.read())
print(data['latest']['pubspec']['environment'])
