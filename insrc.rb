#!/usr/bin/env ruby
# Copyright (c) 2011 Rich Lane
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
# of the Software, and to permit persons to whom the Software is furnished to do
# so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'tempfile'
require 'optparse'

options = { :prefix => 'insrc', :dir => [] }
OptionParser.new do |opts|
  opts.banner = "Usage: insrc.rb [options] [manifest]"

  opts.separator ""
  opts.separator <<-EOS
Output a C file containing the data of each file specified in the manifest,
plus a gperf lookup function named PREFIX_lookup.
  EOS
  opts.separator ""

  opts.on('-p', '--prefix PREFIX', 'Prepend PREFIX to generated names') do |x|
    options[:prefix] = x
  end

  opts.on('-d', '--dir DIR', 'Look for files under DIR') do |x|
    options[:dir] << x
  end
end.parse!

options[:dir] << '.' if options[:dir].empty?

prefix = options[:prefix]
manifest = ARGF.readlines.map(&:chomp)
tmp = Tempfile.new prefix
keywords = []

tmp.puts  '%{'
tmp.puts "#include <string.h>"
tmp.puts "static const char * const #{prefix}_data[] = {"
manifest.each_with_index do |path,idx|
  filename = options[:dir].map { |dir| File.join(dir, path) }.find { |fn| File.exists? fn }
  fail "not found: #{path}" unless filename
  tmp.puts "#{File.read(filename).inspect},"
  keywords << [path, idx]
end
tmp.puts "};"
tmp.puts  '%}'

tmp.puts
tmp.puts "%define lookup-function-name #{prefix}_lookup_int"
tmp.puts "%define hash-function-name #{prefix}_hash"
tmp.puts "%struct-type"
tmp.puts "struct #{prefix}_file { char *name; int idx; };"
tmp.puts "%%"

keywords.each do |path,idx|
  tmp.puts [path, idx]*', '
end

tmp.puts "%%"
tmp.puts <<EOS
const char *#{prefix}_lookup(const char *name)
{
  struct #{prefix}_file *x = #{prefix}_lookup_int(name, strlen(name));
  if (x != NULL) {
    return #{prefix}_data[x->idx];
  } else {
    return NULL;
  }
}
EOS

tmp.close
system("gperf #{tmp.path}")
