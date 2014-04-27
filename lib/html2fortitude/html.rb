require 'cgi'
require 'nokogiri'
require 'html2fortitude/html/erb'

# Html2fortitude monkeypatches various Nokogiri classes
# to add methods for conversion to Fortitude.
# @private
module Nokogiri

  module XML
    # @see Nokogiri
    class Node
      # Whether this node has already been converted to Fortitude.
      # Only used for text nodes and elements.
      #
      # @return [Boolean]
      attr_accessor :converted_to_fortitude

      # Returns the Fortitude representation of the given node.
      #
      # @param tabs [Fixnum] The indentation level of the resulting Fortitude.
      # @option options (see Html2fortitude::HTML#initialize)
      def to_fortitude(tabs, options)
        return "" if converted_to_fortitude

        as_string = self.to_s
        return "" if as_string.strip.empty? && as_string !~ /[\r\n]/mi
        return as_string if as_string.strip.empty?

        text = uninterp(as_string)
        text = text.chomp if self.next && self.next.is_a?(::Nokogiri::XML::Element)
        text = $1 if text =~ /^[\r\n](.*)$/mi && self.previous && self.previous.is_a?(::Nokogiri::XML::Element)
        return parse_text_with_interpolation(text, tabs)
      end

      private

      def erb_to_interpolation(text, options)
        return text unless options[:erb]
        text = CGI.escapeHTML(uninterp(text))
        %w[<fortitude_loud> </fortitude_loud>].each {|str| text.gsub!(CGI.escapeHTML(str), str)}
        ::Nokogiri::XML.fragment(text).children.inject("") do |str, elem|
          if elem.is_a?(::Nokogiri::XML::Text)
            str + CGI.unescapeHTML(elem.to_s)
          else # <fortitude_loud> element
            str + '#{' + CGI.unescapeHTML(elem.inner_text.strip) + '}'
          end
        end
      end

      def tabulate(tabs)
        '  ' * tabs
      end

      def uninterp(text)
        text.gsub('#{', '\#{') #'
      end

      def attr_hash
        Hash[attributes.map {|k, v| [k.to_s, v.to_s]}]
      end

      def parse_text(text, tabs)
        parse_text_with_interpolation(uninterp(text), tabs)
      end

      def escape_single_line_text(text)
        text.gsub(/"/) { |m| "\\" + m }
      end

      def escape_multiline_text(text)
        text.gsub(/\}/, '\\}')
      end

      def parse_text_with_interpolation(text, tabs)
        return "" if text.empty?

        "#{tabulate(tabs)}text #{quoted_string_for_text(text)}\n"
      end

      def code_can_be_used_as_a_method_argument?(code)
        code !~ /[\r\n;]/
      end

      def quoted_string_for_text(text)
        if text =~ /[\r\n]/
          text = "%{#{escape_multiline_text(text)}}"
        else
          text = "\"#{escape_single_line_text(text)}\""
        end
      end
    end
  end
end

# @private
FORTITUDE_TAGS = %w[fortitude_block fortitude_loud fortitude_silent]
#
# FORTITUDE_TAGS.each do |t|
#   Nokogiri::XML::ElementContent[t] = {}
#   Nokogiri::XML::ElementContent.keys.each do |key|
#     Nokogiri::XML::ElementContent[t][key.hash] = true
#   end
# end
#
# Nokogiri::XML::ElementContent.keys.each do |k|
#   FORTITUDE_TAGS.each do |el|
#     val = Nokogiri::XML::ElementContent[k]
#     val[el.hash] = true if val.is_a?(Hash)
#   end
# end

module Html2fortitude
  # Converts HTML documents into Fortitude templates.
  # Depends on [Nokogiri](http://nokogiri.org/) for HTML parsing.
  # If ERB conversion is being used, also depends on
  # [Erubis](http://www.kuwata-lab.com/erubis) to parse the ERB
  # and [ruby_parser](http://parsetree.rubyforge.org/) to parse the Ruby code.
  #
  # Example usage:
  #
  #     HTML.new("<a href='http://google.com'>Blat</a>").render
  #       #=> "%a{:href => 'http://google.com'} Blat"
  class HTML
    # @param template [String, Nokogiri::Node] The HTML template to convert
    # @option options :erb [Boolean] (false) Whether or not to parse
    #   ERB's `<%= %>` and `<% %>` into Fortitude's `text()` and (standard code)
    # @option options :xhtml [Boolean] (false) Whether or not to parse
    #   the HTML strictly as XHTML
    def initialize(template, options = {})
      @options = options

      if template.is_a? Nokogiri::XML::Node
        @template = template
      else
        if template.is_a? IO
          template = template.read
        end

        # TODO ageweke
        # template = Haml::Util.check_encoding(template) {|msg, line| raise Haml::Error.new(msg, line)}

        if @options[:erb]
          require 'html2fortitude/html/erb'
          template = ERB.compile(template)
        end

        if template =~ /^\s*<!DOCTYPE|<html/i
          return @template = Nokogiri.HTML(template)
        end

        @template = Nokogiri::HTML.fragment(template)

        #detect missplaced head or body tag
        #XML_HTML_STRUCURE_ERROR : 800
        if @template.errors.any? { |e| e.code == 800 }
          return @template = Nokogiri.HTML(template).at('/html').children
        end

        #in order to support CDATA in HTML (which is invalid) try using the XML parser
        # we can detect this when libxml returns error code XML_ERR_NAME_REQUIRED : 68
        if @template.errors.any? { |e| e.code == 68 } || template =~ /CDATA/
          return @template = Nokogiri::XML.fragment(template)
        end
      end
    end

    # Processes the document and returns the result as a string
    # containing the Fortitude template.
    def render
      @template.to_fortitude(0, @options)
    end
    alias_method :to_fortitude, :render

    TEXT_REGEXP = /^(\s*).*$/


    # @see Nokogiri
    # @private
    class ::Nokogiri::XML::Document
      # @see Html2fortitude::HTML::Node#to_fortitude
      def to_fortitude(tabs, options)
        (children || []).inject('') {|s, c| s << c.to_fortitude(0, options)}
      end
    end

    class ::Nokogiri::XML::DocumentFragment
      # @see Html2fortitude::HTML::Node#to_fortitude
      def to_fortitude(tabs, options)
        (children || []).inject('') {|s, c| s << c.to_fortitude(0, options)}
      end
    end

    class ::Nokogiri::XML::NodeSet
      # @see Html2fortitude::HTML::Node#to_fortitude
      def to_fortitude(tabs, options)
        self.inject('') {|s, c| s << c.to_fortitude(tabs, options)}
      end
    end

    # @see Nokogiri
    # @private
    class ::Nokogiri::XML::ProcessingInstruction
      # @see Html2fortitude::HTML::Node#to_fortitude
      def to_fortitude(tabs, options)
        "#{tabulate(tabs)}!!! XML\n"
      end
    end

    # @see Nokogiri
    # @private
    class ::Nokogiri::XML::CDATA
      # @see Html2fortitude::HTML::Node#to_fortitude
      def to_fortitude(tabs, options)
        content = parse_text_with_interpolation(
          erb_to_interpolation(self.content, options), tabs + 1)
        "#{tabulate(tabs)}:cdata\n#{content}"
      end

      # removes the start and stop markers for cdata
      def content_without_cdata_tokens
        content.
          gsub(/^\s*<!\[CDATA\[\n/,"").
          gsub(/^\s*\]\]>\n/, "")
      end
    end

    # @see Nokogiri
    # @private
    class ::Nokogiri::XML::DTD
      # @see Html2fortitude::HTML::Node#to_fortitude
      def to_fortitude(tabs, options)
        attrs = external_id.nil? ? ["", "", ""] :
          external_id.scan(/DTD\s+([^\s]+)\s*([^\s]*)\s*([^\s]*)\s*\/\//)[0]
        # TODO ageweke
        # raise Haml::SyntaxError.new("Invalid doctype") if attrs == nil

        type, version, strictness = attrs.map { |a| a.downcase }
        if type == "html"
          version = ""
          strictness = "strict" if strictness == ""
        end

        if version == "1.0" || version.empty?
          version = nil
        end

        if strictness == 'transitional' || strictness.empty?
          strictness = nil
        end

        version = " #{version.capitalize}" if version
        strictness = " #{strictness.capitalize}" if strictness

        "#{tabulate(tabs)}!!!#{version}#{strictness}\n"
      end
    end

    # @see Nokogiri
    # @private
    class ::Nokogiri::XML::Comment
      # @see Html2fortitude::HTML::Node#to_fortitude
      def to_fortitude(tabs, options)
        content = self.content
        if content =~ /\A(\[[^\]]+\])>(.*)<!\[endif\]\z/m
          condition = $1
          content = $2
        end

        if content.include?("\n")
          "#{tabulate(tabs)}/#{condition}\n#{parse_text(content, tabs + 1)}"
        else
          "#{tabulate(tabs)}/#{condition} #{content.strip}\n"
        end
      end
    end

    # @see Nokogiri
    # @private
    class ::Nokogiri::XML::Element
      # @see Html2fortitude::HTML::Node#to_fortitude
      def to_fortitude(tabs, options)
        return "" if converted_to_fortitude

=begin
        if name == "script" &&
            (attr_hash['type'].nil? || attr_hash['type'].to_s == "text/javascript") &&
            (attr_hash.keys - ['type']).empty?
          return to_fortitude_filter(:javascript, tabs, options)
        elsif name == "style" &&
            (attr_hash['type'].nil? || attr_hash['type'].to_s == "text/css") &&
            (attr_hash.keys - ['type']).empty?
          return to_fortitude_filter(:css, tabs, options)
        end
=end

        output = tabulate(tabs)
        if options[:erb] && FORTITUDE_TAGS.include?(name)
          case name
          when "fortitude_loud"
            lines = CGI.unescapeHTML(inner_text).split("\n").map { |s| s.strip }
            command = if attribute("raw") then "rawtext" else "text" end
            lines[-1] = "#{command}(" + lines[-1] + ")"
            return lines.map {|s| output + s + "\n"}.join
          when "fortitude_silent"
            return CGI.unescapeHTML(inner_text).split("\n").map do |line|
              next "" if line.strip.empty?
              "#{output}#{line.strip}\n"
            end.join
          when "fortitude_block"
            return render_children("", tabs, options).rstrip + "\n#{tabulate(tabs)}end\n"
          end
        end

        if self.next && self.next.text? && self.next.content =~ /\A[^\s]/
          if self.previous.nil? || self.previous.text? &&
              (self.previous.content =~ /[^\s]\Z/ ||
               self.previous.content =~ /\A\s*\Z/ && self.previous.previous.nil?)
            nuke_outer_whitespace = true
          else
            output << "= succeed #{self.next.content.slice!(/\A[^\s]+/).dump} do\n"
            tabs += 1
            output << tabulate(tabs)
            #empty the text node since it was inserted into the block
            self.next.content = ""
          end
        end

        output << "#{name}"
        output << " #{fortitude_attributes(options)}" if attr_hash && attr_hash.length > 0

        output << ">" if nuke_outer_whitespace

        has_children = children && children.size >= 1

        can_inline = children && children.size == 1 &&
          (children.first.is_a?(::Nokogiri::XML::Text) ||
            (children.first.is_a?(::Nokogiri::XML::Element) && children.first.name == "fortitude_loud"))

        if children.first.is_a?(::Nokogiri::XML::Text)
          output << " "
          output << quoted_string_for_text(child.to_s)
        elsif children.first.is_a?(::Nokogiri::XML::Element) && children.first.name == "fortitude_loud" &&
          code_can_be_used_as_a_method_argument?(child.inner_text)

          output << "(" + child.inner_text.strip + ")"
        elsif has_children
          output = (render_children("#{output} {", tabs, options) + "#{tabulate(tabs)}}")
        end

        output
      end

      private

      def render_children(so_far, tabs, options)
        (self.children || []).inject(so_far) do |output, child|
          output + child.to_fortitude(tabs + 1, options)
        end
      end

      def dynamic_attributes
        #reject any attrs without <fortitude>
        return @dynamic_attributes if @dynamic_attributes

        @dynamic_attributes = attr_hash.select {|name, value| value =~ %r{<fortitude.*</fortitude} }
        @dynamic_attributes.each do |name, value|
          fragment = Nokogiri::XML.fragment(CGI.unescapeHTML(value))

          # unwrap interpolation if we can:
          if fragment.children.size == 1 && fragment.child.name == 'fortitude_loud'
            if attribute_value_can_be_bare_ruby?(fragment.text)
              value.replace(fragment.text.strip)
              next
            end
          end

          # turn erb into interpolations
          fragment.css('fortitude_loud').each do |el|
            inner_text = el.text.strip
            next if inner_text == ""
            el.replace('#{' + inner_text + '}')
          end

          # put the resulting text in a string
          value.replace('"' + fragment.text.strip + '"')
        end
      end

      def attribute_value_can_be_bare_ruby?(value)
        begin
          ruby = RubyParser.new.parse(value)
        rescue Racc::ParseError, RubyParser::SyntaxError
          return false
        end

        return false if ruby.nil?
        return true if ruby.sexp_type == :str   #regular string
        return true if ruby.sexp_type == :dstr  #string with interpolation
        return true if ruby.sexp_type == :lit   #symbol
        return true if ruby.sexp_type == :call && ruby.mass == 1 #local var or method with no params

        false
      end


      def to_fortitude_filter(filter, tabs, options)
        content =
          if children.first && children.first.cdata?
            decode_entities(children.first.content_without_cdata_tokens)
          else
            decode_entities(self.inner_text)
          end

        content = erb_to_interpolation(content, options)
        content.gsub!(/\A\s*\n(\s*)/, '\1')
        original_indent = content[/\A(\s*)/, 1]
        if content.split("\n").all? {|l| l.strip.empty? || l =~ /^#{original_indent}/}
          content.gsub!(/^#{original_indent}/, tabulate(tabs + 1))
        else
          # Indentation is inconsistent. Strip whitespace from start and indent all
          # to ensure valid Fortitude.
          content.lstrip!
          content.gsub!(/^/, tabulate(tabs + 1))
        end

        content.rstrip!
        content << "\n"

        "#{tabulate(tabs)}:#{filter}\n#{content}"
      end

      # TODO: this method is utterly awful, find a better way to decode HTML entities.
      def decode_entities(str)
        str.gsub(/&[\S]+;/) do |entity|
          begin
            [Nokogiri::HTML::NamedCharacters[entity[1..-2]]].pack("C")
          rescue TypeError
            entity
          end
        end
      end

      def static_attribute?(name, options)
        attr_hash[name] && !dynamic_attribute?(name, options)
      end

      def dynamic_attribute?(name, options)
        options[:erb] and dynamic_attributes.key?(name)
      end

      def static_id?(options)
        static_attribute?('id', options) && fortitude_css_attr?(attr_hash['id'])
      end

      def static_classname?(options)
        static_attribute?('class', options)
      end

      def fortitude_css_attr?(attr)
        attr =~ /^[-:\w]+$/
      end

      # Returns a string representation of an attributes hash
      # that's prettier than that produced by Hash#inspect
      def fortitude_attributes(options)
        attrs = attr_hash.sort.map do |name, value|
          fortitude_attribute_pair(name, value.to_s, options)
        end
        "#{attrs.join(', ')}"
      end

      # Returns the string representation of a single attribute key value pair
      def fortitude_attribute_pair(name, value, options)
        value = dynamic_attribute?(name, options) ? dynamic_attributes[name] : value.inspect

        if name.index(/\W/)
          "#{name.inspect} => #{value}"
        else
          ":#{name} => #{value}"
        end
      end
    end
  end
end