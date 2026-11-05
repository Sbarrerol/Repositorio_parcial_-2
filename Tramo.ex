defmodule Tramo do
  @moduledoc "Tramo de transporte dirigido. `linea` guarda la línea física del archivo."

  defstruct origen: "", destino: "", minutos: 0, costo: 0, linea: 0

  @doc "Convierte `origen,destino,minutos,costo` en `{:ok, %Tramo{}}` o `{:error, motivo}`."
  def parse(texto) do
    case Archivo.separar(texto, ",") do
      [origen, destino, minutos, costo] -> crear(origen, destino, minutos, costo)
      campos -> {:error, "se esperaban 4 campos y hay #{length(campos)}"}
    end
  end

  defp crear("", _destino, _minutos, _costo), do: {:error, "origen vacío"}
  defp crear(_origen, "", _minutos, _costo), do: {:error, "destino vacío"}

  defp crear(origen, destino, minutos, costo) do
    with {:ok, minutos} <- entero_positivo(minutos, "minutos"),
         {:ok, costo} <- entero_positivo(costo, "costo") do
      {:ok, %Tramo{origen: origen, destino: destino, minutos: minutos, costo: costo}}
    end
  end

  defp entero_positivo(texto, nombre) do
    case Archivo.entero(texto, 1) do
      {:ok, numero} -> {:ok, numero}
      :error -> {:error, "#{nombre} debe ser un entero positivo (recibido: \"#{texto}\")"}
    end
  end

  defimpl String.Chars, for: Tramo do
    def to_string(%Tramo{origen: origen, destino: destino, minutos: minutos, costo: costo}) do
      "#{origen},#{destino},#{minutos},#{costo}"
    end
  end
end
