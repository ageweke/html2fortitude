describe "html2fortitude text translation" do
  it "should render simple text with #text" do
    expect(h2f_content("hello, world")).to eq(%{text "hello, world"})
  end

  it "should escape '\#{' sequences in its input" do
    expect(h2f_content("hello, \#{world}")).to eq(%{text "hello, \\\#{world}"})
  end

  it "should properly escape text that requires escaping" do
    expect(h2f_content("hello, \"world")).to eq(%{text "hello, \\\"world"})
  end

  it "should not escape text that doesn't require escaping" do
    expect(h2f_content("hello, \'world")).to eq(%{text "hello, 'world"})
  end

  it "should properly handle multiline text" do
    expect(h2f_content(%{hello

world})).to eq(%{text %{hello

world}})
  end

  it "should properly handle multiline text with a } in it" do
    result = h2f_content(<<-EOS)
hello
}
world
EOS
    expect(result).to eq(<<-EOS.rstrip)
text %{hello
\\}
world}
EOS
  end

  it "should not output empty space" do
    expect(h2f_content("")).to eq("")
    expect(h2f_content("    ")).to eq("")
  end

  it "should allow dynamic content in text" do
    expect(h2f_content("hello, <% abc %> world")).to eq(
      %{text "hello, "
abc
text " world"})
  end

  it "should allow loud dynamic content in text" do
    expect(h2f_content("hello, <%= abc %> world")).to eq(%{text "hello, "
text(abc)
text " world"})
  end

  it "should allow multiline dynamic content in text" do
    expect(h2f_content(%{hello, <% abc
def(a, "b")
ghi %>
world})).to eq(%{text "hello, "
abc
def(a, "b")
ghi

text "world"})
  end

  it "should allow loud multiline dynamic content in text" do
    expect(h2f_content(%{hello, <%= abc
def(a, "b")
ghi %>
world})).to eq(%{text "hello, "
abc
def(a, "b")
text(ghi)

text "world"})
  end

  it "should eliminate whitespace before a tag" do
    expect(h2f_content(%{bar


<p/>})).to eq(%{text "bar"



p})
  end


  it "should eliminate whitespace after a tag" do
    expect(h2f_content(%{<p/>


bar})).to eq(%{p


text "bar"})
  end

  it "should skip 'text'/'rawtext' when calling 'render'" do
    expect(h2f_content(%{<%= render :partial => 'foo/bar' %>})).to eq(%{render :partial => 'foo/bar'})
  end
end
