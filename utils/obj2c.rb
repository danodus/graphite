#!/usr/bin/env ruby
#
# Converts obj model file to C
# Copyright (c) 2021 Daniel Cliche
# Copyright (c) 2021 Ross Bamford
# See LICENSE (hint: MIT)
#

$vertices = []
$texcoords = []
$faces = []

def process_line(line)
  words = line.split
  if words[0] == "v"
    $vertices << [words[1], words[2], words[3]]
  elsif words[0] == "vt"
    $texcoords << [words[1], words[2]]
  elsif words[0] == "f"
    w1 = words[1].split('/')
    w2 = words[2].split('/')
    w3 = words[3].split('/')
    $faces << [w1[0], w2[0], w3[0], w1[1], w2[1], w3[1]]
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

def print_texcoords(array)
  print "static vec2d texcoords[] = {\n"
  array.each.with_index do |item, index|
    print "{FX(#{item[0]}f), FX(#{item[1]}f)}"
    print "," unless index == array.size - 1
    print "\n"
  end
  print("};\n")
end

def print_faces(array)
  print "static face_t faces[] = {\n"
  array.each.with_index do |item, index|
    print "{{#{item[0].to_i-1}, #{item[1].to_i-1}, #{item[2].to_i-1}}, {FX(1.0f), FX(1.0f), FX(1.0f), FX(1.0f)}, {#{item[3].to_i-1}, #{item[4].to_i-1}, #{item[5].to_i-1}}}"
    print "," unless index == array.size - 1
    print "\n"
  end
  print("};\n")
end

def print_all()
  print_vertices $vertices
  print_texcoords $texcoords
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
