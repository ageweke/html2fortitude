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
end
