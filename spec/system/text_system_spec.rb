describe "html2fortitude text translation" do
  it "should render simple text with #text" do
    expect(h2f_content("hello, world")).to eq("text \"hello, world\"")
  end

  it "should properly escape text that requires escaping" do
    expect(h2f_content("hello, \"world")).to eq("text \"hello, \\\"world\"")
  end

  it "should not escape text that doesn't require escaping" do
    expect(h2f_content("hello, 'world")).to eq("text \"hello, 'world\"")
  end

  it "should allow dynamic content in text" do
    expect(h2f_content("hello, <% abc %> world")).to eq(
      %{text "hello, "
abc
text " world"})
  end

  it "should properly handle multiline text"
end
