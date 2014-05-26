describe "html2fortitude ERb support" do
  it "should work with ERb blocks around HTML" do
    expect(h2f_content(%{<% foo do %>
bar
<p class="baz"/>
<% end %>})).to eq(%{foo do
  text "bar"

  p(:class => "baz")
end})
  end

  it "should leave space after an ERb block" do
    expect(h2f_content(%{<% foo do %>
bar
<p class="baz"/>
<% end %>
hello, world})).to eq(%{foo do
  text "bar"

  p(:class => "baz")
end
text "hello, world"})
  end

  it "should handle ERb blocks that are loud, like form_for" do
    expect(h2f_content(%{<%= form_for do |f| %>
  <%= f.text_field :name %>
  <p class="baz"/>
<% end %>})).to eq(%{text(form_for do |f|
  text(f.text_field :name)
  p(:class => "baz")
end)})
  end

  it "should handle multiline ERb blocks that are loud, like form_for" do
    expect(h2f_content(%{<%= foo + bar
form_for do |f| %>
  <%= f.text_field :name %>
  <p class="baz"/>
<% end %>})).to eq(%{foo + bar
text(form_for do |f|
  text(f.text_field :name)
  p(:class => "baz")
end)})
  end

  it "should interpolate ERb inside a <script> block when possible" do
    expect(h2f_content(%{<script type="text/javascript">
foo
<%= bar %>
baz
</script>})).to eq(%{javascript <<-END_OF_JAVASCRIPT_CONTENT
foo
\#{bar}
baz
END_OF_JAVASCRIPT_CONTENT})
  end

  it "should interpolate ERb inside a <style> block when possible" do
    expect(h2f_content(%{<style type="text/css">
foo
<%= bar %>
baz
</style>})).to eq(%{style <<-END_OF_STYLE_CONTENT, :type => "text/css"
foo
\#{bar}
baz
END_OF_STYLE_CONTENT})
  end

  it "should render ERb silent inside <script> blocks as big warnings" do
    expect(h2f_content(%{<script type="text/javascript">
bar
<% baz %>
quux
</script>})).to eq(%{javascript <<-END_OF_JAVASCRIPT_CONTENT
bar

# HTML2FORTITUDE_FIXME_BEGIN: The following code was interpolated into this block using ERb;
# Fortitude isn't a simple string-manipulation engine, so you will have to find another
# way of accomplishing the same result here:
# <%
#  baz
# %>
quux
END_OF_JAVASCRIPT_CONTENT})
  end

  it "should render ERb silent inside <style> blocks as big warnings" do
    expect(h2f_content(%{<style type="text/css">
bar
<% baz %>
quux
</style>})).to eq(%{style <<-END_OF_STYLE_CONTENT, :type => "text/css"
bar

# HTML2FORTITUDE_FIXME_BEGIN: The following code was interpolated into this block using ERb;
# Fortitude isn't a simple string-manipulation engine, so you will have to find another
# way of accomplishing the same result here:
# <%
#  baz
# %>
quux
END_OF_STYLE_CONTENT})
  end

  it "should render ERb blocks inside <script> blocks as big warnings" do
    expect(h2f_content(%{<script type="text/javascript">
bar
<% if foo %>
quux
<% else %>
bar
<% end %>
quux
</script>})).to eq(%{javascript <<-END_OF_JAVASCRIPT_CONTENT
bar

# HTML2FORTITUDE_FIXME_BEGIN: The following code was interpolated into this block using ERb;
# Fortitude isn't a simple string-manipulation engine, so you will have to find another
# way of accomplishing the same result here:
# <%
#  if foo
# %>

# HTML2FORTITUDE_FIXME_BEGIN: The following code was interpolated into this block using ERb;
# Fortitude isn't a simple string-manipulation engine, so you will have to find another
# way of accomplishing the same result here:
# <%
# quux
# %>

# HTML2FORTITUDE_FIXME_BEGIN: The following code was interpolated into this block using ERb;
# Fortitude isn't a simple string-manipulation engine, so you will have to find another
# way of accomplishing the same result here:
# <%
#  else
# %>

# HTML2FORTITUDE_FIXME_BEGIN: The following code was interpolated into this block using ERb;
# Fortitude isn't a simple string-manipulation engine, so you will have to find another
# way of accomplishing the same result here:
# <%
# bar
# %>
quux
END_OF_JAVASCRIPT_CONTENT})
  end

  it "should render ERb blocks inside <style> blocks as big warnings" do
    expect(h2f_content(%{<style type="text/css">
bar
<% if foo %>
quux
<% else %>
bar
<% end %>
quux
</style>})).to eq(%{style <<-END_OF_STYLE_CONTENT, :type => "text/css"
bar

# HTML2FORTITUDE_FIXME_BEGIN: The following code was interpolated into this block using ERb;
# Fortitude isn't a simple string-manipulation engine, so you will have to find another
# way of accomplishing the same result here:
# <%
#  if foo
# %>

# HTML2FORTITUDE_FIXME_BEGIN: The following code was interpolated into this block using ERb;
# Fortitude isn't a simple string-manipulation engine, so you will have to find another
# way of accomplishing the same result here:
# <%
# quux
# %>

# HTML2FORTITUDE_FIXME_BEGIN: The following code was interpolated into this block using ERb;
# Fortitude isn't a simple string-manipulation engine, so you will have to find another
# way of accomplishing the same result here:
# <%
#  else
# %>

# HTML2FORTITUDE_FIXME_BEGIN: The following code was interpolated into this block using ERb;
# Fortitude isn't a simple string-manipulation engine, so you will have to find another
# way of accomplishing the same result here:
# <%
# bar
# %>
quux
END_OF_STYLE_CONTENT})
  end
end
