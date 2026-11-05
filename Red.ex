defmodule Red do
  @moduledoc """
  Red no dirigida para la coloración: lectura, validación recursiva y construcción.

  `leer_nodos/1` y `leer_aristas/1` retornan listas de
  `{linea, {:ok, dato} | {:error, motivo}}`. `validar/2` recorre esas listas
  con recursión propia (sin Enum ni Stream) y retorna todos los problemas.
  """

  defstruct ids: [], nodos: %{}, aristas: [], vecinos: %{}

  # -----------------------------------
  # Lectura
  # -----------------------------------

  def leer_nodos(ruta) do
    ruta
    |> Archivo.lineas()
    |> Stream.map(fn {numero, texto} -> {numero, Nodo.parse(texto)} end)
    |> Enum.to_list()
  end

  def leer_aristas(ruta) do
    ruta
    |> Archivo.lineas()
    |> Stream.map(fn {numero, texto} -> {numero, parse_arista(texto)} end)
    |> Enum.to_list()
  end

  defp parse_arista(texto) do
    case Archivo.separar(texto, ",") do
      [a, b] when a != "" and b != "" -> {:ok, {a, b}}
      _ -> {:error, "formato inválido, se esperaba nodo_a,nodo_b"}
    end
  end

  # -----------------------------------
  # Validación previa recursiva
  # -----------------------------------

  @doc "Retorna la lista de problemas de la red (vacía si es válida)."
  def validar(nodos, aristas) do
    {ids, errores_nodos} = validar_nodos(nodos, MapSet.new(), [])
    errores_nodos ++ validar_aristas(aristas, ids, MapSet.new(), [])
  end

  # Revisa los nodos: formato inválido e IDs duplicados. Retorna {ids, errores}.
  defp validar_nodos([], ids, errores), do: {ids, :lists.reverse(errores)}

  defp validar_nodos([{numero, {:error, motivo}} | resto], ids, errores) do
    validar_nodos(resto, ids, ["nodos.csv línea #{numero}: #{motivo}" | errores])
  end

  defp validar_nodos([{numero, {:ok, nodo}} | resto], ids, errores) do
    if MapSet.member?(ids, nodo.id) do
      validar_nodos(resto, ids, ["nodos.csv línea #{numero}: ID duplicado #{nodo.id}" | errores])
    else
      validar_nodos(resto, MapSet.put(ids, nodo.id), errores)
    end
  end

  # Revisa las aristas: formato, nodos desconocidos, bucles y repetidas (o invertidas).
  defp validar_aristas([], _ids, _vistas, errores), do: :lists.reverse(errores)

  defp validar_aristas([{numero, {:error, motivo}} | resto], ids, vistas, errores) do
    validar_aristas(resto, ids, vistas, ["aristas.csv línea #{numero}: #{motivo}" | errores])
  end

  defp validar_aristas([{numero, {:ok, {a, b}}} | resto], ids, vistas, errores) do
    errores = desconocido(a, ids, numero, errores)
    errores = desconocido(b, ids, numero, errores)
    clave = if a <= b, do: {a, b}, else: {b, a}

    cond do
      not (MapSet.member?(ids, a) and MapSet.member?(ids, b)) ->
        validar_aristas(resto, ids, vistas, errores)

      a == b ->
        validar_aristas(resto, ids, vistas, ["aristas.csv línea #{numero}: bucle #{a},#{b}" | errores])

      MapSet.member?(vistas, clave) ->
        error = "aristas.csv línea #{numero}: arista repetida o invertida #{a},#{b}"
        validar_aristas(resto, ids, vistas, [error | errores])

      true ->
        validar_aristas(resto, ids, MapSet.put(vistas, clave), errores)
    end
  end

  defp desconocido(id, ids, numero, errores) do
    if MapSet.member?(ids, id) do
      errores
    else
      ["aristas.csv línea #{numero}: nodo desconocido #{id}" | errores]
    end
  end

  # -----------------------------------
  # Construcción (solo con red válida)
  # -----------------------------------

  @doc "Construye la red a partir de nodos y aristas ya validados."
  def construir(nodos, aristas) do
    lista = for {_numero, {:ok, nodo}} <- nodos, do: nodo
    pares = for {_numero, {:ok, par}} <- aristas, do: par
    ids = Enum.map(lista, & &1.id)
    sin_vecinos = Map.new(ids, &{&1, []})

    vecinos =
      Enum.reduce(pares, sin_vecinos, fn {a, b}, acumulado ->
        acumulado
        |> Map.update!(a, &[b | &1])
        |> Map.update!(b, &[a | &1])
      end)

    %Red{ids: ids, nodos: Map.new(lista, &{&1.id, &1}), aristas: pares, vecinos: vecinos}
  end

  @doc "Texto de una asignación en el orden de los nodos: `A=1;B=2;...`."
  def formato(asignacion, %Red{ids: ids}) do
    Enum.map_join(ids, ";", fn id -> "#{id}=#{asignacion[id]}" end)
  end
end
