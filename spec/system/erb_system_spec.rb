describe "html2fortitude ERb support" do
  it "should work with ERb blocks around HTML" do
    expect(h2f_content(%{<% foo do %>
bar
<p class="baz"/>
<% end %>})).to eq(%{foo do
  text "bar"
  p :class => "baz"
end})
  end

  it "should leave space after an ERb block" do
    expect(h2f_content(%{<% foo do %>
bar
<p class="baz"/>
<% end %>
hello, world})).to eq(%{foo do
  text "bar"
  p :class => "baz"
end
text "hello, world"})
  end

  it "should leave blank lines in place after an ERb block" do
    expect(h2f_content(%{<% foo do %>
bar
<p class="baz"/>
<% end %>

hello, world})).to eq(%{foo do
  text "bar"
  p :class => "baz"
end

text "hello, world"})
  end
end
