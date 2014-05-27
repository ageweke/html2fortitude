describe "html2fortitude command-line usage" do
  it "should return help if passed --help" do
    with_temp_directory("help") do
      result = invoke("--help")
      expect(result).to match(/Fortitude/mi)
      expect(result).to match(/html2fortitude/mi)
      expect(result).to match(/\-\-output/mi)
    end
  end

  it "should transform a simple file to the same location by default" do
    with_temp_directory("simple_file") do
      splat! "one.html.erb", <<-EOF
hello, world
EOF

      output = invoke("-c MyWidget", "one.html.erb")
      expect(output).to match(/one\.html\.erb\s*\-\>\s*.*one\.rb/)

      result = h2f_from("one.rb")
      expect(result.class_name).to eq("MyWidget")
      expect(result.superclass).to eq("Fortitude::Widget::Html5")
      expect(result.content_text).to eq(%{text "hello, world"})
      expect(result.method_name).to eq("content")
      expect(result.needs).to eq({ })
    end
  end

  it "should let you select the output file with -o" do
    with_temp_directory("output_file") do
      splat! "one.html.erb", <<-EOF
hello, world
EOF

      output = invoke("-c MyWidget", "-o foo.bar.xxx", "one.html.erb")
      expect(output).to match(/one\.html\.erb\s*\-\>\s*.*foo\.bar\.xxx/)

      result = h2f_from("foo.bar.xxx")
      expect(result.content_text).to eq(%{text "hello, world"})
    end
  end

  it "should let you select the class name with -c" do
    with_temp_directory("output_file") do
      splat! "one.html.erb", <<-EOF
hello, world
EOF

      invoke("-c SomeThingYo", "one.html.erb")

      result = h2f_from("one\.rb")
      expect(result.class_name).to eq("SomeThingYo")
      expect(result.content_text).to eq(%{text "hello, world"})
    end
  end

  it "should automatically infer the base directory" do
    with_temp_directory("inferred_base") do
      splat! "app/views/foo/one.html.erb", <<-EOF
hello, world
EOF

      invoke("app/views/foo/one.html.erb")

      result = h2f_from("app/views/foo/one.rb")
      expect(result.class_name).to eq("Views::Foo::One")
      expect(result.content_text).to eq(%{text "hello, world"})
    end
  end
end
