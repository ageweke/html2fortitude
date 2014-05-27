describe "html2fortitude command-line usage" do
  it "should return help if passed --help" do
    with_temp_directory("help") do
      result = invoke("--help")
      expect(result).to match(/Fortitude/mi)
      expect(result).to match(/html2fortitude/mi)
      expect(result).to match(/\-\-output/mi)
    end
  end
end
