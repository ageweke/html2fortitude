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
end
