describe "html2fortitude tags handling" do
  it "should render a very simple tag with just its name" do
    expect(h2f_content("<p/>")).to eq(%{p})
    expect(h2f_content("<p></p>")).to eq(%{p})
  end

  it "should render a very simple tag with attributes" do
    expect(h2f_content(%{<p foo="bar"/>})).to eq(%{p(:foo => "bar")})
  end

  it "should render multiple attributes properly" do
    result = h2f_content(%{<p foo="bar" bar="baz"/>})

    expect(result).to match(%r{^p\(:[a-z].*"\)$})
    expect(result).to match(%r{:foo => "bar"})
    expect(result).to match(%r{:bar => "baz"})
  end

  it "should render attributes that aren't simple Symbols properly" do
    expect(h2f_content(%{<p foo-bar="baz"/>})).to eq(%{p("foo-bar" => "baz")})
  end

  it "should render attributes that have dynamic values properly" do
    expect(h2f_content(%{<p foo="<%= bar %>"})).to eq(%{p(:foo => bar)})
  end

  it "should render attributes that have a mix of dynamic and static content for their values properly" do
    expect(h2f_content(%{<p foo="bar <%= baz %> quux"/>})).to eq(%{p(:foo => "bar \#{baz} quux")})
  end

  it "should render attributes that have a dynamic key properly" do
    pending "This doesn't work; html2haml's <haml_loud> system fouls up Nokogiri too badly here"
    expect(h2f_content(%{<p <%= foo %>="bar"/>})).to eq(%{p foo => "bar"})
  end

  it "should render attributes that have a mix of dynamic and static content for their keys properly" do
    pending "This doesn't work; html2haml's <haml_loud> system fouls up Nokogiri too badly here"
    expect(h2f_content(%{<p foo<%= bar %>baz="bar"/>})).to eq(%{p "foo\#{bar}baz" => "bar"})
  end

  it "should render a tag containing another tag correctly" do
    expect(h2f_content(%{<p><br/></p>})).to eq(%{p {
  br
}})
  end

  it "should render a tag containing text correctly" do
    expect(h2f_content(%{<p>hello, world</p>})).to eq(%{p("hello, world")})
  end

  it "should render a tag containing text with newlines correctly" do
    expect(h2f_content(%{<p>hello,
world</p>})).to eq(%{p(%{hello,
world})})
  end

  it "should render a tag with a single child of loud output correctly" do
    expect(h2f_content(%{<p><%= foo %></p>})).to eq(%{p(foo)})
  end

  it "should render a tag with a single child of multiline loud output correctly" do
    expect(h2f_content(%{<p><%=
x = 123
x += 200
x
%></p>})).to eq(%{p {
  x = 123
  x += 200
  text(x)
}})
  end

  it "should render a tag with a single child of loud output with a semicolon correctly" do
    expect(h2f_content(%{<p><%= x = 123; x += 200; x %></p>})).to eq(%{p {
  text(x = 123; x += 200; x)
}})
  end
end
