# Support for adding tags to daily log posts and miscellaneous fixes to date
# display

require 'fileutils'
require 'nokogiri'
require 'set'
require 'pathname'
require 'uri'

module Jekyll

  class ProjectPage < Page
    def initialize(site, base, dir)
      @site = site
      @base = base
      @dir = dir
      @name = 'index.html'

      self.process(@name)
      @path = site.layouts["project-home"].path
      self.read_yaml("", "") # uses path from above first

      self.data['title'] = "Projects"
    end
  end

  class CategoryPageGenerator < Generator
    safe true

    def generate(site)
      if site.layouts.key? 'project-home'
        dir = site.config['project-dir'] || 'projects'
        site.pages << ProjectPage.new(site, site.source, dir)
      end
    end
  end

end

# Pre-render
#
# This is the first step. When posts are built, this block goes through and
# reads the markdown line by line to identify log entries by looking for headers
# followed by a parseable date. It then extracts the project tags that follow
# the date and constructs a hash/dict mapping log entries by their html ids
# (in the standard YYYYMMDD format) to an array of project tags. This block also
# removes the project tags and pretty formats things.
Jekyll::Hooks.register :posts, :pre_render do |post|
  in_code_block = false

  entrymap = Hash.new { |h, k| h[k] = Set.new }

  converted_lines = post.content.split("\n").map do |line|

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
    iddate = date.strftime("%Y%m%d")
    displaydate = date.strftime("%a, %b %e")

    # extract project tags
    tags = line.strip.scan(/#([a-zA-Z0-9._-]{3,} ?)/)

    # if project tags are detected for this entry then add it to the hash
    if tags.length > 0
      tags.each { |tag| entrymap[iddate].add(tag[0].strip) }
    end

    # replace markdown header with this nice html
    "<h3 class=\"log-entry\" id=\"#{iddate}\">#{displaydate}</h3>"
  end

  # sort the hash so posts will be laid out chronologically on the project page
  entrymap = Hash[ entrymap.sort_by { |key, val| key } ]

  # save the hash for later processing
  post.site.data["entrymap"] = entrymap

  post.content = converted_lines.join("\n")
end

# Post-render
#
# This is the second step. Once the posts are converted to HTML, this block is
# called. It goes through and splits up each post into separate log entries and
# inserts the HTML version of these log entries into a hash that maps projects
# to entry HTMLs. It also goes and fixes relative links in the log entries so
# that images work once the HTML is copied over to the projects folder.
Jekyll::Hooks.register :posts, :post_render do |post|
  # if this post has entries with project tags
  if post.site.data["entrymap"].length > 0

    # attempt to load a hash mapping tags to ids from the site data
    if post.site.data["tagmap"] == nil
      tagmap = {}
    else
      tagmap = post.site.data["tagmap"]
    end

    # create new array if key doesn't exist (default dictionary)
    tagmap.default_proc = proc { |h, k| h[k] = [] }

    doc = Nokogiri::HTML post.content

    # iterate over each entry and its associated tags
    post.site.data["entrymap"].each do |entry, tags|

      new_node_set = Nokogiri::XML::NodeSet.new(doc)
      orig = doc.at_css("h3.log-entry[id=\"#{entry}\"]")
      new_node_set << orig
      node = orig.next

      # continue until we run out of sibling nodes or we hit the next log entry
      while !node.nil? && node["class"] != "log-entry"
        new_node_set << node
        node = node.next
      end

      tags.each do |tag|
        dir = post.site.config['projects_dir'] || 'projects'
        old_path = post.url.dup
        old_path[0] = ''
        fix_links(new_node_set, old_path, File.join(dir, tag)) # fix rel links
        content = new_node_set.to_html
        # fix checkboxes
        content.gsub! '<li>[ ]', '<li class="box task-list-item"><input type="checkbox" class="task-list-item-checkbox" disabled>'
        content.gsub! '<li>[x]', '<li class="box_done task-list-item"><input type="checkbox" class="task-list-item-checkbox" value="on" disabled checked>'
        tagmap[tag.strip].push(content)
      end
    end

    post.site.data["tagmap"] = tagmap
  end
end

# Post-write
#
# This is the last step. Once the posts are all written, we can build the
# project pages. This works by taking the mapping of projects to HTML fragments
# from previously and generating new pages for each project and injecting the
# HTML fragments into their respective pages.
Jekyll::Hooks.register :site, :post_write do |site|
  dir = site.config['projects_dir'] || 'projects'
  dest = site.config["destination"]

  if site.data.key?("tagmap")
    # load in the all generated HTML for the project page, we're going to clone
    # this and inject our new content into it to avoid having to deal with liquid
    template = File.read(File.join(dest, dir, 'index.html'))
    doc = Nokogiri::HTML template

    site.data["tagmap"].each_key do |tag|
      path = File.join(dest, dir, tag)
      FileUtils.mkdir_p path
      File.open(File.join(path, "index.html"), 'w') do |f|
        # inject new title
        doc.at_css('h1.post-title').inner_html = "Project ##{tag} <a href=\"#latest\">&#8617;</a>"

        # construct one body of HTML from all the separate fragments
        new_node_set = Nokogiri::XML::NodeSet.new(doc)
        site.data["tagmap"][tag].each do |content|
          new_node_set << Nokogiri::HTML::fragment(content)
        end

        content = doc.at_css('div.post-content')

        # skeletonize page and inject new content
        content.children.remove rescue nil
        content << new_node_set.to_html
        content << "<div id=latest></div>"

        f.write(doc.to_html)
      end
    end
  end
end


# fixes relative paths for the new tag files
def fix_links(doc, old_path, new_path)
  # figure out relative link mapping
  prefix = Pathname.new(old_path).relative_path_from(Pathname.new(new_path))

  url_tags = {
    'img'    => 'src',
    'script' => 'src',
    'a'      => 'href'
  }

  # grab all url links
  doc.search(url_tags.keys.join(',')).each do |node|
    url_param = url_tags[node.name]
    src = node[url_param]

    unless src.empty?
      path = Pathname.new(src)
      uri = URI.parse(src)
      # only fix relative links and non http calls
      if path.relative? && !%w( http https ).include?(uri.scheme)
        node[url_param] = (prefix+path).to_s
      end
    end
  end
end
