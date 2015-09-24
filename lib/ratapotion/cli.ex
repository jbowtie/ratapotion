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
    bytes = hd Enum.take(f, 1)
    IO.inspect(bytes)
    IO.puts Ratapotion.XML.autodetect_encoding(bytes)
  end


end
