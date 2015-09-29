defmodule Ratapotion.XML do
  require Logger

  def parse(filename) do
    f = File.stream!(filename, [], 24)
    parse_document(f)
  end

  def parse_document(stream) do
    #TODO: handle case where file size < chunk size
    # Enum.reduce won't call if only one element in collection!
    stream
    |> Stream.with_index
    |> Enum.reduce &parse_chunk/2
  end

  def parse_chunk({dataA, 1}, {data, 0}) do
    <<a,b,c,d,_doc::binary>> = data
    bytes = <<a,b,c,d>>
    {enc, bom_len} = autodetect_encoding(bytes)
    Logger.info "autodetected encoding: #{enc}"
    Logger.info "document starts at offset #{bom_len}"
    remainder = binary_part(data, bom_len, 24-bom_len) 

    # last arg is either encoding or func?
    # autodetected encoding can be used until we
    # reach actual declaration,
    # then need to switch encoding
    result = :unicode.characters_to_list remainder, :utf8
    case result do
      {:incomplete, str, rest} ->
        new_offset = handle(str, bom_len)
        parse_chunk({dataA, 1}, {new_offset, rest, :utf8})
      {:error, enc, _rest} ->
        Logger.debug("error")
        Logger.debug enc
        {:error}
      output ->
        new_offset = handle(output, bom_len)
        parse_chunk({dataA, 1}, {new_offset, [], :utf8})
    end
  end
  def parse_chunk({data, _index}, {offset, rest, enc}) do
    result = :unicode.characters_to_list rest ++ data, enc
    case result do
      {:incomplete, str, rest} ->
        new_offset = handle(str, offset)
        {new_offset, rest, enc}
      {:error, str, _rest} ->
        Logger.debug("decode error")
        Logger.debug str
        {:error}
      output ->
        new_offset = handle(output, offset)
        {new_offset, [], enc}
    end
  end

  def handle(chars, offset) do
    str = to_string chars
    # just debug output for new
    # this is where we do our lexing!
    Logger.debug(str)
    offset + byte_size str
  end

  def autodetect_encoding(bytes) do
    # UTF-16, UTF-32 handled by :unicode
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
        {:utf8, 3}
      <<0x00, 0x00, 0x00, 0x3C>> ->
        {"ucs-4be", 0}
      <<0x3C, 0x00, 0x00, 0x00>> ->
        {"ucs-4le", 0}
      <<0x00, 0x3C, 0x00, 0x3F>> ->
        {"utf-16be", 0}
      <<0x3C, 0x00, 0x3F, 0x00>> ->
        {"utf-16le", 0}
      <<0x3C, 0x3F, 0x78, 0x6D>> ->
        {:utf8, 0}
      <<0x4C, 0x6F, 0xA7, 0x94>> ->
        {"EBCDIC", 0}
      _ ->
        {:utf8, 0}
    end
  end
end
