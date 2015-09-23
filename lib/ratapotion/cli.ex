defmodule Ratapotion.CLI do
  def main(argv) do
    argv
    |> parse_args
    |> process
  end

  def parse_args(argv) do
    parse = OptionParser.parse(argv, switches: [help: :boolean],
                                     aliases: [h: :help])
    case parse do
      {[help: true], _, _}
        -> :help
      {_, filename, _}
        -> filename
      _ -> :help
    end
  end

  def process(:help) do
    IO.puts"""
    usage: TODO
    """
    System.halt(0)
  end

  def process(filename) do
    # read in first 4 bytes
    # print out in hex
    # pattern match autodetection (case?)
    f = File.stream!(filename, [], 4)
    bytes = Enum.take(f, 1)
    IO.inspect(bytes)
    IO.puts autodetect_encoding(bytes)
  end

  def autodetect_encoding(bytes) do
    case bytes do
      <<0x00, 0x00, 0xFE, 0xFF>> ->
        "ucs-4be with BOM"
      <<0xFF, 0xFE, 0x00, 0x00>> ->
        "ucs-4le with BOM"
      _ ->
        "utf-8 fallback"
    end
  end

end
