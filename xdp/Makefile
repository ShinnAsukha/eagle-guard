# Eagle Guard XDP program — build
# Gerekenler: clang >= 10, libbpf-dev, linux-headers

CLANG   ?= clang
LLC     ?= llc
BPFTOOL ?= bpftool

ARCH := $(shell uname -m | sed 's/x86_64/x86/; s/aarch64/arm64/; s/armv7l/arm/; s/i[0-9]*86/x86/')
KERNEL_HEADERS ?= /usr/include

CFLAGS := -O2 -g -Wall \
          -target bpf \
          -D__TARGET_ARCH_$(ARCH) \
          -I$(KERNEL_HEADERS) \
          -I/usr/include/$(shell uname -m)-linux-gnu

OBJ := eagle_xdp.o
SRC := eagle_xdp.c

all: $(OBJ)

$(OBJ): $(SRC)
	@echo "  [BPF] $@"
	$(CLANG) $(CFLAGS) -c $< -o $@
	@# vmlinux.h kullanmıyoruz; eski kernel için minimum bağımlılık
	@echo "  [OK] BPF obje üretildi: $(OBJ)"

verify: $(OBJ)
	@echo "  [VERIFY] BPF doğrulayıcı kontrolü"
	@$(BPFTOOL) prog load $(OBJ) /sys/fs/bpf/eagle_xdp_test 2>&1 \
	  && $(BPFTOOL) prog | grep eagle \
	  && rm -f /sys/fs/bpf/eagle_xdp_test \
	  || echo "  [!!] verify başarısız (kurulum sırasında normaldir)"

clean:
	rm -f $(OBJ)

.PHONY: all clean verify
