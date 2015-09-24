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
    # read in first 4 bytes
    # print out in hex
    # pattern match autodetection (case?)
    f = File.stream!(filename, [], 24)
    start = hd Enum.take(f, 1)
    <<a,b,c,d,_doc::binary>> = start
    bytes = <<a,b,c,d>>
    {enc, bom_len} = Ratapotion.XML.autodetect_encoding(bytes)
    Logger.info "autodetected encoding: #{enc}"
    Logger.info "document starts at offset #{bom_len}"
    # if utf-8, just start reading chars
    # else create iconv converter and start converting

  end


end
