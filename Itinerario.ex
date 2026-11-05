defmodule Itinerario do
  @moduledoc "Camino simple entre dos centros, con su tiempo y costo totales."

  defstruct centros: [], minutos: 0, costo: 0

  @doc "Cantidad de tramos del itinerario."
  def tramos(%Itinerario{centros: centros}), do: length(centros) - 1

  defimpl String.Chars, for: Itinerario do
    def to_string(%Itinerario{centros: centros, minutos: minutos, costo: costo} = itinerario) do
      ruta = Enum.join(centros, " → ")
      "#{ruta} | tramos: #{Itinerario.tramos(itinerario)} | #{minutos} min | costo: #{costo}"
    end
  end
end
