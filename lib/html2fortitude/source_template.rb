require 'html2fortitude/html'

module Html2fortitude
  class SourceTemplate
    def initialize(filename, contents, options)
      options.assert_valid_keys(:output, :class_name, :class_base, :superclass, :method, :assigns,
        :do_end, :new_style_hashes, :no_erb)

      @filename = filename
      @contents = contents
      @options = options
    end

    def write_transformed_content!
      html_options = {
        :erb => (! options[:no_erb]),
        :class_name => output_class_name,
        :superclass => options[:superclass],
        :method => options[:method],
        :assigns => options[:assigns],
        :do_end => options[:do_end],
        :new_style_hashes => options[:new_style_hashes]
      }

      html = HTML.new(contents, html_options).render

      if output_filename == '-'
        puts html
      else
        FileUtils.mkdir_p(File.dirname(output_filename))
        File.open(output_filename, 'w') { |f| f << html }
      end
    end

    private
    attr_reader :filename, :contents, :options

    def output_class_name
      if options[:class_name]
        options[:class_name]
      else
        cb = class_base
        if filename.start_with?("#{cb}/")
          filename[(cb.length + 1)..-1].camelize
        else
          raise %{You specified a class base using the -b command-line option:
  #{class_base}
but the file you asked to parse is not underneath that directory:
  #{filename}}
        end
      end
    end

    def class_base
      options[:class_base] || infer_class_base
    end

    def infer_class_base
      if filename =~ %r{^(.*app)/views/.*$}
        File.expand_path($1)
      elsif filename == "-"
        raise %{When converting standard input, you must specify a name for the output class
using the -c command-line option. (Otherwise, we have no way of knowing what to name this widget!)}
      else
        raise %{We can't figure out what the name of the widget class for this file should be:
  #{filename}
You must either specify an explicit name for the class, using the -c command-line option, or
specify a base directory to infer the class name from, using the -b command-line option
(e.g., "-b my_rails_app/app").}
      end
    end

    def output_filename
      if (! options[:output]) && (filename == "-")
        "-"
      elsif (! options[:output])
        if filename =~ /^(.*)\.html\.erb$/i || filename =~ /^(.*)\.rhtml$/i
          "#{$1}.rb"
        else
          "#{filename}.rb"
        end
      elsif File.directory?(options[:output])
        File.join(File.expand_path(options[:output]), "#{output_class_name.underscore}.rb")
      else
        File.expand_path(options[:output])
      end
    end
  end
end
