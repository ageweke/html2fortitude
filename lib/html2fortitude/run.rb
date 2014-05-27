require 'trollop'
require 'find'
require 'html2fortitude/source_template'

module Html2fortitude
  class Run
    def initialize(argv)
      @argv = argv
    end

    def run!
      parse_arguments!

      for_each_input_file do |name_and_block|
        name = name_and_block[:name]
        block = name_and_block[:block]

        contents = nil
        block.call { |io| contents = io.read }

        effective_options = trollop_options.select do |key, value|
          %w{output class_name class_base superclass method assigns do_end new_style_hashes}.include?(key.to_s)
        end

        source_template = Html2fortitude::SourceTemplate.new(name, contents, effective_options)
        source_template.write_transformed_content!

        puts "#{source_template.filename} -> #{source_template.output_filename} (#{source_template.line_count} lines)"
      end
    end

    private
    def for_each_input_file(&block)
      @argv.each do |file_or_directory|
        if file_or_directory == '-'
          block.call({ :name => '-', :block => lambda { |&block| block.call($stdin) } })
          next
        end

        file_or_directory = File.expand_path(file_or_directory)
        raise Errno::ENOENT, "No such file or directory: #{file_or_directory}" unless File.exist?(file_or_directory)

        files = [ ]
        if File.directory?(file_or_directory)
          Find.find(file_or_directory) do |f|
            f = File.expand_path(f, file_or_directory)
            files << f if File.file?(f)
          end
        else
          files << file_or_directory
        end

        files.each do |file|
          block.call(:name => file, :block => lambda { |&block| File.open(file, &block) })
        end
      end
    end

    def parse_arguments!
      trollop_options
    end

    def trollop_options
      @trollop_parser ||= Trollop::Parser.new do
        version "html2fortitude version #{Html2fortitude::VERSION}"
        banner <<-EOS
html2fortitude transforms HTML source files (with or without ERb embedded)
into Fortitude (https://github.com/ageweke/fortitude) source code.

Usage:
  html2fortitude [options] file|directory [file|directory...]
where [options] are:
EOS

        opt :output,     "Output file or directory", :type => String

        opt :class_name, "Class name for created Fortitude class", :type => String
        opt :class_base, "Base directory for input files (e.g., my_rails_app/app) to use when --class-name is not specified", :type => String, :short => 'b'
        opt :superclass, "Name of the class to inherit the output class from", :type => String, :default => 'Fortitude::Widget::Html5'

        opt :method,     "Name of method to write in widget (default 'content')", :type => String, :default => 'content'
        opt :assigns,    %{Method for using assigns passed to the widget:
  needs_defaulted_to_nil: (default) standard Fortitude 'needs', but with a default of 'nil', so all needs are optional
  required_needs:         standard Fortitude 'needs', no default; widget will not render without all needs specified (dangerous)
  instance_variables:     Ruby instance variables; requires that a base class of the widget sets 'use_instance_variables_for_assigns true'
  no_needs:               Omit a 'needs' declaration entirely; requires that a base class sets 'extra_assigns use'},
            :type => String, :default => 'needs_defaulted_to_nil'

        opt :do_end,     "Use do ... end for blocks passed to tag methods, not { ... } (does not affect blocks from ERb)", :type => :boolean
        opt :new_style_hashes, "Use hash_style: ruby19 instead of :hash_style => :ruby_18", :type => :boolean
      end

      @trollop_options ||= begin
        Trollop::with_standard_exception_handling(@trollop_parser) do
          raise Trollop::HelpNeeded if @argv.empty? # show help screen
          @trollop_parser.parse @argv
        end
      end
    end
  end
end
