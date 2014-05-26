describe "html2fortitude options support" do
  it "should generate a class descending from Fortitude::Widget::Html5 by default" do
    result = h2f("hello, world", :class_name => "Some::Class::Name")
    expect(result.class_name).to eq("Some::Class::Name")
    expect(result.superclass).to eq("Fortitude::Widget::Html5")
  end

  it "should generate a class inheriting from the given class if asked to" do
    result = h2f("hello, world", :class_name => "Some::Other::ClassName", :superclass => "My::Base")
    expect(result.class_name).to eq("Some::Other::ClassName")
    expect(result.superclass).to eq("My::Base")
  end

  it "should generate a method named 'content' by default" do
    result = h2f("hello, world")
    expect(result.method_name).to eq("content")
  end

  it "should generate a method with a different name if asked to" do
    result = h2f("hello, world", :method => "foobar")
    expect(result.method_name).to eq("foobar")
  end

  it "should use { ... } for tag content by default" do
    expect(h2f_content("<p><span>hi</span></p>")).to eq(%{p {
  span("hi")
}})
  end

  it "should use do ... end instead of { ... } for tag content if asked to" do
    expect(h2f_content("<p><span>hi</span></p>", :do_end => true)).to eq(%{p do
  span("hi")
end})
  end

  it "should use Ruby 1.8-style Hashes by default" do
    expect(h2f_content("<p class=\"foo\"/>")).to eq(%{p(:class => "foo")})
  end

  it "should use Ruby 1.9-style Hashes if asked to" do
    expect(h2f_content("<p class=\"foo\"/>", :new_style_hashes => true)).to eq(%{p(class: "foo")})
  end
end
