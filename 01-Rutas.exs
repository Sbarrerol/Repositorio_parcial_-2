Code.require_file("Util2.ex", __DIR__)
Code.require_file("Archivo.ex", __DIR__)
Code.require_file("Tramo.ex", __DIR__)
Code.require_file("Itinerario.ex", __DIR__)

defmodule Rutas do
  @moduledoc """
  Problema 1: itinerarios simples en una red dirigida.

  Flujo: leer tramos (Stream) -> depurar (recursión) -> armar el grafo ->
  por cada consulta: Stream infinito de alcance -> búsqueda recursiva.
  """

  def main do
    {datos, salida} = carpetas()
    tramos_csv = Path.join(datos, "tramos.csv")
    consultas_txt = Path.join(datos, "consultas.txt")

    if Archivo.existen?([tramos_csv, consultas_txt]) do
      File.mkdir_p!(salida)
      procesar(tramos_csv, consultas_txt, salida)
    end
  end

  defp carpetas do
    case System.argv() do
      [datos, salida] -> {datos, salida}
      _ -> {"datos", "salida"}
    end
  end

  defp procesar(tramos_csv, consultas_txt, salida) do
    {validos, descartes} =
      tramos_csv
      |> leer_tramos(Path.join(salida, "errores_tramos.txt"))
      |> depurar()

    escribir_descartes(descartes, Path.join(salida, "depuracion_tramos.txt"))

    grafo = Enum.group_by(validos, & &1.origen)
    centros = validos |> Enum.flat_map(&[&1.origen, &1.destino]) |> MapSet.new()

    Archivo.escribir(Path.join(salida, "itinerarios.txt"), fn arch_itinerarios ->
      Archivo.escribir(Path.join(salida, "alcance_centros.txt"), fn arch_alcance ->
        consultas_txt
        |> Archivo.lineas()
        |> Enum.each(&consultar(&1, grafo, centros, arch_itinerarios, arch_alcance))
      end)
    end)
  end


  # Lectura perezosa de tramos
  

  defp leer_tramos(ruta, ruta_errores) do
    Archivo.escribir(ruta_errores, fn arch_errores ->
      ruta
      |> Archivo.lineas()
      |> Stream.map(fn {numero, texto} -> {numero, texto, Tramo.parse(texto)} end)
      |> Stream.each(&reportar_error(&1, arch_errores))
      |> Stream.flat_map(&tramo_valido/1)
      |> Enum.to_list()
    end)
  end

  defp reportar_error({numero, texto, {:error, motivo}}, arch_errores) do
    IO.puts(arch_errores, "Línea #{numero}: #{texto} | #{motivo}")
  end

  defp reportar_error(_linea, _arch_errores), do: :ok

  # El tramo conserva la línea física original.
  defp tramo_valido({numero, _texto, {:ok, tramo}}), do: [%{tramo | linea: numero}]
  defp tramo_valido(_linea), do: []

  
  # Validación previa recursiva: depurar la red (sin Enum ni Stream)
  
  # Descarta bucles y repeticiones de la misma pareja dirigida (se conserva la
  # primera). Retorna {validos, descartes}; cada descarte es {tramo, motivo}.
  defp depurar(tramos), do: depurar(tramos, MapSet.new(), [], [])

  defp depurar([], _vistos, validos, descartes) do
    {:lists.reverse(validos), :lists.reverse(descartes)}
  end

  defp depurar([tramo | resto], vistos, validos, descartes) do
    pareja = {tramo.origen, tramo.destino}

    cond do
      tramo.origen == tramo.destino ->
        motivo = "bucle: sale y llega al mismo centro"
        depurar(resto, vistos, validos, [{tramo, motivo} | descartes])

      MapSet.member?(vistos, pareja) ->
        motivo = "pareja repetida en la misma dirección (se conserva la primera)"
        depurar(resto, vistos, validos, [{tramo, motivo} | descartes])

      true ->
        depurar(resto, MapSet.put(vistos, pareja), [tramo | validos], descartes)
    end
  end

  defp escribir_descartes(descartes, ruta) do
    Archivo.escribir(ruta, fn arch ->
      Enum.each(descartes, fn {tramo, motivo} ->
        IO.puts(arch, "Línea #{tramo.linea} | #{tramo} | #{motivo}")
      end)
    end)
  end

  
  # Consultas
  

  defp consultar({numero, texto}, grafo, centros, arch_itinerarios, arch_alcance) do
    case Archivo.separar(texto, ",") do
      [origen, destino] when origen != "" and destino != "" ->
        resolver(origen, destino, grafo, centros, arch_itinerarios, arch_alcance)

      _ ->
        IO.puts(arch_itinerarios, "=== Línea #{numero}: consulta inválida (#{texto}) ===\n")
        Util2.mostrar("Línea #{numero}: consulta inválida (#{texto})", :error)
    end
  end

  defp resolver(origen, destino, grafo, centros, arch_itinerarios, arch_alcance) do
    IO.puts(arch_itinerarios, "=== #{origen} → #{destino} ===")

    case Enum.reject([origen, destino], &MapSet.member?(centros, &1)) do
      [] ->
        buscar_itinerarios(origen, destino, grafo, arch_itinerarios, arch_alcance)

      desconocidos ->
        mensaje = "centro inexistente: " <> Enum.join(desconocidos, ", ")
        IO.puts(arch_itinerarios, mensaje <> "\n")
        Util2.mostrar("#{origen} → #{destino}: #{mensaje}", :mensaje)
    end
  end

  defp buscar_itinerarios(origen, destino, grafo, arch_itinerarios, arch_alcance) do
    alcanzados =
      grafo
      |> alcanzables(origen)
      |> escribir_alcance(arch_alcance, origen, destino)

    if MapSet.member?(alcanzados, destino) do
      itinerarios = buscar(grafo, origen, destino)
      escribir_itinerarios(arch_itinerarios, itinerarios)
      Util2.mostrar("#{origen} → #{destino}: #{length(itinerarios)} itinerarios", :mensaje)
    else
      IO.puts(arch_itinerarios, "sin itinerarios\n")
      Util2.mostrar("#{origen} → #{destino}: sin itinerarios", :mensaje)
    end
  end


  # Stream infinito: centros alcanzables


  # Stream.iterate/2 genera pasos sin fin; Stream.transform/3 lo corta (:halt)
  # al ver el primer estado igual al anterior y solo emite los estados distintos.
  defp alcanzables(grafo, origen) do
    MapSet.new([origen])
    |> Stream.iterate(&expandir(&1, grafo))
    |> Stream.transform(:inicio, fn estado, anterior ->
      if estado == anterior, do: {:halt, anterior}, else: {[estado], estado}
    end)
  end

  # Añade los destinos de todos los tramos que salen de los centros alcanzados.
  defp expandir(alcanzados, grafo) do
    Enum.reduce(alcanzados, alcanzados, fn centro, acumulado ->
      grafo
      |> Map.get(centro, [])
      |> Enum.reduce(acumulado, fn tramo, conjunto -> MapSet.put(conjunto, tramo.destino) end)
    end)
  end

  defp escribir_alcance(estados, arch, origen, destino) do
    IO.puts(arch, "=== #{origen} → #{destino} ===")

    {ultimo, paso} =
      estados
      |> Stream.with_index()
      |> Enum.reduce({MapSet.new(), 0}, fn {estado, paso}, _anterior ->
        IO.puts(arch, "Paso #{paso}: {#{estado |> Enum.sort() |> Enum.join(", ")}}")
        {estado, paso}
      end)

    IO.puts(arch, "Se estabiliza en el paso #{paso} (el paso #{paso + 1} repite el conjunto)\n")
    ultimo
  end


  # Búsqueda recursiva de itinerarios simples


  defp buscar(grafo, origen, destino), do: recorrer(grafo, origen, destino, [origen], 0, 0)

  defp recorrer(_grafo, destino, destino, camino, minutos, costo) do
    [%Itinerario{centros: :lists.reverse(camino), minutos: minutos, costo: costo}]
  end

  # Prueba cada tramo que sale del centro actual hacia un centro no visitado.
  defp recorrer(grafo, actual, destino, camino, minutos, costo) do
    grafo
    |> Map.get(actual, [])
    |> Enum.reject(&(&1.destino in camino))
    |> Enum.flat_map(fn tramo ->
      recorrer(
        grafo,
        tramo.destino,
        destino,
        [tramo.destino | camino],
        minutos + tramo.minutos,
        costo + tramo.costo
      )
    end)
  end


  # Salida de itinerarios y óptimos


  defp escribir_itinerarios(arch, itinerarios) do
    numerados = Enum.with_index(itinerarios, 1)

    Enum.each(numerados, fn {itinerario, i} ->
      IO.puts(arch, "Itinerario #{i}: #{itinerario}")
    end)

    IO.puts(arch, "Total: #{length(itinerarios)} itinerarios")
    IO.puts(arch, "Menos tramos: #{optimos(numerados, &Itinerario.tramos/1)}")
    IO.puts(arch, "Menor tiempo: #{optimos(numerados, & &1.minutos)}")
    IO.puts(arch, "Menor costo: #{optimos(numerados, & &1.costo)}\n")
  end

  defp optimos(numerados, criterio) do
    minimo =
      numerados
      |> Enum.map(fn {itinerario, _i} -> criterio.(itinerario) end)
      |> Enum.min()

    numerados
    |> Enum.filter(fn {itinerario, _i} -> criterio.(itinerario) == minimo end)
    |> Enum.map_join(", ", fn {_itinerario, i} -> i end)
  end
end

Rutas.main()
