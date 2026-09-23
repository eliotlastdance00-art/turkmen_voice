import urllib.request
import tarfile
import io

req = urllib.request.urlopen("https://pub.dev/packages/record_platform_interface/versions/7.0.0.tar.gz")
tar = tarfile.open(fileobj=io.BytesIO(req.read()), mode="r:gz")
for member in tar.getmembers():
    if 'encoder' in member.name.lower():
        print(member.name)
        f = tar.extractfile(member)
        print(f.read().decode('utf-8'))
