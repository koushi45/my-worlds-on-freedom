"""Read Windows GPU Process Memory performance counters without dependencies."""
import ctypes
from ctypes import wintypes

class ValueUnion(ctypes.Union):
    _fields_=[("large",ctypes.c_longlong),("double",ctypes.c_double),("long",wintypes.LONG)]
class FormattedValue(ctypes.Structure):
    _fields_=[("status",wintypes.DWORD),("value",ValueUnion)]
class Item(ctypes.Structure):
    _fields_=[("name",wintypes.LPWSTR),("formatted",FormattedValue)]

class GpuMemory:
    def __init__(self):
        self.api=ctypes.WinDLL("pdh")
        self.api.PdhOpenQueryW.argtypes=[wintypes.LPCWSTR,ctypes.c_size_t,ctypes.POINTER(wintypes.HANDLE)]
        self.api.PdhAddEnglishCounterW.argtypes=[wintypes.HANDLE,wintypes.LPCWSTR,ctypes.c_size_t,ctypes.POINTER(wintypes.HANDLE)]
        self.api.PdhCollectQueryData.argtypes=[wintypes.HANDLE]
        self.api.PdhGetFormattedCounterArrayW.argtypes=[wintypes.HANDLE,wintypes.DWORD,ctypes.POINTER(wintypes.DWORD),ctypes.POINTER(wintypes.DWORD),ctypes.c_void_p]
        self.api.PdhCloseQuery.argtypes=[wintypes.HANDLE]
        self.query=wintypes.HANDLE()
        self.counters={}
        if self.api.PdhOpenQueryW(None,0,ctypes.byref(self.query)) != 0:return
        for name,label in [("Dedicated Usage","dedicated"),("Shared Usage","shared")]:
            handle=wintypes.HANDLE()
            if self.api.PdhAddEnglishCounterW(self.query,rf"\GPU Process Memory(*)\{name}",0,ctypes.byref(handle))==0:
                self.counters[label]=handle
    def sample(self,pid):
        if not self.query or self.api.PdhCollectQueryData(self.query)!=0:return {}
        result={}
        for label,handle in self.counters.items():
            size=wintypes.DWORD();count=wintypes.DWORD()
            self.api.PdhGetFormattedCounterArrayW(handle,0x400,ctypes.byref(size),ctypes.byref(count),None)
            if size.value==0:continue
            buffer=ctypes.create_string_buffer(size.value)
            if self.api.PdhGetFormattedCounterArrayW(handle,0x400,ctypes.byref(size),ctypes.byref(count),buffer)!=0:continue
            items=ctypes.cast(buffer,ctypes.POINTER(Item))
            matched=[items[i].formatted.value.large for i in range(count.value) if items[i].name.startswith(f"pid_{pid}_") and items[i].formatted.status in [0,1]]
            if matched:result[label]=sum(matched)
        return result
    def close(self):
        if self.query:self.api.PdhCloseQuery(self.query)
