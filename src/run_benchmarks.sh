#!/bin/bash

# Nombre del ejecutable de tu programa CUDA
EXECUTABLE="./case_converter_cuda"
# Nombre del archivo de salida para los resultados
OUTPUT_FILE="performance_results.csv"

# --- RANGOS DE VALORES DEL TALLER ---

# SIZES (bytes): 50 valores diferentes, espaciados linealmente entre 10,000 y 500,000.
SIZES=( 10000 20000 30000 40000 50000 60000 70000 80000 90000 100000
110000 120000 130000 140000 150000 160000 170000 180000 190000 200000
210000 220000 230000 240000 250000 260000 270000 280000 290000 300000
310000 320000 330000 340000 350000 360000 370000 380000 390000 400000
410000 420000 430000 440000 450000 460000 470000 480000 490000 500000)

# ALINEAMIENTO: 2 valores (0 = No Alineado, 1 = Alineado)
ALIGNMENTS=(0 1)

# PORCENTAJES ALFABÉTICOS: 10 valores diferentes (0-100%)
ALPHA_PERCENTS=(0 10 20 30 40 50 60 70 80 90 100)

# Inicializar el archivo CSV con la cabecera
echo "Size_Bytes,Alpha_Percent,Aligned,Time_Serial_ms,Time_CUDA_ms" > $OUTPUT_FILE

echo "Iniciando mediciones..."

# Bucle para iterar sobre todos los parámetros
for size in "${SIZES[@]}"; do
    for align in "${ALIGNMENTS[@]}"; do
        for alpha in "${ALPHA_PERCENTS[@]}"; do
            
            # Ejecución del programa y captura de la salida
            OUTPUT=$("$EXECUTABLE" "$size" "$alpha" "$align")
            
            # Extraer los tiempos de la salida (requiere alta precisión en la salida de C++)
            TIME_SERIAL=$(echo "$OUTPUT" | grep "Tiempo Serial" | awk '{print $3}')
            TIME_CUDA=$(echo "$OUTPUT" | grep "Tiempo CUDA" | awk '{print $3}')

            # Guardar el resultado en el archivo CSV
            echo "$size,$alpha,$align,$TIME_SERIAL,$TIME_CUDA" >> $OUTPUT_FILE
            # Imprimir el estado para seguimiento
            echo "Medición: Tamaño=$size, Alpha=$alpha%, Alineado=$align. T_Serial=$TIME_SERIAL ms, T_CUDA=$TIME_CUDA ms"
        done
    done
done

echo "Mediciones completadas. Resultados guardados en $OUTPUT_FILE"