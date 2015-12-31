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

  def read_sig(data) do
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

  def pack_vtd(token, depth, prefix, qname, offset) do
    record = <<token::4, depth::8, prefix::9, qname::11, 0::2, offset::30>>
  end
  def unpack_vtd(record) do
    <<token::4, depth::8, prefix::9, qname::11, _::2, offset::30>> = <<record::64>>
    {token, depth, prefix, qname, offset}
  end

end

# another tack
# key is next(), back()
# next fetches next item
# back restores the old state
# peek is next+back, returning seen state
# accept is keep calling next until fail, then back, return accum

# Stream.unfold - initial value + function
# func returns value, next input to function
# return nil to terminate

# Stream.resource - same an unfold, but initial value is a func, plus needs destructor

# initial function

# next offset, file pointer/stream?, encoding, tail of current chunk
# if tail = {:incomplete, rest} get next chunk and tail == rest++new_chunk
# if EOF return {:halt}

# state: {lexer, vtd_records, lex_func}
defmodule Ratapotion.XmlTokenizer do
  require Logger
  use GenServer


  # doc_start
  # either DECL, <, or space
  # while next is space, ignore
  def ignorespace(lexer) do
    # while lexer.next() in [' ', '\t', '\r'] 
  end
end

#lexer state (TODO: struct)
# state: {file, enc, start, pos, width, data, last_char, next_char, token_type_or_lex_func}
#  file, encoding
#  start of current token, current file position
#  byte width of last character
#  current file chunk being read
#  last character read
#  next character (used when backing up, nil otherwise)
#  either a token type atom or a lexing function
defmodule Ratapotion.XmlLexer do
  require Logger
  use GenServer

  def init({f, chunk_size}) do
    data = IO.binread(f, chunk_size)
    {enc, bom_len, remainder} = Ratapotion.XML.read_sig(data)
    #result = :unicode.characters_to_list remainder, enc
    {:ok, {f, enc, bom_len, bom_len, 0, remainder, nil, nil, :DOC_START} }
  end

  defp read_char(data, _file, :utf8) do
    <<head::utf8, tail::binary>> = data
    {<<head>>, tail, byte_size(<<head>>)}
  end

  defp read_char(data, file, {:utf16, endian}) when byte_size(data) == 1 do
    new_chunk = IO.binread(file, 240)
    read_char(data <> new_chunk, file, {:utf16, endian})
  end

  defp read_char(data, _file, {:utf16, :big}) do
    <<head::utf16-big, tail::binary>> = data
    {<<head>>, tail, byte_size(<<head>>)}
  end

  defp read_char(data, _file, {:utf16, :little}) do
    <<head::utf16-little, tail::binary>> = data
    {<<head>>, tail, byte_size(<<head>>)}
  end

  # if tail empty or incomplete, read next chunk
  def handle_call(:next, _from, {file, enc, start, pos, width, <<>>, _last_char, nil, token_type_or_lex_func }) do
    # IO.binread returns data OR :eof
    new_chunk = IO.binread(file, 240)
    {head, tail, width} = read_char(new_chunk, file, enc)
    newstate = {file, enc, start, pos+width, width, tail, head, nil, token_type_or_lex_func }
    {:reply, head, newstate}
  end

  # next utf8 character
  def handle_call(:next, _from, {file, enc, start, pos, _width, data, _last_char, nil, token_type_or_lex_func }) do
    # tail or {:incomplete, tail}
    {head, tail, width} = read_char(data, file, enc)
    newstate = {file, enc, start, pos+width, width, tail, head, nil, token_type_or_lex_func }
    {:reply, head, newstate}
  end

  # next_char is not nil -- so we must have called :back
  def handle_call(:next, _from, {file, enc, start, pos, width, data, last_char, next_char, token_type_or_lex_func }) do
    newstate = {file, enc, start, pos+width, width, data, next_char, nil, token_type_or_lex_func }
    {:reply, last_char, newstate}
  end

  # back up one character
  def handle_cast(:back, {file, enc, start, pos, width, data, last_char, _next_char, token_type_or_lex_func}) do
    newstate = {file, enc, start, pos-width, width, data, last_char, last_char, token_type_or_lex_func }
    {:noreply, newstate}
  end

  # skip anything between start and current position
  def handle_cast(:ignore, {file, enc, _start, pos, width, data, last_char, next_char, token_type_or_lex_func}) do
    newstate = {file, enc, pos, pos, width, data, last_char, next_char, token_type_or_lex_func }
    {:noreply, newstate}
  end

  def start(f, chunk_size \\ 240) do
    GenServer.start_link(__MODULE__, {f, chunk_size}, name: __MODULE__)
  end
  def next do
    GenServer.call __MODULE__, :next
  end
  def back do
    GenServer.cast __MODULE__, :back
  end

  def ignore do
    GenServer.cast __MODULE__, :ignore
  end

  def peek do
    c = next()
    back()
    c
  end

  def accept?(wanted) do
    c = next()
    unless c == wanted, do: back()
    c == wanted
  end

end
