describe "html2fortitude basics" do
  it "should render simple text with #text" do
    expect(h2f_content("hello, world")).to eq(%{text "hello, world"})
  end

  it "should not skip newlines in the source" do
    expect(h2f_content(%{<p foo="bar"/>

<p bar="baz"/>})).to eq(%{p(:foo => "bar")


p(:bar => "baz")})
  end
end
