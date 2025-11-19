SHELL := /bin/bash

# Directorio donde se ejecutarán todos los comandos
SRCDIR := src

NVCC := nvcc
PY := python3
NVCCFLAGS := -O3 -std=c++14
RUN_ARGS ?= 1048576 50 1

.PHONY: all build-cuda bench plot clean

.DEFAULT_GOAL := build-cuda

all: build-cuda bench plot
	@echo "[Makefile] Tarea 'all' completada: build-cuda, bench y plot"

build-cuda:
	@echo "[Makefile] Compilando CUDA en $(SRCDIR)"
	@cd $(SRCDIR) && \
	if [ -f case_converter_cuda.cu ]; then \
		$(NVCC) $(NVCCFLAGS) -o case_converter_cuda case_converter_cuda.cu || { echo 'Error al compilar CUDA'; exit 1; }; \
	else \
		echo 'No se encontró case_converter_cuda.cu en $(SRCDIR)'; exit 1; \
	fi

bench:
	@echo "[Makefile] Ejecutando benchmarks en $(SRCDIR)"
	@cd $(SRCDIR) && \
	if [ -f run_benchmarks.sh ]; then \
		chmod +x run_benchmarks.sh || true; \
		./run_benchmarks.sh; \
	else \
		echo 'No se encontró `run_benchmarks.sh` en $(SRCDIR)`'; exit 1; \
	fi

plot:
	@echo "[Makefile] Generando gráficas en $(SRCDIR)"
	@cd $(SRCDIR) && \
	if [ -f plot_performance.py ]; then \
		$(PY) plot_performance.py; \
	else \
		echo 'No se encontró `plot_performance.py` en $(SRCDIR)`'; exit 1; \
	fi

clean:
	@echo "[Makefile] Limpiando binarios generados en $(SRCDIR)"
	@cd $(SRCDIR) && { rm -f case_converter_cuda performance_results.csv || true; rm -rf performance_plots || true; }
	
