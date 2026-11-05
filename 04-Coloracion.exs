Code.require_file("Util2.ex", __DIR__)
Code.require_file("Archivo.ex", __DIR__)
Code.require_file("Nodo.ex", __DIR__)
Code.require_file("Red.ex", __DIR__)

defmodule Coloracion do
  @moduledoc """
  Problema 4: coloración de grafos.

  El backtracking recursivo entrega un Stream de soluciones; otro Stream
  infinito (k = 1, 2, 3, ...) busca el menor número de colores.
  """

  @paleta ~w(#fca5a5 #93c5fd #86efac #fde047 #d8b4fe #fdba74 #67e8f9 #f9a8d4 #bef264 #cbd5e1)

  def main do
    {datos, salida} = carpetas()
    nodos_csv = Path.join(datos, "nodos.csv")
    aristas_csv = Path.join(datos, "aristas.csv")
    colores_txt = Path.join(datos, "colores.txt")
    propuestas_txt = Path.join(datos, "propuestas.txt")

    if Archivo.existen?([nodos_csv, aristas_csv, colores_txt, propuestas_txt]) do
      File.mkdir_p!(salida)
      nodos = Red.leer_nodos(nodos_csv)
      aristas = Red.leer_aristas(aristas_csv)
      problemas = Red.validar(nodos, aristas)

      Archivo.escribir(Path.join(salida, "validacion_red.txt"), &escribir_validacion(problemas, &1))

      case problemas do
        [] ->
          nodos
          |> Red.construir(aristas)
          |> procesar(colores_txt, propuestas_txt, salida)

        _ ->
          Util2.mostrar("La red es inválida (#{length(problemas)} problemas): ver validacion_red.txt", :error)
          Util2.mostrar("No se buscan coloraciones.", :error)
      end
    end
  end

  # Sin argumentos usa datos/ y salida/; con dos argumentos: carpeta_datos carpeta_salida
  defp carpetas do
    case System.argv() do
      [datos, salida] -> {datos, salida}
      _ -> {"datos", "salida"}
    end
  end

  defp escribir_validacion([], arch), do: IO.puts(arch, "Red válida: sin problemas.")
  defp escribir_validacion(problemas, arch), do: Enum.each(problemas, &IO.puts(arch, &1))

  defp procesar(red, colores_txt, propuestas_txt, salida) do
    colores_txt
    |> Archivo.lineas()
    |> Enum.each(&coloraciones_de_k(&1, red, salida))

    verificar_propuestas(propuestas_txt, red, Path.join(salida, "verificacion_colores.txt"))
    primera_coloracion(red, Path.join(salida, "primera_coloracion_k10.svg"))
    secuencia_colores(red, Path.join(salida, "secuencia_colores.csv"))
  end

  # -----------------------------------
  # Backtracking como Stream
  # -----------------------------------

  # Stream perezoso de todas las coloraciones válidas con k colores. Los nodos
  # se procesan en el orden del archivo y los colores de 1 a k; nada se calcula
  # hasta que alguien consume el Stream.
  defp coloraciones(red, k), do: asignar(red.ids, red.vecinos, k, %{})

  defp asignar([], _vecinos, _k, asignacion), do: [asignacion]

  defp asignar([id | resto], vecinos, k, asignacion) do
    Stream.flat_map(1..k, fn color ->
      if libre?(id, color, vecinos, asignacion) do
        asignar(resto, vecinos, k, Map.put(asignacion, id, color))
      else
        []
      end
    end)
  end

  # Un color está libre si ningún vecino ya coloreado lo usa.
  defp libre?(id, color, vecinos, asignacion) do
    vecinos
    |> Map.fetch!(id)
    |> Enum.all?(fn vecino -> Map.get(asignacion, vecino) != color end)
  end

  # -----------------------------------
  # Un archivo por k: cada solución se escribe al recibirla
  # -----------------------------------

  defp coloraciones_de_k({numero, texto}, red, salida) do
    case Archivo.entero(texto, 1) do
      {:ok, k} -> escribir_coloraciones(red, k, salida)
      :error -> Util2.mostrar("colores.txt línea #{numero}: k inválido (#{texto})", :error)
    end
  end

  defp escribir_coloraciones(red, k, salida) do
    total =
      Archivo.escribir(Path.join(salida, "coloraciones_k#{k}.txt"), fn arch ->
        cantidad =
          red
          |> coloraciones(k)
          |> Stream.with_index(1)
          |> Enum.reduce(0, fn {asignacion, i}, _anterior ->
            IO.puts(arch, "#{i}: #{Red.formato(asignacion, red)}")
            i
          end)

        IO.puts(arch, "Total: #{cantidad}")
        cantidad
      end)

    Util2.mostrar("k = #{k}: #{total} coloraciones", :mensaje)
  end

  # -----------------------------------
  # Verificación recursiva de propuestas (sin Enum ni Stream)
  # -----------------------------------

  defp verificar_propuestas(ruta, red, ruta_salida) do
    Archivo.escribir(ruta_salida, fn arch ->
      ruta
      |> Archivo.lineas()
      |> Stream.map(fn {numero, texto} -> {numero, texto, parse_propuesta(texto)} end)
      |> Enum.each(&informar_propuesta(&1, red, arch))
    end)
  end

  # "k;id=color;id=color" -> {:ok, k, [{id, color}, ...]} o {:error, motivo}
  defp parse_propuesta(texto) do
    [k | pares] = Archivo.separar(texto, ";")

    with {:ok, k} <- parse_k(k),
         {:ok, lista} <- parse_pares(pares, []) do
      {:ok, k, lista}
    end
  end

  defp parse_k(texto) do
    case Archivo.entero(texto, 1) do
      {:ok, k} -> {:ok, k}
      :error -> {:error, "k inválido: \"#{texto}\""}
    end
  end

  defp parse_pares([], acumulado), do: {:ok, :lists.reverse(acumulado)}

  defp parse_pares([par | resto], acumulado) do
    with [id, color] when id != "" <- Archivo.separar(par, "="),
         {color, ""} <- Integer.parse(color) do
      parse_pares(resto, [{id, color} | acumulado])
    else
      _ -> {:error, "par mal formado: \"#{par}\" (se esperaba id=color)"}
    end
  end

  defp informar_propuesta({numero, texto, {:error, motivo}}, _red, arch) do
    IO.puts(arch, "Línea #{numero} (#{texto}): INVÁLIDA\n  - #{motivo}\n")
    Util2.mostrar("Propuesta línea #{numero}: inválida", :mensaje)
  end

  defp informar_propuesta({numero, texto, {:ok, k, pares}}, red, arch) do
    {asignacion, errores} = revisar_pares(pares, k, red.nodos, %{}, [])
    errores = revisar_faltantes(red.ids, asignacion, errores)
    errores = revisar_conflictos(red.aristas, asignacion, errores)

    case :lists.reverse(errores) do
      [] ->
        IO.puts(arch, "Línea #{numero} (#{texto}): VÁLIDA\n")
        Util2.mostrar("Propuesta línea #{numero}: válida", :mensaje)

      problemas ->
        IO.puts(arch, "Línea #{numero} (#{texto}): INVÁLIDA")
        Enum.each(problemas, &IO.puts(arch, "  - " <> &1))
        IO.puts(arch, "")
        Util2.mostrar("Propuesta línea #{numero}: inválida (#{length(problemas)} problemas)", :mensaje)
    end
  end

  # Retorna {asignacion, errores}: nodos desconocidos, repetidos y colores fuera de 1..k.
  defp revisar_pares([], _k, _nodos, asignacion, errores), do: {asignacion, errores}

  defp revisar_pares([{id, color} | resto], k, nodos, asignacion, errores) do
    cond do
      not Map.has_key?(nodos, id) ->
        revisar_pares(resto, k, nodos, asignacion, ["nodo desconocido #{id}" | errores])

      Map.has_key?(asignacion, id) ->
        revisar_pares(resto, k, nodos, asignacion, ["nodo repetido #{id}" | errores])

      color < 1 or color > k ->
        error = "color #{color} de #{id} fuera de 1..#{k}"
        revisar_pares(resto, k, nodos, Map.put(asignacion, id, color), [error | errores])

      true ->
        revisar_pares(resto, k, nodos, Map.put(asignacion, id, color), errores)
    end
  end

  defp revisar_faltantes([], _asignacion, errores), do: errores

  defp revisar_faltantes([id | resto], asignacion, errores) do
    if Map.has_key?(asignacion, id) do
      revisar_faltantes(resto, asignacion, errores)
    else
      revisar_faltantes(resto, asignacion, ["falta el nodo #{id}" | errores])
    end
  end

  defp revisar_conflictos([], _asignacion, errores), do: errores

  defp revisar_conflictos([{a, b} | resto], asignacion, errores) do
    color = Map.get(asignacion, a)

    if color != nil and color == Map.get(asignacion, b) do
      error = "conflicto: #{a} y #{b} tienen el color #{color}"
      revisar_conflictos(resto, asignacion, [error | errores])
    else
      revisar_conflictos(resto, asignacion, errores)
    end
  end

  # -----------------------------------
  # Solo la primera solución con 10 colores
  # -----------------------------------

  # Enum.take(1) detiene el Stream en cuanto llega la primera solución.
  defp primera_coloracion(red, ruta_svg) do
    case red |> coloraciones(10) |> Enum.take(1) do
      [primera] ->
        Archivo.escribir(ruta_svg, &dibujar(&1, red, primera))
        Util2.mostrar("Primera coloración con 10 colores: #{Red.formato(primera, red)} (SVG generado)", :mensaje)

      [] ->
        Util2.mostrar("No hay coloración con 10 colores; no se genera el SVG.", :mensaje)
    end
  end

  # El SVG se escribe por fragmentos: apertura, aristas, nodos y cierre.
  defp dibujar(arch, red, asignacion) do
    nodos = Map.values(red.nodos)
    ancho = Enum.max([0 | Enum.map(nodos, & &1.x)]) + 100
    alto = Enum.max([0 | Enum.map(nodos, & &1.y)]) + 100

    IO.puts(arch, ~s|<?xml version="1.0" encoding="UTF-8"?>|)

    IO.puts(
      arch,
      ~s|<svg xmlns="http://www.w3.org/2000/svg" width="#{ancho}" height="#{alto}" viewBox="0 0 #{ancho} #{alto}">|
    )

    IO.puts(arch, ~s|  <rect width="100%" height="100%" fill="#ffffff"/>|)
    Enum.each(red.aristas, &dibujar_arista(arch, red.nodos, &1))
    Enum.each(red.ids, &dibujar_nodo(arch, red.nodos[&1], asignacion[&1]))
    IO.puts(arch, "</svg>")
  end

  defp dibujar_arista(arch, nodos, {a, b}) do
    desde = nodos[a]
    hasta = nodos[b]

    IO.puts(
      arch,
      ~s|  <line x1="#{desde.x}" y1="#{desde.y}" x2="#{hasta.x}" y2="#{hasta.y}" stroke="#374151" stroke-width="2"/>|
    )
  end

  defp dibujar_nodo(arch, nodo, color) do
    relleno = Enum.at(@paleta, rem(color - 1, length(@paleta)))

    IO.puts(
      arch,
      ~s|  <circle cx="#{nodo.x}" cy="#{nodo.y}" r="22" fill="#{relleno}" stroke="#111827" stroke-width="2"/>|
    )

    IO.puts(
      arch,
      ~s|  <text x="#{nodo.x}" y="#{nodo.y}" text-anchor="middle" dominant-baseline="central" | <>
        ~s|font-family="sans-serif" font-size="16" font-weight="bold" fill="#111827">#{escapar(nodo.id)}</text>|
    )
  end

  defp escapar(texto) do
    texto
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end

  # -----------------------------------
  # Stream infinito: número mínimo de colores
  # -----------------------------------

  # Stream.map es perezoso: {k, total} se calcula solo cuando reduce_while pide
  # el siguiente elemento, y reduce_while se detiene tras el primer total > 0,
  # de modo que el k siguiente nunca se calcula.
  defp secuencia_colores(red, ruta) do
    minimo =
      Archivo.escribir(ruta, fn arch ->
        IO.puts(arch, "k;total_coloraciones")

        1
        |> Stream.iterate(&(&1 + 1))
        |> Stream.map(fn k -> {k, red |> coloraciones(k) |> Enum.count()} end)
        |> Enum.reduce_while(nil, fn {k, total}, _anterior ->
          IO.puts(arch, "#{k};#{total}")
          if total > 0, do: {:halt, k}, else: {:cont, nil}
        end)
      end)

    Util2.mostrar("Número mínimo de colores: #{minimo}", :mensaje)
  end
end

Coloracion.main()
