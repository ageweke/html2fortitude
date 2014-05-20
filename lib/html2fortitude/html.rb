require 'cgi'
require 'nokogiri'
require 'html2fortitude/html/erb'
require 'active_support/core_ext/object'
require 'fortitude/rails/helpers'

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
        if as_string.strip.empty?
          as_string = $1 if as_string =~ /^(.*?[\r\n])[ \t]+$/mi
          return as_string
        end

        text = uninterp(as_string)
        if text =~ /\A((?:\s*[\r\n])*)(.*?)((?:\s*[\r\n])*)\Z/mi
          prefix, middle, suffix = $1, $2, $3
          middle = parse_text_with_interpolation(middle, tabs)
          return prefix + middle + suffix
        else
          return parse_text_with_interpolation(text, tabs)
        end
      end

      private

      def erb_to_interpolation(text, options)
        return text unless options[:erb]
        text = CGI.escapeHTML(uninterp(text))
        %w[<fortitude_loud> </fortitude_loud>].each do |str|
          text.gsub!(CGI.escapeHTML(str), str)
        end

        %w[fortitude_silent fortitude_block].each do |fake_tag_name|
          while text =~ %r{^(.*?)&lt;#{fake_tag_name}&gt;(.*?)&lt;/#{fake_tag_name}&gt;(.*)$}mi
            before, middle, after = $1, $2, $3
            text = before +
              %{
# HTML2FORTITUDE_FIXME_BEGIN: The following code was interpolated into this block using ERb;
# Fortitude isn't a simple string-manipulation engine, so you will have to find another
# way of accomplishing the same result here:
# &lt;%
} +
              middle.split(/\n/).map { |l| "# #{l}" }.join("\n") +
              %{
# %&gt;
} +
              after
          end
        end

        ::Nokogiri::XML.fragment(text).children.inject("") do |str, elem|
          if elem.is_a?(::Nokogiri::XML::Text)
            str + CGI.unescapeHTML(elem.to_s)
          else # <fortitude_loud> element
            data = extract_needs_from!(elem.inner_text.strip, options)
            str + '#{' + CGI.unescapeHTML(data) + '}'
          end
        end
      end

      def extract_needs_from!(text, options)
        text.gsub(/@[\w\d]+/) do |variable_name|
          without_at = variable_name[1..-1]
          options[:needs] << without_at

          if options[:assign_reference] == :instance_variable
            variable_name
          else
            without_at
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

      def can_elide_text_against?(previous_or_next)
        (! previous_or_next) ||
          (previous_or_next.is_a?(::Nokogiri::XML::Element) && (! FORTITUDE_TAGS.include?(previous_or_next.name)))
      end

      def parse_text_with_interpolation(text, tabs)
        return "" if text.empty?

        text = text.lstrip if can_elide_text_against?(previous)
        text = text.rstrip if can_elide_text_against?(self.next)

        "#{tabulate(tabs)}text #{quoted_string_for_text(text)}\n"
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
      options.assert_valid_keys(:erb, :class_name, :superclass, :method, :assigns, :do_end, :new_style_hashes)

      if template.is_a? Nokogiri::XML::Node
        @template = template
      else
        if options[:erb]
          require 'html2fortitude/html/erb'
          template = ERB.compile(template)
        end

        @erb = options[:erb]
        @class_name = options[:class_name] || raise(ArgumentError, "You must specify a class name")
        @superclass = options[:superclass] || raise(ArgumentError, "You must specify a superclass")
        @method = options[:method] || raise(ArgumentError, "You must specify a method name")
        @assigns = (options[:assigns] || raise(ArgumentError, "You must specify :assigns")).to_sym

        @do_end = options[:do_end]
        @new_style_hashes = options[:new_style_hashes]

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
      to_fortitude_options = {
        :erb => @erb,
        :needs => [ ],
        :assign_reference => (@assigns == :instance_variables ? :instance_variable : :method),
        :do_end => @do_end,
        :new_style_hashes => @new_style_hashes
      }

      content_text = @template.to_fortitude(2, to_fortitude_options)

      out = "class #{@class_name} < #{@superclass}\n"
      needs_text = needs_declarations(to_fortitude_options[:needs])
      out << "#{needs_text}\n  \n" if needs_text

      out << "  def #{@method}\n"
      out << "#{content_text.rstrip}\n"
      out << "  end\n"
      out << "end\n"

      out
    end

    private
    def needs_declarations(needs)
      return nil if @assigns == :no_needs

      needs = needs.map { |n| n.to_s.strip.downcase }.uniq.compact.sort
      return nil if needs.empty?

      out = ""
      out << needs.map do |need|
        if [ :needs_defaulted_to_nil, :instance_variables ].include?(@assigns)
          "  needs :#{need} => nil"
        else
          "  needs :#{need}"
        end
      end.join("\n")
      out
    end

    alias_method :to_fortitude, :render

    TEXT_REGEXP = /^(\s*).*$/


    # @see Nokogiri
    # @private
    class ::Nokogiri::XML::Document
      # @see Html2fortitude::HTML::Node#to_fortitude
      def to_fortitude(tabs, options)
        (children || []).inject('') {|s, c| s << c.to_fortitude(tabs, options)}
      end
    end

    class ::Nokogiri::XML::DocumentFragment
      # @see Html2fortitude::HTML::Node#to_fortitude
      def to_fortitude(tabs, options)
        (children || []).inject('') {|s, c| s << c.to_fortitude(tabs, options)}
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
        # "#{tabulate(tabs)}!!! XML\n"
        "#{tabulate(tabs)}rawtext(\"#{self.to_s}\")\n"
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
        "#{tabulate(tabs)}doctype!\n"
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
      BUILT_IN_RENDERING_HELPERS = %w{render}

      def can_skip_text_or_rawtext_prefix?(code)
        return false if code =~ /[\r\n]/mi
        return false if code =~ /;/mi
        method = $1 if code =~ /^\s*([A-Za-z_][A-Za-z0-9_]*[\!\?\=]?)[\s\(]/
        method ||= $1 if code =~ /^\s*([A-Za-z_][A-Za-z0-9_]*[\!\?\=]?)$/
        options = Fortitude::Rails::Helpers.helper_options(method.strip.downcase) if method
        (options && options[:transform] == :output_return_value) ||
          (method && BUILT_IN_RENDERING_HELPERS.include?(method.strip.downcase))
      end

      def code_can_be_used_as_a_method_argument?(code)
        code !~ /[\r\n;]/ && (! can_skip_text_or_rawtext_prefix?(code))
      end

      def is_text_element_starting_with_newline?(node)
        node && node.is_a?(::Nokogiri::XML::Text) && node.to_s =~ /^\s*[\r\n]/
      end

      def is_loud_block!
        @is_loud_block = true
      end

      # @see Html2fortitude::HTML::Node#to_fortitude
      def to_fortitude(tabs, options)
        return "" if converted_to_fortitude

        if name == "script" &&
            (attr_hash['type'].nil? || attr_hash['type'].to_s == "text/javascript") &&
            (attr_hash.keys - ['type']).empty?
          return to_fortitude_filter(:javascript, tabs, options)
        elsif name == "style" &&
            (attr_hash['type'].nil? || attr_hash['type'].to_s == "text/css") &&
            (attr_hash.keys - ['type']).empty?
          return to_fortitude_filter(:css, tabs, options)
        end

        output = tabulate(tabs)
        if options[:erb] && FORTITUDE_TAGS.include?(name)
          case name
          when "fortitude_loud"
            t = extract_needs_from!(CGI.unescapeHTML(inner_text), options)
            lines = t.split("\n").map { |s| s.strip }

            command = if attribute("raw") then "rawtext" else "text" end

            # Handle this case:
            # <%= form_for(@user) do |f| %>
            #   <%= f.whatever %>
            # <% end %>
            if self.next && self.next.is_a?(::Nokogiri::XML::Element) && self.next.name == 'fortitude_block'
              self.next.is_loud_block!
              lines[-1] = "#{command}(" + lines[-1]
            elsif lines.length == 1 && can_skip_text_or_rawtext_prefix?(lines.first)
              # OK, we're good
            else
              lines[-1] = "#{command}(" + lines[-1] + ")"
            end

            return lines.map {|s| output + s + "\n"}.join
          when "fortitude_silent"
            t = extract_needs_from!(CGI.unescapeHTML(inner_text), options)
            return t.split("\n").map do |line|
              next "" if line.strip.empty?
              "#{output}#{line.strip}\n"
            end.join
          when "fortitude_block"
            needs_coda = true unless self.next && self.next.is_a?(::Nokogiri::XML::Element) &&
              self.next.name == 'fortitude_silent' && self.next.inner_text =~ /^\s*els(e|if)\s*$/i
            coda = if needs_coda then "\n#{tabulate(tabs)}end" else "" end
            coda << ")" if @is_loud_block
            coda << "\n"
            children_text = render_children("", tabs, options).rstrip
            return children_text + coda
          end
        end

        output << "#{name}"

        attributes_text = fortitude_attributes(options) if attr_hash && attr_hash.length > 0
        direct_content = nil
        render_children = true

        if children.try(:size) == 1 && children.first.is_a?(::Nokogiri::XML::Text)
          direct_content = quoted_string_for_text(child.to_s.strip)
          render_children = false
        elsif children.try(:size) == 1 && children.first.is_a?(::Nokogiri::XML::Element) &&
          children.first.name == "fortitude_loud" &&
          code_can_be_used_as_a_method_argument?(child.inner_text)

          it = extract_needs_from!(child.inner_text, options)

          direct_content = "#{it.strip}"
          direct_content = "(#{direct_content})" if attributes_text && direct_content =~ /^\s*[A-Za-z_][A-Za-z0-9_]*[\!\?\=]?\s+\S/
          render_children = false
        end

        if attributes_text && direct_content
          output << "(#{direct_content}, #{attributes_text})"
        elsif direct_content
          output << "(#{direct_content})"
        elsif attributes_text
          output << "(#{attributes_text})"
        end

        if render_children && children && children.size >= 1
          children_output = render_children("", tabs, options).strip
          output << " #{element_block_start(options)}\n"
          output << tabulate(tabs + 1)
          output << children_output
          output << "\n#{tabulate(tabs)}#{element_block_end(options)}\n"
        else
          output << "\n" unless is_text_element_starting_with_newline?(self.next)
        end

        output
      end

      private

      def render_children(so_far, tabs, options)
        (self.children || []).inject(so_far) do |output, child|
          output + child.to_fortitude(tabs + 1, options)
          # output + "|#{child.node_type}#{child.to_fortitude(tabs + 1, options)}|"
        end
      end

      def dynamic_attributes(options)
        #reject any attrs without <fortitude>
        return @dynamic_attributes if @dynamic_attributes

        @dynamic_attributes = attr_hash.select {|name, value| value =~ %r{<fortitude.*</fortitude} }
        @dynamic_attributes.each do |name, value|
          fragment = Nokogiri::XML.fragment(CGI.unescapeHTML(value))

          # unwrap interpolation if we can:
          if fragment.children.size == 1 && fragment.child.name == 'fortitude_loud'
            t = extract_needs_from!(fragment.text, options)
            if attribute_value_can_be_bare_ruby?(t)
              value.replace(t.strip)
              next
            end
          end

          # turn erb into interpolations
          fragment.css('fortitude_loud').each do |el|
            inner_text = el.text.strip
            next if inner_text == ""
            inner_text = extract_needs_from!(inner_text, options)
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
        return true if ruby.sexp_type == :call  #local var or method

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
=begin
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
=end

        content.strip!
        content << "\n"

        "#{tabulate(tabs)}#{filter} <<-END_OF_#{filter.to_s.upcase}_CONTENT\n#{content.rstrip}\n#{tabulate(tabs)}END_OF_#{filter.to_s.upcase}_CONTENT"
      end

      def element_block_start(options)
        if options[:do_end]
          "do"
        else
          "{"
        end
      end

      def element_block_end(options)
        if options[:do_end]
          "end"
        else
          "}"
        end
      end

      # TODO: this method is utterly awful, find a better way to decode HTML entities.
      def decode_entities(str)
        return str
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
        options[:erb] and dynamic_attributes(options).key?(name)
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
        value = dynamic_attribute?(name, options) ? dynamic_attributes(options)[name] : value.inspect

        if name.index(/\W/)
          "#{name.inspect} => #{value}"
        else
          if options[:new_style_hashes]
            "#{name}: #{value}"
          else
            ":#{name} => #{value}"
          end
        end
      end
    end
  end
end
