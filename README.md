# Html2fortitude

Html2fortitude converts HTML to [Fortitude](http://github.com/ageweke/fortitude). It works on HTML with
embedded ERB tags as well as plain old HTML.

## Installation

Add this line to your application's Gemfile:

    gem 'html2fortitude'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install html2fortitude

## Usage


### To convert a project from .erb to .rb (Fortitude)

If your system has `sed` and `xargs` available and none of your .erb file names
have whitespace in them, you can convert all your templates like so:

    find . -name \*.erb -print | sed 'p;s/.erb$/.rb/' | xargs -n2 html2fortitude

If some of your file names have whitespace or you need finer-grained control
over the process, you can convert your files using `gsed` or multi-line script
techniques discussed [here](http://stackoverflow.com/questions/17576814/).


### Documentation


#### Options

Here are the options currently available to Html2fortitude:

See `html2fortitude --help`:

    Usage: html2fortitude [options] [INPUT] [OUTPUT]

    Description: Transforms an HTML file into corresponding Fortitude code.

    Options:
        -e, --erb                        Parse ERb tags.
            --no-erb                     Don't parse ERb tags.
            --html-attributes            Use HTML style attributes instead of Ruby hash style.
            --ruby19-attributes          Use Ruby 1.9-style attributes when possible.
        -E ex[:in]                       Specify the default external and internal character encodings.
        -s, --stdin                      Read input from standard input instead of an input file
            --trace                      Show a full traceback on error
            --unix-newlines              Use Unix-style newlines in written files.
        -?, -h, --help                   Show this message
        -v, --version                    Print version

## License



Original Html2haml:

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
