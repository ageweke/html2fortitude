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

        # Eliminate whitespace that has no newlines
        as_string = self.to_s
        return "" if as_string.strip.empty? && as_string !~ /[\r\n]/mi

        if as_string.strip.empty?
          # If we get here, it's whitespace, but containing newlines; eliminate trailing indentation
          as_string = $1 if as_string =~ /^(.*?[\r\n])[ \t]+$/mi
          return as_string
        end

        # We have actual content if we get here; deal with leading and trailing newline/whitespace combinations properly
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

      # Converts a string that may contain ERb interpolation into valid Fortitude code.
      #
      # This is actually NOT called in nearly all the cases you might imagine. Generally speaking, our strategy is to
      # convert ERb interpolation into faux-HTML tags (<fortitude_loud>, <fortitude_silent>, and <fortitude_block>),
      # and use Nokogiri to parse the resulting "HTML"; we then transform elements properly, converting most into
      # Fortitude tags (e.g., 'p', 'div', etc.) and converting, _e.g._, <fortitude_loud>...</fortitude_loud> into
      # 'text(...)', <fortitude_silent>...</fortitude_silent> into just '...', and so on.
      #
      # However, in certain cases -- like the content of <script> and <style> tags -- we need to convert an entire
      # string, at once, to Fortitude, because the content of those tags is special; it's not parsed as HTML.
      # This method does exactly that.
      #
      # There is, however, one case we cannot trivially convert. If you do something like this with ERb:
      #
      #     <script>
      #       var message = "You are ";
      #       <% if @current_user.admin? %>
      #       message = message + "an admin";
      #       <% else %>
      #       message = message + "a user";
      #       <% end %>
      #       ...
      #     </script>
      #
      # Then there actually _is_ no valid Fortitude transformation of this block -- because here you're using ERb as
      # a Javascript text-substitution preprocessor, not an HTML-generation engine. Short of actually having
      # Fortitude invoke ERb at runtime, there's no simple answer here.
      #
      # Instead, we choose to emit this with a big FIXME comment around it, saying that you need to fix it yourself;
      # most cases actually don't seem to be very hard to fix, as long as you know about it.
      def erb_to_interpolation(text, options)
        return text unless options[:erb]
        # Escape the text...
        text = CGI.escapeHTML(uninterp(text))
        # Unescape our <fortitude_loud> tags.
        %w[<fortitude_loud> </fortitude_loud>].each do |str|
          text.gsub!(CGI.escapeHTML(str), str)
        end

        # Find any instances of the escaped form of tags we're not compatible with, and put in the FIXME comments.
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

      # Given a string of text, extracts the 'needs' declarations we'll, ahem, need from it in order to render it --
      # in short, just the instance variables we see in it -- and adds them to options[:needs]. Returns a version of
      # +text+ with instance variable references replaced with +needs+ references; this typically just means converting,
      # _e.g._, +@foo+ to +foo+, although we leave it alone if you've told us that you're going to use Fortitude in
      # that mode.
      def extract_needs_from!(text, options)
        text.gsub(/@[A-Za-z0-9_]+/) do |variable_name|
          without_at = variable_name[1..-1]
          options[:needs] << without_at

          if options[:assign_reference] == :instance_variable
            variable_name
          else
            without_at
          end
        end
      end

      TAB_SIZE = 2

      # Returns a number of spaces equivalent to that many tabs.
      def tabulate(tabs)
        ' ' * TAB_SIZE * tabs
      end

      # Replaces actual "#{" strings with the escaped version thereof.
      def uninterp(text)
        text.gsub('#{', '\#{') #'
      end

      # Returns a Hash of the attributes for this node. This just transforms the internal Nokogiri attribute list
      # (which is an Array) into a Hash.
      def attr_hash
        Hash[attributes.map {|k, v| [k.to_s, v.to_s]}]
      end

      # Turns a String into a Fortitude 'text' command.
      def parse_text(text, tabs)
        parse_text_with_interpolation(uninterp(text), tabs)
      end

      # Escapes single-line text properly.
      def escape_single_line_text(text)
        text.gsub(/"/) { |m| "\\" + m }
      end

      # Escapes multi-line text properly.
      def escape_multiline_text(text)
        text.gsub(/\}/, '\\}')
      end

      # Given another Node (which can be nil), tells us whether we can elide any whitespace present between this node
      # and that node. This is true only if the next-or-previous node is an Element and not one of our special
      # <fortitude...> elements.
      def can_elide_whitespace_against?(previous_or_next)
        (! previous_or_next) ||
          (previous_or_next.is_a?(::Nokogiri::XML::Element) && (! FORTITUDE_TAGS.include?(previous_or_next.name)))
      end

      # Given text, produces a valid Fortitude command to output that text.
      def parse_text_with_interpolation(text, tabs)
        return "" if text.empty?

        text = text.lstrip if can_elide_whitespace_against?(previous)
        text = text.rstrip if can_elide_whitespace_against?(self.next)

        "#{tabulate(tabs)}text #{quoted_string_for_text(text)}\n"
      end

      # Quotes text properly; this deals with figuring out whether it's a single line of text or multiline text.
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
    # @option options :class_name [String] (required) The name of the class to generate
    # @option options :superclass [String] (required) The name of the superclass for this widget
    # @option options :method [String] (required) The name of the method to generate (usually 'content')
    # @option options :assigns [Symbol] (required) Can be one of +:needs_defaulted_to_nil+ (generate +needs+
    #                                              declarations with defaults of +nil+), +:required_needs+ (generate
    #                                              +needs+ declarations with no defaults), +:instance_variables+
    #                                              (generate +needs+ declarations with defaults of +nil+, but reference
    #                                              them using instance variables, not methods), or +:no_needs+ (omit
    #                                              any +needs+ declarations entirely -- requires that you have
    #                                              +extra_assigns :use+ set on your widget, or it won't work)
    # @option options :do_end [Boolean] (false) Use 'do ... end' rather than '{ ... }' for tag content
    # @option options :new_style_hashes [Boolean] (false) Use Ruby 1.9-style Hashes
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

    # Processes the document and returns the result as a String containing the Fortitude template, including the
    # class declaration, needs text, method declaration, content, and ends.
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
    # Returns the 'needs' line appropriate for this class; this can be nil if they've set +:no_needs+.
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
        content = erb_to_interpolation(self.content, options).strip
        # content = parse_text_with_interpolation(
        #   erb_to_interpolation(self.content, options), tabs + 1)
        "#{tabulate(tabs)}cdata <<-END_OF_CDATA_CONTENT\n#{content}\nEND_OF_CDATA_CONTENT"
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

      # We just emit 'doctype!' here, because the base widget knows its doctype.
      def to_fortitude(tabs, options)
        "#{tabulate(tabs)}doctype!\n"
      end
    end

    # @see Nokogiri
    # @private
    class ::Nokogiri::XML::Comment
      # @see Html2fortitude::HTML::Node#to_fortitude
      def to_fortitude(tabs, options)
        return "#{tabulate(tabs)}comment #{quoted_string_for_text(self.content.strip)}\n"
      end
    end

    # @see Nokogiri
    # @private
    class ::Nokogiri::XML::Element
      BUILT_IN_RENDERING_HELPERS = %w{render}

      # Given a section of code that we're going to output, can we skip putting 'text' or 'rawtext' in front of it?
      # We can do this under the following scenarios:
      #
      # * The code is a single line, and contains no semicolons; and
      # * The method it's calling is either 'render' (which Fortitude implements internally) or a helper method that
      #   Fortitude automatically outputs the return value from.
      def can_skip_text_or_rawtext_prefix?(code)
        return false if code =~ /[\r\n]/mi
        return false if code =~ /;/mi
        method = $1 if code =~ /^\s*([A-Za-z_][A-Za-z0-9_]*[\!\?\=]?)[\s\(]/
        method ||= $1 if code =~ /^\s*([A-Za-z_][A-Za-z0-9_]*[\!\?\=]?)$/
        options = Fortitude::Rails::Helpers.helper_options(method.strip.downcase) if method
        (options && options[:transform] == :output_return_value) ||
          (method && BUILT_IN_RENDERING_HELPERS.include?(method.strip.downcase))
      end

      # Given a section of code that we're going to output, can we use it as a method argument directly? Or do we need
      # to nest it inside a block to the tag?
      #
      # In other words, can we say just:
      #
      #     p(...code...)
      #
      # ...or do we need to say:
      #
      #     p {
      #       text(...code...)
      #     }
      def code_can_be_used_as_a_method_argument?(code)
        code !~ /[\r\n;]/ && (! can_skip_text_or_rawtext_prefix?(code))
      end

      # Kinda just like what it says ;)
      def is_text_element_starting_with_newline?(node)
        node && node.is_a?(::Nokogiri::XML::Text) && node.to_s =~ /^\s*[\r\n]/
      end

      # This is used to support blocks like form_for -- this tells the next element that it needs to put a close
      # parenthesis on the end, since we end up outputting something like:
      #
      #     text(form_for do |f|
      #       text(f.text_field :name)
      #     end)
      def is_loud_block!
        @is_loud_block = true
      end

      VALID_JAVASCRIPT_SCRIPT_TYPES = [ 'text/javascript', 'text/ecmascript', 'application/javascript', 'application/ecmascript']
      VALID_JAVASCRIPT_LANGUAGE_TYPES = [ 'javascript', 'ecmascript' ]

      VALID_CSS_TYPES = [ 'text/css' ]

      # @see Html2fortitude::HTML::Node#to_fortitude
      def to_fortitude(tabs, options)
        return "" if converted_to_fortitude

        # If this is a <script> or <style> block, output the correct syntax for it; we use the #javascript convenience
        # method if possible.
        if name == "script"
          if VALID_JAVASCRIPT_SCRIPT_TYPES.include?((attr_hash['type'] || VALID_JAVASCRIPT_SCRIPT_TYPES.first).strip.downcase) &&
             VALID_JAVASCRIPT_LANGUAGE_TYPES.include?((attr_hash['language'] || VALID_JAVASCRIPT_LANGUAGE_TYPES.first).strip.downcase)
            new_attrs = Hash[attr_hash.reject { |k,v| %w{type language}.include?(k.to_s.strip.downcase) }]
            return contents_as_direct_input_to_tag(:javascript, tabs, options, new_attrs)
          else
            return contents_as_direct_input_to_tag(:script, tabs, options, attr_hash)
          end
        elsif name == "style"
          return contents_as_direct_input_to_tag(:style, tabs, options, attr_hash)
        end

        output = tabulate(tabs)
        # Here's where the real heart of a lot of our ERb processing happens. We process the special tags:
        #
        # * +<fortitude_loud>+ -- equivalent to ERb's +<%= %>+;
        # * +<fortitude_silent>+ -- equivalent to ERb's +<% %>+;
        # * +<fortitude_block>+ -- used when a +<%=+ or +<%+ starts a block of Ruby code; encloses the whole thing
        if options[:erb] && FORTITUDE_TAGS.include?(name)
          case name
          # This is ERb +<%= %>+ -- i.e., code we need to output the return value of
          when "fortitude_loud"
            # Extract any instance variables, add 'needs' for them, and turn them into method calls
            t = extract_needs_from!(CGI.unescapeHTML(inner_text), options)
            lines = t.split("\n").map { |s| s.strip }

            outputting_method = if attribute("raw") then "rawtext" else "text" end

            # Handle this case:
            # <%= form_for(@user) do |f| %>
            #   <%= f.whatever %>
            # <% end %>
            if self.next && self.next.is_a?(::Nokogiri::XML::Element) && self.next.name == 'fortitude_block'
              self.next.is_loud_block!
              # What gets output is whatever the code returns, so we put the method on the last line of the block
              lines[-1] = "#{outputting_method}(" + lines[-1]
            elsif lines.length == 1 && can_skip_text_or_rawtext_prefix?(lines.first)
              # OK, we're good -- this means there's only a single line, and we're calling a Rails helper method
              # that automatically outputs, so we don't actually have to use 'text' or 'rawtext'
            else
              # What gets output is whatever the code returns, so we put the method on the last line of the block
              lines[-1] = "#{outputting_method}(" + lines[-1] + ")"
            end

            return lines.map {|s| output + s + "\n"}.join
          # This is ERb +<% %>+ -- i.e., code we just need to run
          when "fortitude_silent"
            # Extract any instance variables, add 'needs' for them, and turn them into method calls
            t = extract_needs_from!(CGI.unescapeHTML(inner_text), options)
            return t.split("\n").map do |line|
              next "" if line.strip.empty?
              "#{output}#{line.strip}\n"
            end.join
          # This is ERb +<%+ or +<%=+ that starts a Ruby block
          when "fortitude_block"
            needs_coda = true unless self.next && self.next.is_a?(::Nokogiri::XML::Element) &&
              self.next.name == 'fortitude_silent' && self.next.inner_text =~ /^\s*els(e|if)\s*$/i
            coda = if needs_coda then "\n#{tabulate(tabs)}end" else "" end
            coda << ")" if @is_loud_block
            coda << "\n"
            children_text = render_children("", tabs, options).rstrip
            return children_text + coda
          else
            raise "Unknown special tag: #{name.inspect}"
          end
        end

        output << "#{name}"

        attributes_text = fortitude_attributes(options) if attr_hash && attr_hash.length > 0
        direct_content = nil
        render_children = true

        # If the element only has a single run of text as its content, try just passing it as a direct argument to
        # our tag method, rather than starting a block
        if children.try(:size) == 1 && children.first.is_a?(::Nokogiri::XML::Text)
          direct_content = quoted_string_for_text(child.to_s.strip)
          render_children = false
        # If the element only has one thing as its content, and that's an ERb +<%= %>+ block, try just passing that
        # code directly as a method argument, if we can do that
        elsif children.try(:size) == 1 && children.first.is_a?(::Nokogiri::XML::Element) &&
          children.first.name == "fortitude_loud" &&
          code_can_be_used_as_a_method_argument?(child.inner_text)

          it = extract_needs_from!(child.inner_text, options)

          direct_content = "#{it.strip}"
          # Put parentheses around it if we have attributes, and it's a method call without parentheses
          direct_content = "(#{direct_content})" if attributes_text && direct_content =~ /^\s*[A-Za-z_][A-Za-z0-9_]*[\!\?\=]?\s+\S/
          render_children = false
        end

        # Produce the arguments to our tag method...
        if attributes_text && direct_content
          output << "(#{direct_content}, #{attributes_text})"
        elsif direct_content
          output << "(#{direct_content})"
        elsif attributes_text
          output << "(#{attributes_text})"
        end

        # Render the children, if we need to.
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

      # Just string together the children, calling #to_fortitude on each of them.
      def render_children(so_far, tabs, options)
        (self.children || []).inject(so_far) do |output, child|
          output + child.to_fortitude(tabs + 1, options)
        end
      end

      # Take the attributes for this node (from +attr_hash+) and return from it a Hash. This Hash will have entries
      # for any attributes that have substitutions (_i.e._, ERb tags) in their values, mapping the name of each
      # attribute to the text we should use for it -- that is, pure Ruby code where possible, Ruby String interpolations
      # where not.
      def dynamic_attributes(options)
        return @dynamic_attributes if @dynamic_attributes

        # reject any attrs without <fortitude>
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

      # Given an attribute value, can we simply use bare Ruby code for it, or do we need to use string interpolation?
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

      # Some HTML tags like <script> and <style> have content that isn't parsed at all; Fortitude handles this by
      # simply supplying it as direct content to the tag, typically as an <<-EOS string:
      #
      #     script <<-END_OF_SCRIPT_CONTENT
      #       var foo = 1;
      #       ...
      #     END_OF_SCRIPT_CONTENT
      #
      # This method creates exactly that form.
      def contents_as_direct_input_to_tag(tag_name, tabs, options, attributes_hash)
        tag_name = tag_name.to_s.strip.downcase

        content =
          # We want to remove any CDATA present if it's Javascript; the Fortitude #javascript method takes care of
          # adding CDATA if needed (_i.e._, for XHTML doctypes only).
          if children.first && children.first.cdata? && tag_name == 'javascript'
            decode_entities(children.first.content_without_cdata_tokens)
          else
            decode_entities(self.inner_text)
          end

        content = erb_to_interpolation(content, options)
        content.strip!
        content << "\n"

        first_line = "#{tabulate(tabs)}#{tag_name} <<-END_OF_#{tag_name.upcase}_CONTENT"
        first_line += ", #{fortitude_attributes({ }, attributes_hash)}" unless attributes_hash.empty?
        middle = content.rstrip
        last_line = "#{tabulate(tabs)}END_OF_#{tag_name.upcase}_CONTENT"

        first_line + "\n" + middle + "\n" + last_line
      end

      # Returns the string we want to use to start a block -- either '{' (by default) or 'do' (if asked)
      def element_block_start(options)
        if options[:do_end]
          "do"
        else
          "{"
        end
      end

      # Returns the string we want to use to end a block -- either '}' (by default) or 'end' (if asked)
      def element_block_end(options)
        if options[:do_end]
          "end"
        else
          "}"
        end
      end

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

      # Does the attribute with the given name include any ERb in its value?
      def dynamic_attribute?(name, options)
        options[:erb] and dynamic_attributes(options).key?(name)
      end

      # Returns a string representation of an attributes hash
      # that's prettier than that produced by Hash#inspect
      def fortitude_attributes(options, override_attr_hash = nil)
        attrs = override_attr_hash || attr_hash
        attrs = attrs.sort.map do |name, value|
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
