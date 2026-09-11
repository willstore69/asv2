#!/usr/bin/env python3
"""Sisipkan 3 inbound XHTTP ke config xray live (satu kali, tanpa hapus user)."""
import uuid, sys
p = "/usr/local/etc/xray/config.json"
s = open(p).read()
if '"tag":"trojan-xhttp"' in s:
    print("SKIP: sudah ada")
    sys.exit(0)
seed = str(uuid.uuid4())
blocks = (
    ',\n'
    '    {"tag":"vmess-xhttp","listen":"127.0.0.1","port":3014,"protocol":"vmess",'
    '"settings":{"clients":[{"id":"' + seed + '","alterId":0}\n#vmessxhttp\n]},'
    '"streamSettings":{"network":"xhttp","xhttpSettings":{"path":"/vmess-x","mode":"auto"}}},\n'
    '    {"tag":"vless-xhttp","listen":"127.0.0.1","port":3015,"protocol":"vless",'
    '"settings":{"clients":[{"id":"' + seed + '"}\n#vlessxhttp\n],"decryption":"none"},'
    '"streamSettings":{"network":"xhttp","xhttpSettings":{"path":"/vless-x","mode":"auto"}}},\n'
    '    {"tag":"trojan-xhttp","listen":"127.0.0.1","port":3016,"protocol":"trojan",'
    '"settings":{"clients":[{"password":"' + seed + '"}\n#trojanxhttp\n]},'
    '"streamSettings":{"network":"xhttp","xhttpSettings":{"path":"/trojan-x","mode":"auto"}}}'
)
anchor = '}}\n  ],\n  "outbounds"'
assert s.count(anchor) == 1, "anchor tidak unik: %d" % s.count(anchor)
s = s.replace(anchor, '}}' + blocks + '\n  ],\n  "outbounds"')
open(p, "w").write(s)
print("INSERT OK")
