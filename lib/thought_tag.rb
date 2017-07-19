module ThoughtTagger

  class ThoughtTag < Liquid::Tag
    def initialize(tag_name, markup, tokens)
      @markup = markup
      super
    end

    def render(context)
      site = context.registers[:site]
      converter = site.find_converter_instance(::Jekyll::Converters::Markdown)

      result = "<div class=\"alert alert-info\" role=\"alert\">#{converter.convert(@markup).strip}</div>"
    end
  end
end

Liquid::Template.register_tag('thought', ThoughtTagger::ThoughtTag)

module NoteTagger

  class NoteTag < Liquid::Tag
    def initialize(tag_name, markup, tokens)
      @markup = markup
      super
    end

    def render(context)
      site = context.registers[:site]
      converter = site.find_converter_instance(::Jekyll::Converters::Markdown)

      markup = converter.convert(@markup).strip[3..-1]
      result = "<div class=\"alert alert-note\" role=\"alert\">"
      result << "<p><span><strong>Note: </strong></span>#{markup}</div>"
    end
  end
end

Liquid::Template.register_tag('note', NoteTagger::NoteTag)
