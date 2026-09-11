# Konfigurasi O-MVLL rilis asv2 — SELEKTIF.
# Prinsip: hanya fungsi lisensi yang diobfuscate berat (flatten + bcf +
# aritmetika); string dienkripsi global (URL lisensi, pesan, path).
# Hot path (gRPC, WS relay, monitor) TIDAK diobfuscate agar performa utuh.
import omvll
from functools import lru_cache

LICENSE_FUNCS = ("licenseCheck", "selfCheck", "myIp", "licenseClientName")

def _is_license(func: omvll.Function) -> bool:
    try:
        name = func.demangled_name or ""
    except Exception:
        name = ""
    if not name:
        try:
            name = func.name or ""
        except Exception:
            return False
    return any(k in name for k in LICENSE_FUNCS)


class Asv2Release(omvll.ObfuscationConfig):
    def __init__(self):
        super().__init__()

    def flatten_cfg(self, mod: omvll.Module, func: omvll.Function):
        return _is_license(func)

    def break_control_flow(self, mod: omvll.Module, func: omvll.Function):
        return _is_license(func)

    def obfuscate_arithmetic(self, mod: omvll.Module,
                             func: omvll.Function) -> omvll.ArithmeticOpt:
        return _is_license(func)

    def obfuscate_string(self, mod: omvll.Module, func: omvll.Function,
                         string: bytes):
        # Enkripsi semua string: URL lisensi, pesan error, path sensitif.
        # Transparan saat runtime (dekripsi otomatis).
        if not string:
            return False
        return omvll.StringEncOptGlobal()


@lru_cache(maxsize=1)
def omvll_get_config() -> omvll.ObfuscationConfig:
    return Asv2Release()
