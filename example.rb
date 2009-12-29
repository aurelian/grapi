$LOAD_PATH<< "lib"

require "rubygems"
require "grapi"
require "grapi/parser"
require "yaml"

def print_list(list)
  puts "~> Got: #{list.gid} updated at: #{list.updated_at}\n\t contains: #{list.entries.size} items. continuation: #{list.continuation}"
  list.entries.each do | entry |
    puts "~> #{entry.title}"
    puts "\tpublished at: #{entry.published_at}"
    puts "\tcategories: \n\t\t#{entry.categories.map{|k| "label= #{k[:label]} | term= #{k[:term]}"}.join("\n\t\t")}"
    puts "\tsource: #{entry.source[:title]}"
    puts "\tauthor: #{entry.author}"
    puts "\turl: #{entry.link}"
    puts "\tsummary: #{entry.summary}"
    puts "======================================================================="
  end
end

config= YAML.load_file File.expand_path("~/.gdata.yml")

reader= Grapi::Reader.new(true)
reader.login config["username"], config["password"]

continuation= nil
loop do
  list= Grapi::Parser::ReadingList.parse(reader.reading_list(continuation))
  print_list list
  continuation= list.continuation
  break if continuation.nil?
end

