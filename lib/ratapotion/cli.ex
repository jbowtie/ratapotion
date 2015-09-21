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
      _ -> :help
    end
  end

  def process(:help) do
    IO.puts"""
    usage: TODO
    """
    System.halt(0)
  end
end
