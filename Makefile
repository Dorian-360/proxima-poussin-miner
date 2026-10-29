# Proxima Poussin Miner — ProxiChorizo 0.5.8 modifie (voir MODIFICATIONS.md, LICENSE, NOTICE)
NVCC ?= nvcc
# RTX 20xx (sm_75), CMP/A100 (sm_80), RTX 30xx (sm_86), RTX 40xx (sm_89), RTX 50xx (sm_120), + PTX for newer cards
ARCHS ?= -gencode arch=compute_75,code=sm_75 -gencode arch=compute_80,code=sm_80 -gencode arch=compute_86,code=sm_86 \
         -gencode arch=compute_89,code=sm_89 -gencode arch=compute_120,code=sm_120 -gencode arch=compute_120,code=compute_120
proxima-poussin-miner: proxima-poussin-miner.cu proxima-poussin-miner_device.cuh platform_profiles.h
	$(NVCC) -O3 -std=c++17 $(ARCHS) -o $@ proxima-poussin-miner.cu -lpthread -ldl
test: proxima-poussin-miner
	./proxima-poussin-miner --selftest vectors.json && ./proxima-poussin-miner --fetest && ./proxima-poussin-miner --verify
clean:
	rm -f proxima-poussin-miner
# RTX 50xx only (faster build)
sm120:
	$(MAKE) proxima-poussin-miner ARCHS="-gencode arch=compute_120,code=sm_120"
.PHONY: test clean sm120
