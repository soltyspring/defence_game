import ctypes as c,sys
from ctypes import wintypes as w
sys.stdout.reconfigure(encoding='utf-8', errors='replace')
k=c.WinDLL('kernel32',use_last_error=True)
k.AttachConsole.argtypes=[w.DWORD];k.AttachConsole.restype=w.BOOL
k.CreateFileW.argtypes=[w.LPCWSTR,w.DWORD,w.DWORD,c.c_void_p,w.DWORD,w.DWORD,w.HANDLE];k.CreateFileW.restype=w.HANDLE
class COORD(c.Structure): _fields_=[('X',w.SHORT),('Y',w.SHORT)]
class RECT(c.Structure): _fields_=[('Left',w.SHORT),('Top',w.SHORT),('Right',w.SHORT),('Bottom',w.SHORT)]
class INFO(c.Structure): _fields_=[('size',COORD),('cursor',COORD),('attr',w.WORD),('window',RECT),('max',COORD)]
k.FreeConsole()
if not k.AttachConsole(int(sys.argv[1])): raise c.WinError(c.get_last_error())
h=k.CreateFileW('CONOUT$',0x80000000,3,None,3,0,None); i=INFO()
if not k.GetConsoleScreenBufferInfo(h,c.byref(i)): raise c.WinError(c.get_last_error())
print('size',i.size.X,i.size.Y,'cursor',i.cursor.X,i.cursor.Y,'window',i.window.Top,i.window.Bottom)
for y in range(max(i.window.Top,i.window.Bottom-12),i.window.Bottom+1):
 buf=c.create_unicode_buffer(i.size.X+1);n=w.DWORD(); k.ReadConsoleOutputCharacterW(h,buf,i.size.X,COORD(0,y),c.byref(n));print(buf.value.rstrip())
k.FreeConsole()
