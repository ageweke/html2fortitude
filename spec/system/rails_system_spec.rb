describe "html2fortitude Rails support" do
  it "should output calls to Rails helpers normally" do
    expect(h2f_content(%{<%= distance_of_time_in_words 5.minutes.from_now %>})).to eq(%{text(distance_of_time_in_words 5.minutes.from_now)})
  end

  it "should not output calls to Rails helpers that are transformed to output already" do
    expect(h2f_content(%{<%= image_tag 'foo' %>})).to eq(%{image_tag 'foo'})
  end
end
