"""Check every ELF library in an APK/AAB for 16 KiB load-segment alignment.

This does not replace Play validation or testing on a 16 KiB Android device.
For APK ZIP alignment also run Android build-tools zipalign -c -P 16 -v 4.
"""
import struct
import sys
import zipfile


def check(path):
    count = 0
    with zipfile.ZipFile(path) as archive:
        for name in archive.namelist():
            if not name.endswith('.so'):
                continue
            blob = archive.read(name)
            if blob[:4] != b'\x7fELF' or blob[4] != 2 or blob[5] != 1:
                raise ValueError(f'{name}: expected little-endian ELF64')
            offset = struct.unpack_from('<Q', blob, 32)[0]
            size, entries = struct.unpack_from('<HH', blob, 54)
            segments = 0
            for index in range(entries):
                kind, _, file_offset, virtual, _, _, _, alignment = struct.unpack_from('<IIQQQQQQ', blob, offset + index * size)
                if kind == 1:
                    segments += 1
                    if alignment < 16384 or file_offset % 16384 != virtual % 16384:
                        raise ValueError(f'{name}: PT_LOAD not 16 KiB aligned')
            if not segments:
                raise ValueError(f'{name}: no load segments')
            count += 1
            print(f'PASS: {name} ({segments} load segments)')
    if not count:
        raise ValueError('No native libraries found')
    print(f'PASS: {count} native libraries support 16 KiB ELF alignment')


if __name__ == '__main__':
    check(sys.argv[1])
