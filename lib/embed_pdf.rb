module PDFEmbedder

  require 'pathname'

  class PDFTag < Liquid::Tag
    def initialize(tag_name, url, tokens)
      super
      @url = url
    end

    def render(context)
      # current directory
      filedir = File.dirname(context.registers[:page]["path"])

      # if the path is relative than we have escape up one level
      if !Pathname.new(@url.strip).absolute?
        pdfpath = File.path(File.join("..", @url.strip))
      else
        pdfpath = @url.strip
      end

      result = "<div class=\"pdf-wrapper\">"
      result += "<embed src=\"#{pdfpath}\"/>"
      result += "<div class=\"caption\">Original file: <a href=\"#{pdfpath}\">#{File.basename(pdfpath)}</a></div>"
      result += "</div>"
    end
  end
end

Liquid::Template.register_tag('embedpdf', PDFEmbedder::PDFTag)
