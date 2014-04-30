class Html2FortitudeResult
  def initialize(text)
    lines = text.split(/[\r\n]/)
    if lines.shift =~ /^\s*class\s*(\S+)\s+<\s+(\S+)\s*$/i
      @class_name = $1
      @superclass = $2
    else
      raise "Can't find 'class' declaration in: #{text}"
    end

    @needs = { }

    lines.shift while lines[0] =~ /^\s*$/i

    while lines[0] =~ /^\s*needs\s*(.*?)\s*$/i
      need_name = $1
      need_value = nil

      if need_name =~ /^(.*)\s*=>\s*(.*?)\s*$/i
        need_name = $1
        need_value = $2
      end

      @needs[need_name] = need_value

      lines.shift
    end

    lines.shift while lines[0] =~ /^\s*$/i

    if lines[0] =~ /^\s+def\s+(\S+)\s*$/i
      @method_name = $1
      lines.shift
    else
      raise "Can't find 'def' in: #{text}"
    end

    lines.pop while lines[-1] =~ /^\s*$/i
    if lines[-1] =~ /^\s*end\s*$/i
      lines.pop
    else
      raise "Can't find last 'end' in: #{text}"
    end

    lines.pop while lines[-1] =~ /^\s*$/i
    if lines[-1] =~ /^\s*end\s*$/i
      lines.pop
    else
      raise "Can't find last 'end' in: #{text}"
    end

    @content_lines = lines
    @content_lines = @content_lines.map do |content_line|
      content_line = content_line.rstrip
      if content_line[0..3] == '    '
        content_line[4..-1]
      else
        content_line
      end
    end
  end

  def content_text
    @content_lines.join("\n")
  end

  private
  attr_reader :text
end
