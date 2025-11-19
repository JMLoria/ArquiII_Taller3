#include <iostream>
#include <vector>
#include <string>
#include <algorithm>
#include <cmath>
#include <chrono>
#include <cstring>
#include <cstdlib>
#include <ctime>
#include <iomanip>

// Función para verificar errores en llamadas a CUDA
#define CUDA_CHECK(call)                                                     \
    do                                                                       \
    {                                                                        \
        cudaError_t err = call;                                              \
        if (err != cudaSuccess)                                              \
        {                                                                    \
            std::cerr << "CUDA Error: " << cudaGetErrorString(err) << " at " \
                      << __FILE__ << ":" << __LINE__ << std::endl;           \
            exit(EXIT_FAILURE);                                              \
        }                                                                    \
    } while (0)

/**
 * @brief Genera una cadena de texto aleatoria con alineamiento y porcentaje de caracteres específicos.
 * @param size El tamaño de la cadena en bytes.
 * @param alpha_percent Porcentaje de caracteres que serán letras (0-100).
 * @param aligned Si es verdadero, usa posix_memalign para asegurar un alineamiento de 16 bytes.
 * @param data_buffer Puntero donde se almacenará la cadena generada.
 */
void generate_random_string(size_t size, int alpha_percent, bool aligned, char *&data_buffer)
{
    // Definimos el rango de caracteres
    const char *non_alpha_chars = "0123456789!@#$%^&*()-+= ";
    const size_t non_alpha_len = strlen(non_alpha_chars);
    // Usar rand() para evitar dependencias de <random> que pueden causar
    // problemas con ciertas versiones de nvcc y las cabeceras de libstdc++.
    // Asegúrese de llamar a `srand` en `main` una vez antes de generar datos.

    // Asignación de memoria con o sin alineamiento
    if (aligned)
    {
        // Asignación alineada a 16 bytes (común para optimización SIMD o bus de memoria)
        if (posix_memalign((void **)&data_buffer, 16, size) != 0)
        {
            std::cerr << "Error en posix_memalign" << std::endl;
            exit(EXIT_FAILURE);
        }
    }
    else
    {
        // Asignación no alineada
        data_buffer = (char *)malloc(size);
        if (data_buffer == nullptr)
        {
            std::cerr << "Error en malloc" << std::endl;
            exit(EXIT_FAILURE);
        }
    }

    // Llenar el buffer
    for (size_t i = 0; i < size; ++i)
    {
        if ((rand() % 100) < alpha_percent)
        {
            // Generar un caracter alfabético (minúscula o mayúscula)
            char base = (rand() % 2) ? 'A' : 'a';
            data_buffer[i] = base + (rand() % 26);
        }
        else
        {
            // Generar un caracter no alfabético
            data_buffer[i] = non_alpha_chars[rand() % non_alpha_len];
        }
    }
}

/**
 * @brief Algoritmo serial de conversión de mayúsculas y minúsculas.
 */
void case_converter_serial(char *data, size_t size)
{
    for (size_t i = 0; i < size; ++i)
    {
        char current_char = data[i];

        if (current_char >= 'a' && current_char <= 'z')
        {
            // Minúscula a Mayúscula: Restar 0x20
            data[i] = current_char - 0x20; // [cite: 23]
        }
        else if (current_char >= 'A' && current_char <= 'Z')
        {
            // Mayúscula a Minúscula: Sumar 0x20
            data[i] = current_char + 0x20; // [cite: 23]
        }
        // Si no es alfabético, se mantiene igual
    }
}

/**
 * @brief Kernel CUDA para la conversión paralela de mayúsculas/minúsculas.
 * Cada hilo procesa un único carácter.
 * @param data Puntero a la cadena de caracteres en la memoria de la GPU (Device).
 * @param size Tamaño total de la cadena.
 */
__global__ void case_converter_kernel(char *data, size_t size)
{
    // Calcular el índice global del hilo
    size_t idx = blockIdx.x * blockDim.x + threadIdx.x; // [cite: 15]

    // Solo procesar si el índice está dentro de los límites de la cadena
    if (idx < size)
    {
        char current_char = data[idx];

        if (current_char >= 'a' && current_char <= 'z')
        {
            // Minúscula a Mayúscula: Restar 0x20
            data[idx] = current_char - 0x20; // [cite: 23]
        }
        else if (current_char >= 'A' && current_char <= 'Z')
        {
            // Mayúscula a Minúscula: Sumar 0x20
            data[idx] = current_char + 0x20; // [cite: 23]
        }
    }
}

/**
 * @brief Función wrapper para la ejecución CUDA.
 */
double run_cuda(char *h_input, char *h_output, size_t size)
{
    // 1. Declaración de Punteros en el Device
    char *d_data; // Puntero a la memoria de la GPU

    // 2. Asignación de Memoria en la GPU (Device)
    // cudaMalloc: Asigna memoria en la GPU. Recibe la dirección del puntero del device y el tamaño. [cite: 16]
    CUDA_CHECK(cudaMalloc((void **)&d_data, size));

    // 3. Copia de Datos de Host a Device
    // cudaMemcpy: Copia datos del Host (CPU) al Device (GPU). [cite: 16]
    CUDA_CHECK(cudaMemcpy(d_data, h_input, size, cudaMemcpyHostToDevice));

    // 4. Configuración del Lanzamiento del Kernel
    int threads_per_block = 256;
    // Calcular el número de bloques necesario para cubrir todos los elementos
    int blocks_per_grid = (size + threads_per_block - 1) / threads_per_block;

    // Crear eventos para medir el tiempo
    cudaEvent_t start, stop;
    CUDA_CHECK(cudaEventCreate(&start));
    CUDA_CHECK(cudaEventCreate(&stop));

    // 5. Lanzamiento del Kernel y Medición de Tiempo
    CUDA_CHECK(cudaEventRecord(start, 0));
    // Ejecución del Kernel: <<<gridDim, blockDim>>>
    case_converter_kernel<<<blocks_per_grid, threads_per_block>>>(d_data, size); // [cite: 14]
    CUDA_CHECK(cudaGetLastError());                                              // Comprobar si hay errores en el kernel
    CUDA_CHECK(cudaEventRecord(stop, 0));

    // Esperar a que la GPU termine
    CUDA_CHECK(cudaEventSynchronize(stop));

    // 6. Copia de Resultados de Device a Host
    // Copia de vuelta al buffer de salida
    CUDA_CHECK(cudaMemcpy(h_output, d_data, size, cudaMemcpyDeviceToHost)); // [cite: 16]

    // 7. Liberación de Memoria del Device
    // cudaFree: Libera la memoria asignada en la GPU. [cite: 16]
    CUDA_CHECK(cudaFree(d_data));

    // Calcular el tiempo transcurrido
    float milliseconds = 0;
    CUDA_CHECK(cudaEventElapsedTime(&milliseconds, start, stop));

    // Limpiar eventos
    CUDA_CHECK(cudaEventDestroy(start));
    CUDA_CHECK(cudaEventDestroy(stop));

    return (double)milliseconds;
}

int main(int argc, char *argv[])
{
    // 1. Verificar Argumentos y Parsear (MANTENER ESTO)
    if (argc < 4) {
        std::cerr << "Uso: " << argv[0] << " <size_bytes> <alpha_percent> <aligned_bool>" << std::endl;
        return 1;
    }

    // Estas son las ÚNICAS declaraciones que deben existir para estas variables.
    size_t test_size = std::stoll(argv[1]);
    int test_alpha_percent = std::stoi(argv[2]);
    bool test_aligned = std::stoi(argv[3]) == 1;

    std::cout << "Iniciando prueba con Tamaño: " << test_size << " bytes, % Alfabético: " << test_alpha_percent << "%, Alineado: " << (test_aligned ? "Si" : "No") << std::endl;

    // Inicializar el generador de números aleatorios de C
    srand((unsigned)time(nullptr));

    // --- 1. Generar la Cadena Original ---
    char *h_original = nullptr;
    generate_random_string(test_size, test_alpha_percent, test_aligned, h_original);

    // --- 2. Preparar Buffers para Serial y CUDA ---
    // Copia para Serial
    char *h_serial_input = (char *)malloc(test_size);
    memcpy(h_serial_input, h_original, test_size);
    // Copia para CUDA
    char *h_cuda_input = (char *)malloc(test_size);
    memcpy(h_cuda_input, h_original, test_size);
    // Buffer para el resultado CUDA
    char *h_cuda_output = (char *)malloc(test_size);

    // --- 3. Ejecución Serial y Medición ---
    auto start_serial = std::chrono::high_resolution_clock::now();
    case_converter_serial(h_serial_input, test_size);
    auto end_serial = std::chrono::high_resolution_clock::now();
    auto duration_ns = std::chrono::duration_cast<std::chrono::nanoseconds>(end_serial - start_serial).count();
    double time_serial = (double)duration_ns / 1000000.0; // Convertir nanosegundos a milisegundos (ms)

    std::cout << "Tiempo Serial: " << std::fixed << std::setprecision(6) << time_serial << " ms" << std::endl;
    // --- 4. Ejecución CUDA y Medición ---
    double time_cuda = run_cuda(h_cuda_input, h_cuda_output, test_size);

    std::cout << "Tiempo CUDA: " << time_cuda << " ms" << std::endl;

    // --- 5. Validación de la Correctitud ---
    // Comparar el resultado de la versión CUDA con la versión Serial (que ya tiene el resultado correcto)
    if (memcmp(h_serial_input, h_cuda_output, test_size) == 0)
    { // [cite: 43]
        std::cout << "✅ Validación exitosa: Los resultados Serial y CUDA son idénticos." << std::endl;
    }
    else
    {
        std::cout << "❌ Error de validación: Los resultados Serial y CUDA NO coinciden." << std::endl;
    }

    // --- 6. Limpieza de Memoria del Host ---
    if (test_aligned)
        free(h_original); // Si se usó posix_memalign, se usa free
    else
        free(h_original);
    free(h_serial_input);
    free(h_cuda_input);
    free(h_cuda_output);

    return 0;
}