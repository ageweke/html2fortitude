describe "html2fortitude basics" do
  it "should render simple text with #text" do
    expect(h2f_content("hello, world")).to eq("text \"hello, world\"")
  end
end
