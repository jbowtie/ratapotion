defmodule Ratapotion.XML do
  require Logger

  def parse(_filename, _chunk_size \\ 240) do
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

  def has_decl?(:utf8, data) do
    decl = binary_part(data, 0, 5)
    decl == "<?xml"
  end

  def has_decl?({:utf16, :big}, data) do
    decl = binary_part(data, 0, 10)
    decl == <<?<::utf16-big, ??::utf16-big, ?x::utf16-big, ?m::utf16-big, ?l::utf16-big>>
  end

  def has_decl?({:utf16, :little}, data) do
    decl = binary_part(data, 0, 10)
    decl == <<?<::utf16-little, ??::utf16-little, ?x::utf16-little, ?m::utf16-little, ?l::utf16-little>>
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
        {:ebcdic, 0}
      _ ->
        {:utf8, 0}
    end
  end

  def pack_vtd(token, depth, prefix, qname, offset) do
    <<token::4, depth::8, prefix::9, qname::11, 0::2, offset::30>>
  end
  def unpack_vtd(record) do
    <<token::4, depth::8, prefix::9, qname::11, _::2, offset::30>> = <<record::64>>
    {token, depth, prefix, qname, offset}
  end

end

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
  alias Ratapotion.XmlLexer, as: Scanner

  # state: lexer, VTD records
  def init({scanner, vtd}) do
    {:ok, {scanner, vtd} }
  end
  def start(scanner, vtd \\ []) do
    GenServer.start_link(__MODULE__, {scanner, vtd})
  end

  # doc_start
  # either DECL, <, or space
  def doc_start(scanner) do
    c = Scanner.next(scanner)
    case c do
      " " ->
        Scanner.eat_whitespace(scanner)
        unless Scanner.accept?("<"), do: {:error, "Malformed XML document"}
        {:ok, &lt_seen/1}
      #"<" -> Scanner.lex_func lt_seen/1
      _ -> {:error, "Malformed XML document"}
    end
  end

  # element, PI, comment, CDATA, or DTD decl
  def lt_seen(_scanner) do
  end

end

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
  def handle_call(:next, _from, {file, enc, start, pos, _width, <<>>, _last_char, nil, token_type_or_lex_func }) do
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
    GenServer.start_link(__MODULE__, {f, chunk_size})
  end

  def next(pid) do
    GenServer.call pid, :next
  end

  def back(pid) do
    GenServer.cast pid, :back
  end

  def ignore(pid) do
    GenServer.cast pid, :ignore
  end

  def peek(pid) do
    c = next(pid)
    back(pid)
    c
  end

  def accept?(pid, wanted) do
    c = next(pid)
    if Regex.regex?(wanted) do
      unless Regex.match?(wanted, c), do: back(pid)
      Regex.match?(wanted, c)
    else
      unless c == wanted, do: back(pid)
      c == wanted
    end
  end

  # keep going until we hit an unacceptable character
  def accept_run(pid, wanted) do
    if accept?(pid, wanted), do: accept_run(pid, wanted)
  end

  # while next is space, ignore
  def eat_whitespace(pid) do
    if accept?(pid, ~r/\s/) do
      ignore(pid)
      eat_whitespace(pid)
    end
  end

end
