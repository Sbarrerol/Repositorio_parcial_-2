defmodule Nodo do
  @moduledoc "Nodo de la red con su posición de dibujo."

  defstruct id: "", x: 0, y: 0

  @doc "Convierte `id,x,y` en `{:ok, %Nodo{}}` o `{:error, motivo}`."
  def parse(texto) do
    with [id, x, y] when id != "" <- Archivo.separar(texto, ","),
         {:ok, x} <- Archivo.entero(x, 0),
         {:ok, y} <- Archivo.entero(y, 0) do
      {:ok, %Nodo{id: id, x: x, y: y}}
    else
      _ -> {:error, "formato inválido, se esperaba id,x,y con x e y enteros no negativos"}
    end
  end
end
