#!/usr/bin/env ruby
#
# Converts obj model file to C
# Copyright (c) 2021 Daniel Cliche
# Copyright (c) 2021 Ross Bamford
# See LICENSE.md (hint: MIT)
#

$vertices = []
$faces = []

def process_line(line)
  words = line.split
  if words[0] == "v"
    $vertices << [words[1], words[2], words[3]]
  elsif words[0] == "f"
    $faces << [words[1].split('/')[0], words[2].split('/')[0], words[3].split('/')[0]]
  end
end

def print_vertices(array)
  print "static vec3d vertices[] = {\n"
  array.each.with_index do |item, index|
    print "{FX(#{item[0]}f), FX(#{item[1]}f), FX(#{item[2]}f), FX(1.0f)}"
    print "," unless index == array.size - 1
    print "\n"
  end
  print("};\n")
end

def print_faces(array)
  print "static face_t faces[] = {\n"
  array.each.with_index do |item, index|
    print "{{#{item[0]}-1, #{item[1]}-1, #{item[2]}-1}, {FX(1.0f), FX(1.0f), FX(1.0f), FX(1.0f)}}"
    print "," unless index == array.size - 1
    print "\n"
  end
  print("};\n")
end

def print_all()
  print_vertices $vertices
  print_faces $faces
end

if $0 == __FILE__
  if (ARGV.length != 1)
    puts "Usage: obj2c.rb <objfile>"
  else
    fn = File.expand_path(ARGV.first)
    if !File.exists?(fn)
      puts "Error: '#{fn}' not found"
    else
      File.readlines(fn).each do |line| process_line line end
      print_all()
    end
  end
end
