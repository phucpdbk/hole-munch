"""Fetch only the Android debug template from Godot's official release archive.

Uses HTTP ranges instead of downloading the entire >1 GB multi-platform archive.
zipfile verifies the entry CRC. The version must match the installed Godot engine.
"""
import io
import json
import pathlib
import urllib.request
import zipfile
from concurrent.futures import ThreadPoolExecutor

VERSION = "4.7.1-stable"
ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "builds" / "templates"


def request(url, headers=None):
    return urllib.request.urlopen(urllib.request.Request(url, headers={
        "User-Agent": "HoleMunch-Godot-build", **(headers or {})}), timeout=180)


class RemoteArchive(io.RawIOBase):
    def __init__(self, url, size):
        self.url, self.size, self.position = url, size, 0
        self.cache_start, self.cache = -1, b""

    def seekable(self):
        return True

    def readable(self):
        return True

    def tell(self):
        return self.position

    def seek(self, offset, whence=0):
        self.position = offset if whence == 0 else self.position + offset if whence == 1 else self.size + offset
        return self.position

    def read(self, size=-1):
        if size < 0:
            size = self.size - self.position
        size = min(size, self.size - self.position)
        if size <= 0:
            return b""
        start = self.position
        end = start + size
        if not (self.cache_start <= start and end <= self.cache_start + len(self.cache)):
            # Fetch a small read-ahead for local ZIP headers and the central directory.
            fetch_end = min(self.size, max(end, start + 262144))
            if fetch_end-start > 8*1048576:
                chunks = [(pos, min(pos+4*1048576, fetch_end)) for pos in range(start, fetch_end, 4*1048576)]
                with ThreadPoolExecutor(max_workers=6) as pool:
                    self.cache = b"".join(pool.map(lambda bounds: self.fetch(*bounds), chunks))
                self.cache_start = start
            else:
                self.cache = self.fetch(start, fetch_end)
                self.cache_start = start
            if len(self.cache) != fetch_end - start:
                raise RuntimeError("Incomplete template download")
        self.position = end
        return self.cache[start-self.cache_start:end-self.cache_start]

    def fetch(self, start, end):
        with request(self.url + f"?range_start={start}", {"Range": f"bytes={start}-{end - 1}"}) as response:
            if response.status != 206:
                raise RuntimeError("Server did not honor HTTP ranges; refusing a full archive download")
            expected = f"bytes {start}-{end - 1}/{self.size}"
            if response.headers.get("Content-Range") != expected:
                raise RuntimeError("Unexpected HTTP range response")
            data = response.read()
        if len(data) != end-start:
            raise RuntimeError("Incomplete range")
        if len(data)>1048576:
            print(f"Received {len(data)/1048576:.0f} MiB segment", flush=True)
        return data


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    with request(f"https://api.github.com/repos/godotengine/godot-builds/releases/tags/{VERSION}") as response:
        release = json.load(response)
    asset = next(a for a in release["assets"] if a["name"] == f"Godot_v{VERSION}_export_templates.tpz")
    with zipfile.ZipFile(RemoteArchive(asset["browser_download_url"], asset["size"])) as archive:
        entry = next(n for n in archive.namelist() if n.endswith("/android_debug.apk"))
        print(f"Downloading {entry} ({archive.getinfo(entry).compress_size / 1048576:.1f} MiB compressed)", flush=True)
        content = archive.read(entry)
    target = OUT / "android_debug.apk"
    target.write_bytes(content)
    print(f"Saved {target} ({len(content) / 1048576:.1f} MiB)", flush=True)
