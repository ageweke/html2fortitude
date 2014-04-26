require 'helpers/html2fortitude_result'
require 'html2fortitude/html'

module StandardHelper
  def h2f(input)
    Html2FortitudeResult.new(Html2fortitude::HTML.new(input, { :erb => true }).render)
  end

  def h2f_content(input)
    h2f(input).content_text
  end
end
