defmodule RatapotionTest do
  use ExUnit.Case

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
    Ratapotion.XmlLexer.start(f)
    assert Ratapotion.XmlLexer.next == ?<
    assert Ratapotion.XmlLexer.next == ??
    assert Ratapotion.XmlLexer.next == ?x
    assert Ratapotion.XmlLexer.next == ?m
    assert Ratapotion.XmlLexer.next == ?l
  end

  test "lexer.back works as expected" do
    f = File.open!("testdocs/utf8.xml")
    Ratapotion.XmlLexer.start(f)
    assert Ratapotion.XmlLexer.next == ?<
    Ratapotion.XmlLexer.back
    assert Ratapotion.XmlLexer.next == ?<
    assert Ratapotion.XmlLexer.next == ??
  end

  test "lexer.peek doesn't move cursor" do
    f = File.open!("testdocs/utf8.xml")
    Ratapotion.XmlLexer.start(f)
    assert Ratapotion.XmlLexer.next == ?<
    assert Ratapotion.XmlLexer.next == ??
    assert Ratapotion.XmlLexer.peek == ?x
    assert Ratapotion.XmlLexer.next == ?x
  end

  test "lexer.next in UTF-16 document" do
    f = File.open!("testdocs/utf16bom.xml")
    Ratapotion.XmlLexer.start(f, 5)
    assert Ratapotion.XmlLexer.next == "<"
    assert Ratapotion.XmlLexer.next == "?"
    assert Ratapotion.XmlLexer.next == "x"
    assert Ratapotion.XmlLexer.next == "m"
    assert Ratapotion.XmlLexer.next == "l"
  end
end
