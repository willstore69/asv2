CXX ?= c++
CXXFLAGS ?= -std=c++17 -O2 -Wall -Wextra -pthread
SRC = src/util.cpp src/license.cpp src/ssh.cpp src/grpc.cpp src/xray_api.cpp src/xray.cpp src/l2tp.cpp src/monitor.cpp src/policy.cpp src/netsetup.cpp src/paths.cpp src/hcr.cpp src/argo.cpp src/backup.cpp src/api.cpp src/bot.cpp src/main.cpp
WS_SRC = src/util.cpp src/paths.cpp src/procacct.cpp src/ws.cpp src/ws_main.cpp
BIN = asv2
WS_BIN = asv2-ws

all: $(BIN) $(WS_BIN)

$(BIN): $(SRC)
	$(CXX) $(CXXFLAGS) -o $@ $(SRC)

$(WS_BIN): $(WS_SRC)
	$(CXX) $(CXXFLAGS) -o $@ $(WS_SRC)

clean:
	rm -f $(BIN) $(WS_BIN)

# Rilis publik: build keras + strip + manifest checksum.
# Wajib dari tree bersih. Protektor (VMProtect, lihat docs/PROTECTION.md)
# dijalankan SETELAH target ini, terhadap biner hasil strip.
release: clean
	$(CXX) -std=c++17 -O2 -Wall -Wextra -pthread -fstack-protector-strong -D_FORTIFY_SOURCE=2 -fPIE -pie -s -o $(BIN) $(SRC)
	$(CXX) -std=c++17 -O2 -Wall -Wextra -pthread -fstack-protector-strong -D_FORTIFY_SOURCE=2 -fPIE -pie -s -o $(WS_BIN) $(WS_SRC)
	sha256sum $(BIN) $(WS_BIN) > CHECKSUMS.sha256
	cat CHECKSUMS.sha256

# Rilis terobfuscasi O-MVLL (butuh clang-19 + plugin ~/o-mvll, lihat docs/PROTECTION.md).
# Hanya fungsi lisensi yang diobfuscate berat (obf/omvll.py); hot path utuh.
# Override: make obf OMVLL_SO=/path/libOMVLL.so CLANGXX=clang++-19
CLANGXX ?= clang++-19
OMVLL_SO ?= /root/o-mvll/build/libOMVLL.so
OMVLL_CONF ?= $(CURDIR)/obf/asv2_obf.py
obf: clean
	OMVLL_CONFIG=$(OMVLL_CONF) $(CLANGXX) -std=c++17 -O2 -Wall -Wextra -pthread -fstack-protector-strong -D_FORTIFY_SOURCE=2 -fPIE -pie -s -fpass-plugin=$(OMVLL_SO) -o $(BIN) $(SRC)
	$(CXX) -std=c++17 -O2 -Wall -Wextra -pthread -fstack-protector-strong -D_FORTIFY_SOURCE=2 -fPIE -pie -s -o $(WS_BIN) $(WS_SRC)
	sha256sum $(BIN) $(WS_BIN) > CHECKSUMS.sha256
	cat CHECKSUMS.sha256

install: all
	install -m 755 asv2 /usr/local/bin/asv2
	install -m 755 asv2-ws /usr/local/bin/asv2-ws
	@echo "Link kompatibel v1 (add-ssh, add-vmess, ...):"
	@for n in add-ssh del-ssh renew-ssh trial-ssh lock-ssh unlock-ssh ban-ssh unban-ssh cek cek-ssh cek-xray add-vmess del-vmess renew-vmess add-vless del-vless add-trojan del-trojan add-vmessgrpc add-vlessgrpc add-trojangrpc add-vmesstcp add-vlessxtls add-l2tp del-l2tp renew-l2tp autoban backup restore change-domain change-port change-uuid argo-setup; do ln -sf asv2 /usr/local/bin/$$n; done
	@echo OK

.PHONY: all clean install
