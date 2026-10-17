"""Download the stock home screen package (lipstick-jolla-home-qt5) of a Sailfish OS release from Jolla's public
release repository, checked against the repository's sha256. Its files are Jolla's (proprietary): they go into out/
and are never committed (scripts/stock-base.sh unpacks them).

Usage: python3 stock.py VERSION OUTDIR      (writes OUTDIR/lipstick.rpm and OUTDIR/PACKAGE)
"""
import gzip
import hashlib
import re
import sys
import urllib.request
from pathlib import Path

PACKAGE = "lipstick-jolla-home-qt5"
version, out = sys.argv[1], Path(sys.argv[2])
if not re.fullmatch(r"\d+\.\d+\.\d+\.\d+", version):
    sys.exit(f"not a Sailfish OS version: {version}")
# the QML is the same for every architecture
repo = f"https://releases.jolla.com/releases/{version}/jolla/aarch64"


def fetch(url):
    with urllib.request.urlopen(url, timeout=60) as response:
        return response.read()


repomd = fetch(repo + "/repodata/repomd.xml").decode()
primary = re.search(r'<data type="primary">.*?<location href="([^"]+)"', repomd, re.S).group(1)
xml = gzip.decompress(fetch(repo + "/" + primary)).decode()
for package in re.findall(r"<package .*?</package>", xml, re.S):
    if re.search(r"<name>%s</name>" % PACKAGE, package):
        break
else:
    sys.exit(f"{PACKAGE} is not in Sailfish OS {version}'s repository")
href = re.search(r'<location href="([^"]+)"', package).group(1)
sha256 = re.search(r'<checksum type="sha256"[^>]*>([0-9a-f]{64})</checksum>', package).group(1)
data = fetch(repo + "/" + href)
if hashlib.sha256(data).hexdigest() != sha256:
    sys.exit(f"{href}: the download does not match the repository's sha256")
out.mkdir(parents=True, exist_ok=True)
(out / "lipstick.rpm").write_bytes(data)
(out / "PACKAGE").write_text(Path(href).name[:-len(".rpm")] + "\n")
print(Path(href).name)
