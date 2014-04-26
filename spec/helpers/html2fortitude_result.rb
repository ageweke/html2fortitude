class Html2FortitudeResult
  def initialize(text)
    @text = text
  end

  def content_text
    text.strip
  end

  private
  attr_reader :text
end
