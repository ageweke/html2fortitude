require 'helpers/html2fortitude_result'
require 'html2fortitude/html'

module StandardHelper
  def default_html_options
    {
      :erb => true,
      :class_name => "SpecClass",
      :superclass => "Fortitude::Widget::Html5",
      :method => "content",
      :assigns => :needs_defaulted_to_nil,
      :do_end => false,
      :new_style_hashes => false
    }
  end

  def h2f(input, options = { })
    Html2FortitudeResult.new(Html2fortitude::HTML.new(input, default_html_options.merge(options)).render)
  end

  def h2f_content(input, options = { })
    h2f(input, options).content_text
  end

  def h2f_from(filename)
    Html2FortitudeResult.new(get(filename))
  end

  def invoke(*args)
    cmd = "#{binary_path} #{args.join(" ")} 2>&1"
    output = `#{cmd}`
    unless $?.success?
      raise "Invocation failed: ran: #{cmd}\nin: #{Dir.pwd}\nand got: #{$?.inspect}\nwith output:\n#{output}"
    end
    output
  end

  def splat!(filename, data)
    File.open(filename, 'w') { |f| f << data }
  end

  def get(filename)
    raise Errno::ENOENT, "No such file: #{filename.inspect}" unless File.file?(filename)
    File.read(filename).strip
  end

  def with_temp_directory(name, &block)
    directory = File.join(temp_directory_base, name)
    FileUtils.rm_rf(directory) if File.exist?(directory)
    FileUtils.mkdir_p(directory)
    Dir.chdir(directory, &block)
  end

  private
  def temp_directory_base
    @temp_directory_base ||= begin
      out = File.join(gem_root, 'tmp', 'specs')
      FileUtils.mkdir_p(out)
      out
    end
  end

  def gem_root
    @gem_root ||= File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
  end

  def binary_path
    @binary_path ||= File.join(gem_root, 'bin', 'html2fortitude')
  end
end
