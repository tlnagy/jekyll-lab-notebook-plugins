module Jekyll

  require 'pathname'

  class SearchFileGenerator < Generator
    safe true

    def generate(site)
      output = [{"title" => "Test"}]

      path = Pathname.new(site.dest) + "search.json"

      converter = site.find_converter_instance(::Jekyll::Converters::Markdown)
      search_list = []

      site.posts.docs.each do |post|
        search_list.push(*build_post_hashes(post, converter))
      end

      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, 'w') do |f|
       f.write(search_list.to_json)
      end
      site.keep_files << "search.json"
    end

    def build_post_hashes(post, converter)
      post_hashes = []
      curr_post = nil
      curr_hash = {}
      curr_hash["content"] = []

      converted_lines = post.content.split("\n").map do |line|

        curr_hash["content"] << line

        # skip code blocks
        in_code_block = !in_code_block if line.match(/^```/)
        next line if in_code_block

        # drop lines that aren't markdown headers
        matched = line.match(/^(#+) /)
        next line unless matched

        # drop headers that don't start with dates
        DateTime.parse(line.strip) rescue next line

        # pretty format dates
        date = DateTime.parse(line.strip)
        yearmonth = date.strftime("%Y_%m")
        iddate = date.strftime("%Y%m%d")
        displaydate = date.strftime("%a, %b %e")

        # we've found a new entry, remove it from the previous entry's lines
        curr_hash["content"].pop()

        # extract project tags and flatten into a single array
        tags = line.strip.scan(/#([a-zA-Z0-9._-]{3,} ?)/).flatten(1)

        if !curr_post.nil?
          curr_hash["content"] = converter.convert(curr_hash["content"].join("\n"))
          post_hashes << curr_hash
        end

        curr_hash = {}
        curr_hash["content"] = []
        curr_hash["title"] = displaydate
        curr_hash["url"] = "/log/#{yearmonth}/##{iddate}"
        curr_hash["tags"] = tags

        curr_post = date
      end
      return post_hashes
    end
  end
end
