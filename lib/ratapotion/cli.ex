defmodule Ratapotion.CLI do
  require Logger

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
    Ratapotion.XML.parse(filename)
  end


end
