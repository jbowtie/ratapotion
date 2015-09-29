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
    assert detect("testdocs/ucs4.xml") == "ucs-4be"
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
    assert detect("testdocs/ucs4bom.xml") == "ucs-4be"
  end

  test "autodetect utf16 BOM encoding" do
    assert detect("testdocs/utf16bom.xml") == {:utf16, :big}
  end
end
