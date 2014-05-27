describe "html2fortitude 'needs' conversion" do
  it "should produce no needs if there are no needs" do
    result = h2f("hello, world")
    expect(result.needs).to eq({ })
    expect(result.content_text).to eq("text \"hello, world\"")
  end

  it "should produce a single need, mapped to nil, if there's just one" do
    result = h2f("hello, <%= @foo %>")
    expect(result.needs).to eq({ ":foo" => "nil" })
    expect(result.content_text).to eq(%{text "hello, "
text(foo)})
  end

  it "should produce multiple needs, mapped to nil, if there are multiple" do
    result = h2f("hello, <%= @foo + @bar %>, <%= @baz %>")
    expect(result.needs).to eq({
      ":foo" => "nil", ":bar" => "nil", ":baz" => "nil"
    })
    expect(result.content_text).to eq(%{text "hello, "
text(foo + bar)
text ", "
text(baz)})
  end

  it "should produce needs with no mapping if asked to" do
    result = h2f("hello, <%= @foo %>", :assigns => :required_needs)
    expect(result.needs).to eq({ ":foo" => nil })
    expect(result.content_text).to eq(%{text "hello, "
text(foo)})
  end

  it "should produce multiple needs with no mapping if asked to" do
    result = h2f("hello, <%= @foo + @bar %>", :assigns => :required_needs)
    expect(result.needs).to eq({ ":foo" => nil, ":bar" => nil })
    expect(result.content_text).to eq(%{text "hello, "
text(foo + bar)})
  end

  it "should turn off needs entirely if asked to" do
    result = h2f("hello, <%= @foo + @bar %>", :assigns => :no_needs)
    expect(result.needs).to eq({ })
    expect(result.content_text).to eq(%{text "hello, "
text(foo + bar)})
  end

  it "should produce instance variables in text if asked to" do
    result = h2f("hello, <%= @foo + @bar %>", :assigns => :instance_variables)
    expect(result.needs).to eq({ ":foo" => "nil", ":bar" => "nil" })
    expect(result.content_text).to eq(%{text "hello, "
text(@foo + @bar)})
  end

  it "should extract 'needs' from loud ERb" do
    result = h2f("hello, <%= @foo %>")
    expect(result.needs).to eq({ ":foo" => "nil" })
    expect(result.content_text).to eq(%{text "hello, "
text(foo)})
  end

  it "should extract 'needs' from silent ERb" do
    result = h2f("hello, <% @foo %>")
    expect(result.needs).to eq({ ":foo" => "nil" })
    expect(result.content_text).to eq(%{text "hello, "
foo})
  end

  it "should extract 'needs' from code used as a direct argument to a tag" do
    result = h2f("<p><%= @foo %></p>")
    expect(result.needs).to eq({ ":foo" => "nil" })
    expect(result.content_text).to eq(%{p(foo)})
  end
end
