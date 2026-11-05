defmodule Archivo do
  @moduledoc """
  Funciones comunes de lectura y escritura de archivos para los dos problemas.

  - Lectura: siempre en flujo (`File.stream!/1`), línea por línea.
  - Escritura: se crea o reemplaza el archivo y las líneas se escriben
    a medida que se producen.
  """

  @doc """
  Retorna un Stream de `{numero_de_linea, texto}`.

 
  """
  def lineas(ruta) do
    ruta
    |> File.stream!()
    |> Stream.with_index(1)
    |> Stream.map(fn {texto, numero} -> {numero, String.trim(texto)} end)
    |> Stream.reject(fn {_numero, texto} -> comentario_o_vacia?(texto) end)
  end

  defp comentario_o_vacia?(texto) do
    texto == "" or String.starts_with?(texto, "#")
  end

  @doc """
  Verifica que existan todos los archivos requeridos.

  Si falta alguno, informa cuál en la salida de errores y retorna `false`.
  """
  def existen?(rutas) do
    case Enum.reject(rutas, &File.regular?/1) do
      [] ->
        true

      faltantes ->
        Enum.each(faltantes, &Util2.mostrar("Error: falta el archivo requerido #{&1}", :error))
        false
    end
  end

  @doc """
  Crea (o reemplaza) un archivo de salida y ejecuta `escribir_en`, que
  recibe el dispositivo para usar con `IO.puts/2`. Retorna lo que
  retorne `escribir_en`.
  """
  def escribir(ruta, escribir_en) do
    File.open!(ruta, [:write, :utf8], escribir_en)
  end

  @doc "Separa un texto por `separador` y recorta los espacios de cada campo."
  def separar(texto, separador) do
    texto
    |> String.split(separador)
    |> Enum.map(&String.trim/1)
  end

  @doc "Convierte un texto a entero (sin texto sobrante) mayor o igual a `minimo`."
  def entero(texto, minimo) do
    case Integer.parse(texto) do
      {numero, ""} when numero >= minimo -> {:ok, numero}
      _ -> :error
    end
  end
end
