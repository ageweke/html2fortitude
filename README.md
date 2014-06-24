# `html2fortitude`

`html2fortitude` converts HTML to [Fortitude](http://github.com/ageweke/fortitude). It works on HTML with
embedded ERB tags as well as plain old HTML.

`html2fortitude` is a heavily-modified fork of [`html2haml`](https://github.com/haml/html2haml), version 2.0.0beta1.
Many, many thanks to [Stefan Natchev](https://github.com/snatchev), [Norman Clarke](https://github.com/norman),
Hampton Catlin, and Nathan Weizenbaum for all their work on `html2haml`, and for the excellent idea of transforming
ERb into valid HTML with ERb pseudo-tags, then parsing it with Nokogiri. `html2fortitude` could not have been created
without all their hard work.

## Usage

    % gem install html2fortitude
    % html2fortitude <input-file>

For more information:

    % html2fortitude --help

Because Fortitude views have a class name, while nearly no other templating languages do, `html2fortitude` needs to
determine a class name for the generated class. If you're converting files that lie underneath a Rails repository,
`html2fortitude` will automatically detect this and give them the correct name depending on their hierarchy underneath
`app/views`. If you're converting files that aren't underneath a Rails repository, you'll have to either specify the
root directory from which class names should be computed using the `--class-base`/`-b` option, or give each file an
explicit class name, using `--class-name`/`-c`.

You can convert an entire directory full of files by passing a directory on the command line. By default, translated
files will be written right along side the original files, but you can create a separate hierarchy under a new
directory by passing the new directory as `--output`/`-o`. For a single file, `-o` specifies the filename of the
translated file to be written to.

Other useful options:

* You can set the superclass of the generated widget using `--superclass`/`-s`.
* You can set the name of the content method using `--method`/`-m`.
* You can set the style of assigns to use using `--assigns`/`-a`, which can be one of:
  * `needs_defaulted_to_nil`, the default; this is standard Fortitude syntax, but with all `need`ed variables
    defaulted to `nil` (_e.g._, `needs :foo => nil, :bar => nil`). This is the default because it is impossible to
    know whether callers of this template always pass in a value for each variable or not, so this is the safest
    option.
  * `required_needs`; this has all `need`ed variables required. If a caller of this template doesn't pass in a value
    for all `need`ed variables, the widget will raise an exception. This produces cleaner code, but may force you to
    manually go add `nil` defaults for any `need`s that are actually optional.
  * `instance_variables`; this uses Ruby instance variables for `need`ed variables (`@foo` instead of `foo`). This is
    not preferred Fortitude style, and requires that you've set `use_instance_variables_for_assigns true` on your
    widget class or superclass in your code, but can be useful if you prefer this style or want to maintain more
    compatibility with Erector, which always uses this style.
  * `no_needs`; this declares no `needs` at all, which means you'll either have to go fill them in yourself, or
    set `extra_assigns :use` in order for things to work.
* You can set the style of blocks passed to HTML elements using `--do-end`. By default, code is generated that
  looks like `p { ... }` even on multi-line blocks (which is preferred Fortitude style, as it helps you differentiate
  between blocks resulting from control flow vs. blocks resulting from HTML), but `html2fortitude` will generate
  `p do ... end` if you pass this option.
* You can use new-style hashes (`class: 'foo'`) rather than old-style (`:class => 'foo'`) by passing
  `--new-style-hashes`.

## License

Copyright (c) 2014 Andrew Geweke

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


Copyright (c) 2006-2013 Hampton Catlin, Nathan Weizenbaum and Norman Clarke

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
