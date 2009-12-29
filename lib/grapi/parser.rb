require "nokogiri"
require "loofah"
require "time"

module Grapi

  module Parser

    class Entry
      attr_accessor :crawled_at, :summary, :gid, :categories, :published_at, :updated_at, :author, :source, :title, :link

      def initialize
        @categories= []
        yield self
      end
    end

    class ReadingList
      attr_accessor :entries, :gid, :updated_at, :continuation

      def initialize
        @entries= []
        yield self
      end

      def self.parse(xml)
        doc= Nokogiri::XML xml
        Grapi::Parser::ReadingList.new do | list |
          list.gid          = doc.search("id").first.inner_text
          list.updated_at   = Time.parse(doc.search("updated").first.inner_text)
          list.continuation = doc.at_xpath("//gr:continuation").inner_text rescue nil
          doc.search("entry").each do | entry |
            list.entries << Grapi::Parser::Entry.new do | e |
              e.gid          = entry.search("id").first.inner_text
              e.title        = entry.search("title").first.inner_text
              e.published_at = Time.parse(entry.search("published").first.inner_text)
              e.updated_at   = Time.parse(entry.search("updated").first.inner_text)
              e.link         = entry.search("link").attr("href").value
              e.crawled_at   = Time.at(entry["crawl-timestamp-msec"].to_i/1000.0).utc
              e.summary      = Loofah.fragment(entry.search("summary").inner_text).scrub!(:strip).text
              e.author       = entry.search("author/name").inner_text
              e.source       = {
                :id    => entry.search("source/id").inner_text,
                :title => entry.search("source/title").inner_text,
                :link  => entry.search("source/link").attr("href").value
              }
              entry.search("category").each { | category | e.categories << {:term=>category.attr("term"), :label=>category.attr("label")} }
            end
          end
        end
      end
    end
  end
end

