describe "html2fortitude 'other stuff' support" do
  it "should emit XML Processing Instructions correctly" do
    expect(h2f_content("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")).to eq(
      %{rawtext("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")})
  end

  it "should emit CDATA correctly" do
    expect(h2f_content(%{hello <![CDATA[
foo
bar
]]>
world})).to eq(%{text "hello "
cdata <<-END_OF_CDATA_CONTENT
foo
bar
END_OF_CDATA_CONTENT
text "world"})
  end

  it "should emit DTDs correctly" do
    expect(h2f_content(%{<!DOCTYPE html>})).to eq(%{doctype!})
  end

  it "should emit comments correctly" do
    expect(h2f_content(%{hello <!-- something here --> world})).to eq(%{text "hello "
comment "something here"
text " world"})
  end

  it "should emit multiline comments correctly" do
    expect(h2f_content(%{hello <!-- something
here
yo --> world})).to eq(%{text "hello "
comment %{something
here
yo}
text " world"})
  end
end
