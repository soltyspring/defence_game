"""Write to a specifically observed existing Windows console; never restart it.

Use only after observing the exact role's empty idle input prompt.  Does not
activate windows, clear input, send interrupts, or handle authentication.
"""
import argparse
import ctypes as c
from ctypes import wintypes as w
import json
from pathlib import Path
import time


class Key(c.Structure):
    _fields_ = [('down', w.BOOL), ('repeat', w.WORD), ('vk', w.WORD),
                ('scan', w.WORD), ('char', w.WCHAR), ('control', w.DWORD)]


class Event(c.Union):
    _fields_ = [('key', Key), ('pad', c.c_byte * 16)]


class Record(c.Structure):
    _fields_ = [('kind', w.WORD), ('event', Event)]


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--pid', type=int, required=True)
    p.add_argument('--text-file', type=Path, required=True)
    p.add_argument('--result', type=Path, required=True)
    p.add_argument('--checkpoint-only', action='store_true')
    args = p.parse_args()
    quota_dir = Path(__file__).resolve().parent / '.runtime/quota'
    if (quota_dir / 'triggered.json').exists() and not args.checkpoint_only:
        raise SystemExit('97% checkpoint is active: new work dispatch forbidden.')
    usage_path = quota_dir / 'usage.json'
    if not args.checkpoint_only and usage_path.exists() and json.loads(usage_path.read_text(encoding='utf-8-sig')).get('percent', 0) >= 97:
        raise SystemExit('Observed usage >=97%: save/checkpoint and await login.')
    text = args.text_file.read_text(encoding='utf-8-sig').strip()
    if not text or '\n' in text or '\r' in text:
        raise SystemExit('Requires one nonempty observed CLI prompt line')
    k = c.WinDLL('kernel32', use_last_error=True)
    k.AttachConsole.argtypes = [w.DWORD]
    k.AttachConsole.restype = w.BOOL
    k.CreateFileW.argtypes = [w.LPCWSTR, w.DWORD, w.DWORD, c.c_void_p, w.DWORD, w.DWORD, w.HANDLE]
    k.CreateFileW.restype = w.HANDLE
    k.WriteConsoleInputW.argtypes = [w.HANDLE, c.POINTER(Record), w.DWORD, c.POINTER(w.DWORD)]
    k.WriteConsoleInputW.restype = w.BOOL
    k.CloseHandle.argtypes = [w.HANDLE]
    k.FreeConsole()
    outcome = {'pid': args.pid, 'text_file': str(args.text_file), 'delivery': 'FAILED'}
    handle = None
    try:
        if not k.AttachConsole(args.pid):
            raise c.WinError(c.get_last_error())
        handle = k.CreateFileW('CONIN$', 0xC0000000, 3, None, 3, 0, None)
        if handle == c.c_void_p(-1).value:
            raise c.WinError(c.get_last_error())
        def send(chars):
            records = []
            for char in chars:
                for down in (1, 0):
                    rec = Record()
                    rec.kind = 1
                    rec.event.key = Key(down, 1, 13 if char == '\r' else 0,
                                        28 if char == '\r' else 0, char, 0)
                    records.append(rec)
            array = (Record * len(records))(*records)
            written = w.DWORD()
            if not k.WriteConsoleInputW(handle, array, len(records), c.byref(written)):
                raise c.WinError(c.get_last_error())
            if written.value != len(records):
                raise RuntimeError(f'Partial input write: {written.value}/{len(records)}')
        send(text)
        time.sleep(0.3)
        send('\r')
        outcome['delivery'] = 'INPUT_WRITTEN_REQUIRES_READBACK'
        outcome['characters'] = len(text)
    except Exception as error:
        outcome['error'] = str(error)
    finally:
        if handle and handle != c.c_void_p(-1).value:
            k.CloseHandle(handle)
        k.FreeConsole()
        args.result.parent.mkdir(parents=True, exist_ok=True)
        args.result.write_text(json.dumps(outcome, indent=2), encoding='utf-8')
    if outcome['delivery'] == 'FAILED':
        raise SystemExit(1)


if __name__ == '__main__':
    main()

