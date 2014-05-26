describe "html2fortitude tags handling" do
  it "should render a very simple tag with just its name" do
    expect(h2f_content("<p/>")).to eq(%{p})
    expect(h2f_content("<p></p>")).to eq(%{p})
  end

  it "should render a very simple tag with attributes" do
    expect(h2f_content(%{<p foo="bar"/>})).to eq(%{p(:foo => "bar")})
  end

  it "should render several tags back-to-back correctly" do
    expect(h2f_content(%{<p/><br/><p/>})).to eq(%{p
br
p})
  end

  it "should render several tags with attributes back-to-back correctly" do
    expect(h2f_content(%{<p foo="bar"/><br bar="foo"/><p bar="baz"/>})).to eq(%{p(:foo => "bar")
br(:bar => "foo")
p(:bar => "baz")})
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

  it "should render a tag with multiple children of loud output correctly" do
    expect(h2f_content(%{<p><%= foo %><%= bar %></p>})).to eq(%{p {
  text(foo)
  text(bar)
}})
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

  it "should render a tag with a single child of loud output and attributes correctly" do
    expect(h2f_content(%{<p aaa="bbb" ccc="ddd"><%= foo %></p>})).to eq(%{p(foo, :aaa => "bbb", :ccc => "ddd")})
  end

  it "should render a tag with a single child of loud output that needs parentheses and attributes correctly" do
    expect(h2f_content(%{<p aaa="bbb" ccc="ddd"><%= foo :bar, :baz %></p>})).to eq(%{p((foo :bar, :baz), :aaa => "bbb", :ccc => "ddd")})
  end

  it "should render a tag with a single child of quiet output correctly" do
    expect(h2f_content(%{<p><% foo %></p>})).to eq(%{p {
  foo
}})
  end

  it "should render a tag with multiple children of quiet output correctly" do
    expect(h2f_content(%{<p><% foo %><% bar %></p>})).to eq(%{p {
  foo
  bar
}})
  end

  it "should render a tag with intermixed quiet and loud output correctly" do
    expect(h2f_content(%{<p><% foo %><%= bar %><% baz %><%= quux %></p>})).to eq(%{p {
  foo
  text(bar)
  baz
  text(quux)
}})
  end

  it "should turn <script type=\"text/javascript\"> into javascript <<-EOJC ... EOJC" do
    expect(h2f_content(%{<script type="text/javascript">
foo
bar
baz
</script>})).to eq(%{javascript <<-END_OF_JAVASCRIPT_CONTENT
foo
bar
baz
END_OF_JAVASCRIPT_CONTENT})
  end

  it "should turn <script language=\"javascript\"> into javascript <<-EOJC ... EOJC" do
    expect(h2f_content(%{<script language="javascript">
foo
bar
baz
</script>})).to eq(%{javascript <<-END_OF_JAVASCRIPT_CONTENT
foo
bar
baz
END_OF_JAVASCRIPT_CONTENT})
  end

  it "should turn <script type=\"text/javascript\"> with additional attributes into javascript <<-EOJC ... EOJC with those attributes" do
    expect(h2f_content(%{<script type="text/javascript" id="bar">
foo
bar
baz
</script>})).to eq(%{javascript <<-END_OF_JAVASCRIPT_CONTENT, :id => "bar"
foo
bar
baz
END_OF_JAVASCRIPT_CONTENT})
  end

  it "should turn other <script> blocks into just script <<-EOSC ... EOSC" do
    expect(h2f_content(%{<script type="text/vbscript">
foo
bar
baz
</script>})).to eq(%{script <<-END_OF_SCRIPT_CONTENT, :type => "text/vbscript"
foo
bar
baz
END_OF_SCRIPT_CONTENT})
  end

  it "should include attributes in other <script> blocks" do
    result = h2f_content(%{<script type="text/vbscript" id="bar">
foo
bar
baz
</script>})

    if result =~ /^script <<-END_OF_SCRIPT_CONTENT, (.*)$/
      attributes = $1

      expect([
        %{:type => "text/vbscript", :id => "bar"},
        %{:id => "bar", :type => "text/vbscript"}
      ]).to be_include(attributes)
    else
      raise "No match: #{script}"
    end

    expect(result).to match(/^script <<-END_OF_SCRIPT_CONTENT, .*\nfoo\nbar\nbaz\nEND_OF_SCRIPT_CONTENT$/mi)
  end

  it "should turn <style> tags into style <<-EOSC ... EOSC" do
    expect(h2f_content(%{<style>
foo
bar
baz
</style>})).to eq(%{style <<-END_OF_STYLE_CONTENT
foo
bar
baz
END_OF_STYLE_CONTENT})
  end

  it "should turn <style> tags with an attribute into style <<-EOSC, <attribute> ... EOSC" do
    expect(h2f_content(%{<style id="foo">
foo
bar
baz
</style>})).to eq(%{style <<-END_OF_STYLE_CONTENT, :id => "foo"
foo
bar
baz
END_OF_STYLE_CONTENT})
  end
end
