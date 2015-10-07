defmodule Ratapotion.XML do
  require Logger

  def parse(filename, chunk_size \\ 240) do
    info = File.stat!(filename)
    if info.size <= chunk_size do
      Logger.debug("reading in single go")
      f = File.open!(filename, [:read])
      data = IO.binread(f, :all)
      File.close(f)
      parse_document(data)
    end
    if info.size > chunk_size do
      f = File.stream!(filename, [], chunk_size)
      parse_document(f)
    end
  end

  def parse_document(data) when is_binary(data) do
    {enc, bom_len, remainder} = read_sig(data)
    read_chunk remainder, enc, bom_len
  end

  def parse_document(stream) do
    #TODO: handle case where file size < chunk size
    # Enum.reduce won't call if only one element in collection!
    stream
    |> Stream.with_index
    |> Enum.reduce(&parse_chunk/2)
  end

  defp read_sig(data) do
    <<a,b,c,d,_doc::binary>> = data
    bytes = <<a,b,c,d>>
    {enc, bom_len} = autodetect_encoding(bytes)
    Logger.info "autodetected encoding #{inspect enc}"
    Logger.info "document starts at offset #{bom_len}"
    remainder = binary_part(data, bom_len, byte_size(data)-bom_len)
    {enc, bom_len, remainder}
  end

  def parse_chunk({dataA, 1}, {data, 0}) do
    {enc, bom_len, remainder} = read_sig(data)

    # last arg is either encoding or func?
    # autodetected encoding can be used until we
    # reach actual declaration,
    # then need to switch encoding
    {new_offset, rest, new_enc} = read_chunk remainder, enc, bom_len
    parse_chunk({dataA, 1}, {new_offset, rest, new_enc})
  end

  def parse_chunk({data, _index}, {offset, rest, enc}) do
    read_chunk rest ++ data, enc, offset
  end

  defp read_chunk(data, enc, offset) do
    result = :unicode.characters_to_list data, enc
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

  defp handle(chars, offset) do
    # just debug output for new
    # this is where we do our lexing!
    # Agent.update
    # state: offset, accum, token_type
    # send a VTD record to another process 
    # when token recognized
    # usage
    # Parser.start
    # Parser.inc_parse(chars)
    # VTD.start
    # VTD.add_record
    {extra, new_offset} = Ratapotion.Lexer.lex(chars, offset)
    Logger.debug "unparsed: #{extra}"
    new_offset
  end

  def autodetect_encoding(bytes) do
    # UTF-16, UTF-32 handled by :unicode
    case bytes do
      <<0x00, 0x00, 0xFE, 0xFF>> ->
        {{:utf32, :big}, 4}
      <<0xFF, 0xFE, 0x00, 0x00>> ->
        {{:utf32, :little}, 4}
      <<0xFE, 0xFF, _, _>> ->
        {{:utf16, :big}, 2}
      <<0xFF, 0xFE, _, _>> ->
        {{:utf16, :little}, 2}
      <<0xEF, 0xBB, 0xBF, _>> ->
        {:utf8, 3}
      <<0x00, 0x00, 0x00, 0x3C>> ->
        {{:utf32, :big}, 0}
      <<0x3C, 0x00, 0x00, 0x00>> ->
        {{:utf32, :little}, 0}
      <<0x00, 0x3C, 0x00, 0x3F>> ->
        {{:utf16, :big}, 0}
      <<0x3C, 0x00, 0x3F, 0x00>> ->
        {{:utf16, :little}, 0}
      <<0x3C, 0x3F, 0x78, 0x6D>> ->
        {:utf8, 0}
      <<0x4C, 0x6F, 0xA7, 0x94>> ->
        {"EBCDIC", 0}
      _ ->
        {:utf8, 0}
    end
  end
end

defmodule Ratapotion.Lexer do
  require Logger
  @whitespace ' \t\r\n'
  # @nameChar ?A..?Z ++ ?a..?z  #extend to match XML spec

  def lex(input, offset) do
    lex_start(input, offset+1)
  end

  #XML declaration
  #or start of UTF-8 document
  def lex_start([?<, ??, ?x, ?m, ?l, space | tail], offset)  when space in @whitespace do
    Logger.info "XML declaration #{offset}"
    lex_decl tail, offset + 6
  end

  def lex_decl([??, ?> | tail], offset) do
    Logger.info "XML declaration ends"
    {tail, offset+2}
  end

  #consume whitespace
  def lex_decl([head | tail], offset) when head in ' \t\r\n' do
    lex_decl tail, offset+1
  end

  def lex_decl([head | tail], offset) do
    Logger.debug "#{head} at offset #{offset}"
    lex_decl tail, offset+1
  end
end
