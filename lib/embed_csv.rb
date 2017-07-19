module CSVEmbedder
  require 'csv'

  class CSVTag < Liquid::Tag
    def initialize(tag_name, url, tokens)
      super
      @url = url
    end

    def render(context)
      # current directory
      filedir = File.dirname(context.registers[:page]["path"])

      csvpath = File.path(File.join(filedir, @url.strip))

      table_tag = "<table>"
      table_tag += '<caption>Data from here: <a href="'+ @url + '">' + @url + '</a></caption>'
      count = 0
      CSV.foreach(csvpath) do |row|
        if count == 0
          table_tag += "<thead>"
        else
          table_tag += "<tbody>"
        end
        table_tag += "<tr>"
        for item in row
          table_tag += "<td>#{item}</td>"
        end
        table_tag += "</tr>"
        if count == 0
          table_tag += "</thead>"
        else
          table_tag += "</tbody>"
        end
        count += 1
      end

      table_tag += "</table>"
    end
  end
end

Liquid::Template.register_tag('embedcsv', CSVEmbedder::CSVTag)
