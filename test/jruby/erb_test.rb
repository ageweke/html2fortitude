#reopen classes that need to be modified for JRuby specific behavior
class ErbTest
  def test_inline_erb
    assert_equal("%p= foo", render_erb("<p><%= foo %></p>"))
    assert_equal(<<FORTITUDE.rstrip, render_erb(<<HTML))
%p
  = foo
FORTITUDE
<p><%= foo %>
</p>
HTML
  end

  def test_two_multiline_erb_loud_scripts
    assert_equal(<<FORTITUDE.rstrip, render_erb(<<ERB))
.blah
  = foo +          |
    bar.baz.bang + |
    baz            |
  = foo.bar do |
      bang     |
    end        |
  %p foo
FORTITUDE
<div class="blah">
  <%=
    foo +
    bar.baz.bang +
    baz
  %>
  <%= foo.bar do
        bang
      end %>
  <p>foo</p>
</div>
ERB
  end

end
