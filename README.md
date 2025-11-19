# Taller 3 - CUDA

Este repositorio contiene el código y scripts del Taller 3 (CE4302 - Arquitectura de Computadores). 
El `Makefile` en la raíz facilita compilar el binario CUDA, ejecutar los benchmarks y generar las gráficas.

Requisitos

- `nvcc` (CUDA Toolkit) disponible en el PATH.
- `python3` (>=3.7) y los paquetes Python usados por `plot_performance.py`.

## Instalación rápida (opcional):

Instalar CUDA en Linux Ubuntu

```bash
sudo apt install nvidia-cuda-toolkit
```

Instala las dependencias Python necesarias (si no las tienes)

```bash
python3 -m pip install --user pandas matplotlib seaborn numpy
```

## Uso del Makefile
Todos los comandos se deben ejecutar desde la raíz del repositorio (donde está el `Makefile`). El `Makefile` ejecuta sus scripts dentro del directorio `src`.

- Compilar el binario CUDA:

```bash
make build
```

- Ejecutar los benchmarks (ejecutará `src/run_benchmarks.sh`):

```bash
make bench
```

- Generar las gráficas a partir de `src/performance_results.csv` (usa `src/plot_performance.py`):

```bash
make plot
```

- Ejecutar todo (compila, corre benchmarks y genera gráficas):

```bash
make all
```

- Limpiar resultados y gráficos generados en `src`:

```bash
make clean
```

## Notas y detalles

- El ejecutable CUDA compilado se coloca en `src/case_converter_cuda`.
- Si quieres ejecutar manualmente el binario compilado:

```bash
./src/case_converter_cuda <size_bytes> <alpha_percent> <aligned_bool>
# ejemplo (1 MiB, 50% alpha, alineado):
./src/case_converter_cuda 1048576 50 1
```
