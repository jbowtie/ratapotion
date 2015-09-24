defmodule Ratapotion.XML do


  def parse(filename) do
    # read in first 4 bytes
    # print out in hex
    # pattern match autodetection (case?)
    f = File.stream!(filename, [], 4)
    bytes = hd Enum.take(f, 1)
    IO.inspect(bytes)
    IO.puts autodetect_encoding(bytes)
  end

  def autodetect_encoding(bytes) do
    case bytes do
      <<0x00, 0x00, 0xFE, 0xFF>> ->
        {"ucs-4be", 4}
      <<0xFF, 0xFE, 0x00, 0x00>> ->
        {"ucs-4le", 4}
      <<0xFE, 0xFF, _, _>> ->
        {"utf-16be", 2}
      <<0xFF, 0xFE, _, _>> ->
        {"utf-16le", 2}
      <<0xEF, 0xBB, 0xBF, _>> ->
        {"utf-8", 3}
      <<0x00, 0x00, 0x00, 0x3C>> ->
        {"ucs-4be", 0}
      <<0x3C, 0x00, 0x00, 0x00>> ->
        {"ucs-4le", 0}
      <<0x00, 0x3C, 0x00, 0x3F>> ->
        {"utf-16be", 0}
      <<0x3C, 0x00, 0x3F, 0x00>> ->
        {"utf-16le", 0}
      <<0x3C, 0x3F, 0x78, 0x6D>> ->
        {"utf-8", 0}
      <<0x4C, 0x6F, 0xA7, 0x94>> ->
        {"EBCDIC", 0}
      _ ->
        {"utf-8 fallback", 0}
    end
  end
end
