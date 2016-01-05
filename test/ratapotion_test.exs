defmodule RatapotionTest do
  use ExUnit.Case
  require Logger

  alias Ratapotion.XmlLexer, as: Lexer

  #mute logging during unit tests
  setup_all do
    :ok = Logger.remove_backend(:console)
    on_exit(fn -> Logger.add_backend(:console, flush: true) end)
  end

  def detect(filename) do
    # read in first 4 bytes
    f = File.stream!(filename, [], 4)
    bytes = hd Enum.take(f, 1)
    {enc, _} = Ratapotion.XML.autodetect_encoding(bytes)
    enc
  end

  test "autodetect ucs-4 big-endian" do
    assert detect("testdocs/ucs4.xml") == {:utf32, :big}
  end

  test "autodetect utf8 encoding" do
    assert detect("testdocs/utf8.xml") == :utf8
  end

  test "autodetect utf8 BOM encoding" do
    assert detect("testdocs/utf8bom.xml") == :utf8
  end

  test "autodetect utf16 encoding" do
    assert detect("testdocs/utf16.xml") == {:utf16, :big}
  end

  test "autodetect utf16 LE encoding" do
    assert detect("testdocs/utf16le.xml") == {:utf16, :little}
  end

  test "autodetect ucs-4 BOM encoding" do
    assert detect("testdocs/ucs4bom.xml") == {:utf32, :big}
  end

  test "autodetect utf16 BOM encoding" do
    assert detect("testdocs/utf16bom.xml") == {:utf16, :big}
  end

  test "lexer.next in UTF-8 document" do
    f = File.open!("testdocs/utf8bom.xml")
    {:ok, lexer} = Lexer.start(f)
    assert Lexer.next(lexer) == "<"
    assert Lexer.next(lexer) == "?"
    assert Lexer.next(lexer) == "x"
    assert Lexer.next(lexer) == "m"
    assert Lexer.next(lexer) == "l"
  end

  test "lexer.back works as expected" do
    f = File.open!("testdocs/utf8.xml")
    {:ok, lexer} = Lexer.start(f)
    assert Lexer.next(lexer) == "<"
    Ratapotion.XmlLexer.back(lexer)
    assert Lexer.next(lexer) == "<"
    assert Lexer.next(lexer) == "?"
  end

  test "lexer.peek doesn't move cursor" do
    f = File.open!("testdocs/utf8.xml")
    {:ok, lexer} = Lexer.start(f)
    assert Lexer.next(lexer) == "<"
    assert Lexer.next(lexer) == "?"
    assert Lexer.peek(lexer) == "x"
    assert Lexer.next(lexer) == "x"
  end

  test "lexer.accept? works as expected" do
    f = File.open!("testdocs/utf8.xml")
    {:ok, lexer} = Lexer.start(f)
    assert Lexer.accept?(lexer, "<")
    refute Lexer.accept?(lexer, "A")
    assert Lexer.accept?(lexer, "?")
  end

  test "lexer.next in UTF-16BE document" do
    f = File.open!("testdocs/utf16bom.xml")
    {:ok, lexer} = Lexer.start(f, 5)
    assert Lexer.next(lexer) == "<"
    assert Lexer.next(lexer) == "?"
    assert Lexer.next(lexer) == "x"
    assert Lexer.next(lexer) == "m"
    assert Lexer.next(lexer) == "l"
  end

  test "lexer.next in UTF-16LE document" do
    f = File.open!("testdocs/utf16le.xml")
    {:ok, lexer} = Lexer.start(f, 5)
    assert Lexer.next(lexer) == "<"
    assert Lexer.next(lexer) == "?"
    assert Lexer.next(lexer) == "x"
    assert Lexer.next(lexer) == "m"
    assert Lexer.next(lexer) == "l"
  end

  test "eat whitespace" do
    {:ok, f} = StringIO.open("   abcd")
    {:ok, lexer} = Lexer.start(f)
    Lexer.eat_whitespace(lexer)
    assert Lexer.next(lexer) == "a"
    assert Lexer.next(lexer) == "b"
  end

  test "has_decl utf8" do
    f = File.open!("testdocs/utf8bom.xml")
    data = IO.binread(f, 32)
    {enc, _, remainder} = Ratapotion.XML.read_sig(data)
    assert Ratapotion.XML.has_decl? enc, remainder
  end

  test "has_decl UTF16-BE" do
    f = File.open!("testdocs/utf16.xml")
    data = IO.binread(f, 32)
    {enc, _, remainder} = Ratapotion.XML.read_sig(data)
    assert Ratapotion.XML.has_decl? enc, remainder
  end

  test "has_decl UTF16-LE" do
    f = File.open!("testdocs/utf16lebom.xml")
    data = IO.binread(f, 32)
    {enc, _, remainder} = Ratapotion.XML.read_sig(data)
    assert Ratapotion.XML.has_decl? enc, remainder
  end

  test "accept_run for tokens" do
    {:ok, f} = StringIO.open("123abc")
    {:ok, lexer} = Lexer.start(f)
    # should consume 123 in test string
    Lexer.accept_run(lexer, ~r/[0-9]/)
    assert Lexer.next(lexer) == "a"
  end

  test "pack VTD record" do
    # token 4 bits, depth 8 bits, prefix len 9 bits, qname len 11 bits
    # reserved 2 bits, offset 30 bits
    record = Ratapotion.XML.pack_vtd(0, 1, 0, 7, 130)
    <<val::64>> = record
    assert byte_size(record) == 8
    assert val == 4503629692141698
  end

  test "unpack VTD record" do
    # token 4 bits, depth 8 bits, prefix len 9 bits, qname len 11 bits
    # reserved 2 bits, offset 30 bits
    {token, depth, prefix, qname, offset} = Ratapotion.XML.unpack_vtd(4503629692141698)
    assert token == 0
    assert depth == 1
    assert prefix == 0
    assert qname == 7
    assert offset == 130
  end
end
