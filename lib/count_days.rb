module DayLister
  require 'nokogiri'
  require 'date'
  require 'jekyll'

  class DayListTag < Liquid::Tag
    def initialize(tag_name, url, tokens)
      super
    end

    def render(context)
      # current directory
      postlist = context.registers[:site].posts.docs

      result = "{\n"
      postlist.each do |post|
        doc = Nokogiri::HTML::DocumentFragment.parse(post.content)

        doc.search('h3').each do |header|
          if dt = DateTime.parse(header.attribute("id")) rescue false
            result += (dt + Rational(12, 24)).strftime('%s') + ": 4,\n"
          end
        end
      end
      result += "}"
      result
    end
  end
end

Liquid::Template.register_tag('listdays', DayLister::DayListTag)
