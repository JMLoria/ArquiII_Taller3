import pandas as pd
import matplotlib.pyplot as plt
import os
import sys

# --- Configuración ---
SRC_DIR = os.path.dirname(os.path.abspath(__file__))
INPUT_CSV = os.path.join(SRC_DIR, 'performance_results.csv') # Asegúrate de que el nombre coincida con el OUTPUT_FILE de tu script bash
OUTPUT_DIR = os.path.join(SRC_DIR, 'performance_plots')

# Verificar que el archivo de entrada existe
if not os.path.exists(INPUT_CSV):
    print(f"Error: No se encontró el archivo CSV de entrada '{INPUT_CSV}'.")
    sys.exit(1)

# Crear el directorio de salida si no existe
if not os.path.exists(OUTPUT_DIR):
    os.makedirs(OUTPUT_DIR)
    print(f"Carpeta '{OUTPUT_DIR}' creada.")

print(f"Cargando datos desde '{INPUT_CSV}'...")

# Cargar el CSV
# Asegurarse de que las columnas numéricas se carguen correctamente, especialmente Time_Serial_ms
try:
    df = pd.read_csv(INPUT_CSV)
    # Convertir a float por si acaso, especialmente Time_Serial_ms
    df['Time_Serial_ms'] = pd.to_numeric(df['Time_Serial_ms'], errors='coerce')
    df['Time_CUDA_ms'] = pd.to_numeric(df['Time_CUDA_ms'], errors='coerce')
    df.dropna(inplace=True)
except Exception as e:
    print(f"Error al leer o procesar el CSV: {e}")
    sys.exit(1)

# --- Gráfico 1: Comparación de Desempeño vs. Tamaño (Efecto Principal) ---

# Filtrar para un porcentaje alfabético fijo (ej. 50%)
df_fixed_alpha = df[df['Alpha_Percent'] == 50]

plt.figure(figsize=(12, 6))

# Tiempos Seriales (promedio de alineamientos 0 y 1, que deberían ser casi iguales)
serial_avg = df_fixed_alpha.groupby('Size_Bytes')['Time_Serial_ms'].mean().reset_index()
plt.plot(serial_avg['Size_Bytes'], serial_avg['Time_Serial_ms'], 
         label='Serial (Promedio)', color='gray', linestyle='-')

# Tiempos CUDA por alineamiento
df_cuda_aligned = df_fixed_alpha[df_fixed_alpha['Aligned'] == 1]
df_cuda_nonaligned = df_fixed_alpha[df_fixed_alpha['Aligned'] == 0]

plt.plot(df_cuda_aligned['Size_Bytes'], df_cuda_aligned['Time_CUDA_ms'], 
         label='CUDA (Alineado)', color='blue', linestyle='--')
plt.plot(df_cuda_nonaligned['Size_Bytes'], df_cuda_nonaligned['Time_CUDA_ms'], 
         label='CUDA (No Alineado)', color='red', linestyle=':')

plt.xscale('log') # Escala logarítmica para mejor visualización de un rango amplio de tamaños
plt.xlabel('Tamaño de Cadena (bytes, Escala Logarítmica)')
plt.ylabel('Tiempo de Ejecución (ms)')
plt.title('Gráfico 1: Comparación de Desempeño vs. Tamaño (Alpha 50%)')
plt.legend()
plt.grid(True, which="both", ls="--", alpha=0.7)

# Guardar Gráfico 1
plt.savefig(os.path.join(OUTPUT_DIR, '1 - Rendimiento vs Size.png'))
plt.close()
print("Gráfico 1 generado: 1 - Rendimiento vs Size.png")

# --- Gráfico 2: Efecto del Porcentaje Alfabético en CUDA vs. Serial (Tamaño Fijo) ---

# Filtrar para un tamaño fijo (ej. el máximo o un punto intermedio)
fixed_size = df['Size_Bytes'].max() 
df_fixed_size = df[df['Size_Bytes'] == fixed_size]

plt.figure(figsize=(12, 6))

# Tiempos Seriales (promedio)
serial_alpha_avg = df_fixed_size.groupby('Alpha_Percent')['Time_Serial_ms'].mean().reset_index()
plt.plot(serial_alpha_avg['Alpha_Percent'], serial_alpha_avg['Time_Serial_ms'], 
         label='Serial (Promedio)', color='gray', marker='o')

# Tiempos CUDA (Alineado)
cuda_alpha_aligned = df_fixed_size[df_fixed_size['Aligned'] == 1]
plt.plot(cuda_alpha_aligned['Alpha_Percent'], cuda_alpha_aligned['Time_CUDA_ms'], 
         label='CUDA (Alineado)', color='blue', marker='s')

plt.xlabel('Porcentaje de Caracteres Alfabéticos (%)')
plt.ylabel('Tiempo de Ejecución (ms)')
plt.title(f'Gráfico 2: Efecto del Porcentaje Alfabético (Tamaño Fijo: {fixed_size} bytes)')
plt.legend()
plt.grid(True, ls="--", alpha=0.7)

# Guardar Gráfico 2
plt.savefig(os.path.join(OUTPUT_DIR, '2 - Efecto Alpha Percent.png'))
plt.close()
print("Gráfico 2 generado: 2 - Efecto Alpha Percent.png")

# --- Gráfico 3: Análisis de Aceleración (Speedup) vs. Tamaño ---

# Calcular Speedup (Tiempo Serial / Tiempo CUDA)
# Usaremos los datos filtrados de Alpha=50% para mayor claridad
df_speedup = df_fixed_alpha.copy()

# Calcular Speedup para alineado y no alineado
df_speedup['Speedup_A'] = df_speedup.apply(lambda row: 
    row['Time_Serial_ms'] / df_speedup[(df_speedup['Size_Bytes'] == row['Size_Bytes']) & (df_speedup['Aligned'] == 1)]['Time_CUDA_ms'].iloc[0], axis=1)

df_speedup['Speedup_NA'] = df_speedup.apply(lambda row: 
    row['Time_Serial_ms'] / df_speedup[(df_speedup['Size_Bytes'] == row['Size_Bytes']) & (df_speedup['Aligned'] == 0)]['Time_CUDA_ms'].iloc[0], axis=1)

plt.figure(figsize=(12, 6))

plt.plot(df_speedup[df_speedup['Aligned'] == 1]['Size_Bytes'], df_speedup[df_speedup['Aligned'] == 1]['Speedup_A'], 
         label='Speedup (Alineado)', color='green', marker='^')
plt.plot(df_speedup[df_speedup['Aligned'] == 0]['Size_Bytes'], df_speedup[df_speedup['Aligned'] == 0]['Speedup_NA'], 
         label='Speedup (No Alineado)', color='orange', marker='v')

plt.axhline(1, color='red', linestyle='--', linewidth=0.8, label='Speedup = 1 (Punto de Equilibrio)')
plt.xscale('log')
plt.xlabel('Tamaño de Cadena (bytes, Escala Logarítmica)')
plt.ylabel('Aceleración (Speedup)')
plt.title('Gráfico 3: Aceleración (Speedup) CUDA vs. Serial (Alpha 50%)')
plt.legend()
plt.grid(True, which="both", ls="--", alpha=0.7)

# Guardar Gráfico 3
plt.savefig(os.path.join(OUTPUT_DIR, '3 - Speedup vs Size.png'))
plt.close()
print("Gráfico 3 generado: 3 - Speedup vs Size.png")

print(f"\nProceso finalizado. Las gráficas se encuentran en la carpeta '{OUTPUT_DIR}'.")