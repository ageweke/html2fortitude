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

  it "should automatically infer the base directory, and the class name from that" do
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

  it "should allow overriding an inferred class name with -c" do
    with_temp_directory("inferred_base_with_override") do
      splat! "app/views/foo/one.html.erb", <<-EOF
hello, world
EOF

      invoke("-c SomeWidget", "app/views/foo/one.html.erb")

      result = h2f_from("app/views/foo/one.rb")
      expect(result.class_name).to eq("SomeWidget")
      expect(result.content_text).to eq(%{text "hello, world"})
    end
  end

  it "should allow manually specifying a base directory with -b" do
    with_temp_directory("explicit_base") do
      splat! "foo/bar/baz/one.html.erb", <<-EOF
hello, world
EOF

      invoke("-b foo/bar", "foo/bar/baz/one.html.erb")

      result = h2f_from("foo/bar/baz/one.rb")
      expect(result.class_name).to eq("Baz::One")
      expect(result.content_text).to eq(%{text "hello, world"})
    end
  end

  it "should allow manually specifying a base directory with -b, and overriding the class name with -c" do
    with_temp_directory("explicit_base_with_override") do
      splat! "foo/bar/baz/one.html.erb", <<-EOF
hello, world
EOF

      invoke("-b foo/bar", "-c MyWidget", "foo/bar/baz/one.html.erb")

      result = h2f_from("foo/bar/baz/one.rb")
      expect(result.class_name).to eq("MyWidget")
      expect(result.content_text).to eq(%{text "hello, world"})
    end
  end

  it "should infer the class base properly, even if you output the file elsewhere" do
    with_temp_directory("inferred_base_with_other_output") do
      splat! "app/views/foo/one.html.erb", <<-EOF
hello, world
EOF

      FileUtils.mkdir_p("bar/baz")
      invoke("app/views/foo/one.html.erb", "-o bar/baz/two.rb")

      result = h2f_from("bar/baz/two.rb")
      expect(result.class_name).to eq("Views::Foo::One")
      expect(result.content_text).to eq(%{text "hello, world"})
    end
  end

  it "should let you override the superclass with -s" do
    with_temp_directory("set_superclass") do
      splat! "one.html.erb", <<-EOF
hello, world
EOF

      invoke("one.html.erb", "-c MyWidget", "-s MyBaseWidget")

      result = h2f_from("one.rb")
      expect(result.class_name).to eq("MyWidget")
      expect(result.superclass).to eq("MyBaseWidget")
      expect(result.content_text).to eq(%{text "hello, world"})
    end
  end

  it "should let you change the method name using --method" do
    with_temp_directory("method_name") do
      splat! "one.html.erb", <<-EOF
hello, world
EOF

      invoke("one.html.erb", "-c MyWidget", "-m foobar")

      result = h2f_from("one.rb")
      expect(result.class_name).to eq("MyWidget")
      expect(result.method_name).to eq("foobar")
      expect(result.content_text).to eq(%{text "hello, world"})
    end
  end

  it "should, by default, map needs to nil" do
    with_temp_directory("default_needs") do
      splat! "one.html.erb", <<-EOF
hello, <%= @first_name %> <%= @last_name %>
EOF

      invoke("one.html.erb", "-c MyWidget")

      result = h2f_from("one.rb")
      expect(result.class_name).to eq("MyWidget")
      expect(result.needs).to eq({ ":first_name" => "nil", ":last_name" => "nil" })
      expect(result.content_text).to eq(%{text "hello, "
text(first_name)
text(last_name)})
    end
  end
end
