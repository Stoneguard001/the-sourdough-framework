require 'pry'
require 'nokogiri'

# This class goes through the generated default LaTeX HTML and performs
# several optimisations on the HTML. Nokogiri is used to facilitate the
# modifications.

class ModifyBuild
  def self.build
    new.build
  end

  def build
    build_latex_html
  end

  private

  def build_latex_html
    system("rm -rf #{build_dir}/")
    system("mkdir #{build_dir}/")
    copy_source_to_local_dir_for_modification
    copy_assets_into_folder
    list_of_files_to_modify.each do |filename|
      modify_file(filename)
    end
  end

  def modify_file(filename)
    orig_text = File.read(filename)
    text = fix_double_slashes(orig_text)
    text = fix_navigation_bar(text)
    text = fix_titles(text)
    text = fix_menu(text)
    text = fix_cover_page(text) if is_cover_page?(filename)
    text = add_home_link_to_menu(text)
    text = fix_anchor_hyperlinks_menu(text)
    text = add_favicon(text)
    text = add_meta_tags(text, filename)
    text = remove_section_table_of_contents(text)
    text = mark_menu_as_selected_if_on_page(text, extract_file_from_path(filename))
    text = add_canonical_for_duplicates(text, extract_file_from_path(filename))
    text = include_javascript(text)
    text = add_text_to_coverpage(text, extract_file_from_path(filename))
    File.open(filename, "w") {|file| file.puts text }
  end

  def is_cover_page?(filename)
    ["book.html", "index.html"].any? do |name|
      filename.include?(name)
    end
  end

  def list_of_files_to_modify
    Dir.glob("#{build_dir}/*.html")
  end

  def copy_source_to_local_dir_for_modification
    system("cd ../book/ && make website") unless source_website_output_exists?
    system("cp -R ../book/#{build_dir}/* #{build_dir}")
  end

  def copy_assets_into_folder
    system("cp -R ./assets/* #{build_dir}")
  end

  def source_website_output_exists?
    File.directory?("../book/#{build_dir}/")
  end

  def build_dir
    'static_website_html'
  end

  def fix_double_slashes(text)
    text.gsub(/\/\//, "/")
  end

  def fix_navigation_bar(text)
    doc = build_doc(text)
    elements = [doc.search('.chapterToc'), doc.search('.sectionToc'), doc.search('.subsectionToc')].flatten
    elements.each do |n|
      chapter_number_or_nothing = n.children[0].text.strip.to_i
      hyperlink_node = n.children[1]
      next if hyperlink_node.nil?

      # remove unneeded text and merge into single a tag
      n.children[0].remove
      link_text = hyperlink_node.content
      # no chapter number
      if chapter_number_or_nothing == 0
        content = hyperlink_node.to_s
      else
        link_node_content = %Q{
        <span class="chapter_number">#{chapter_number_or_nothing}</span>
        <span class="link_text">#{link_text}</span>
        }
        hyperlink_node.inner_html = link_node_content
        content = hyperlink_node.to_s
      end
      n.inner_html = content
    end
    doc.to_html
  end

  # By default the titles look boring. This changes the titles of all the
  # pages and adds the book name as appendix
  def fix_titles(text)
    doc = build_doc(text)
    title_node = doc.css("title")[0]
    raise ArgumentError.new("No title found in HTML document") if title_node.nil?

    title_node.content = build_title(title_node.content)
    doc.to_html
  end

  # "3 Making a sourdough starter"
  # Should return Making a sourdough starter - The Sourdough Framework"
  def build_title(title)
    # No title, happens on index page in LaTeX build
    return title_appendix if title.length == 0

    # Starts with number
    if title[0].to_i > 0
      use_title = title.split(" ").drop(1).join(" ")
    else
      use_title = title
    end
    "#{use_title} - #{title_appendix}"
  end

  def title_appendix
    "The Sourdough Framework"
  end

  # By default the menu is not made for mobile devices. This adds mobile
  # capabilities to the menu
  def fix_menu(text)
    doc = build_doc(text)
    nav = doc.css("nav.TOC")[0]
    # page has no nav
    return text unless nav

    menu_items_html = doc.css("nav.TOC > *").to_html
    nav.add_class("menu")
    nav_content = %Q{
      #{menu_mobile_nav}
      <div class="menu-items">#{menu_items_html}</div>
    }
    nav.inner_html = nav_content
    doc.to_html
  end

  def menu_mobile_nav
  %Q{
    <a href="/" class="logo">
      The Sourdough Framework
    </a>
    <input type="checkbox" id="toggle-menu">
    <label class="hamb toggle-menu-label" for="toggle-menu"><span class="hamb-line"></span></label>
  }
  end

  # The cover page should have some additional content and allow the user to
  # click the book cover in order to start reading.
  def fix_cover_page(text)
    doc = build_doc(text)
    body = doc.css("body")[0]
    content = doc.css("body > .titlepage")[0]
    menu = doc.css("body > .menu")[0]
    cover = content.css(".center")[0]
    cover_html = cover.to_html
    cover.inner_html = "<a href='Thehistoryofsourdough.html'>#{cover_html}</a>"
    body.inner_html = "#{menu} #{content}"
    doc.to_html
  end

  # By default the menu is not made for mobile devices. This adds mobile
  # capabilities to the menu
  def fix_menu(text)
    doc = build_doc(text)
    nav = doc.css("nav.TOC")[0]
    # page has no nav
    return text unless nav

    menu_items_html = doc.css("nav.TOC > *").to_html
    nav.add_class("menu")
    nav_content = %Q{
      #{menu_mobile_nav}
      <div class="menu-items">#{menu_items_html}</div>
    }
    nav.inner_html = nav_content
    doc.to_html
  end

  def menu_mobile_nav
  %Q{
    <a href="/" class="logo">
      The Sourdough Framework
    </a>
    <input type="checkbox" id="toggle-menu">
    <label class="hamb toggle-menu-label" for="toggle-menu"><span class="hamb-line"></span></label>
  }
  end

  # The cover page should have some additional content and allow the user to
  # click the book cover in order to start reading.
  def fix_cover_page(text)
    doc = build_doc(text)
    body = doc.css("body")[0]
    content = doc.css("body > .titlepage")[0]
    menu = doc.css("body > .menu")[0]
    cover = content.css(".center")[0]
    cover_html = cover.to_html
    cover.inner_html = "<a href='Thehistoryofsourdough.html'>#{cover_html}</a>"
    body.inner_html = "#{menu} #{content}"
    doc.to_html
  end

  # Users are lost and can't easily access the root page of the book. This
  # adds a home menu item.
  def add_home_link_to_menu(text)
    doc = build_doc(text)
    menu = doc.css(".menu-items")[0]
    return text if menu.nil?

    home_html = %Q{<span class="chapterToc home-link"><a href="/">Home</a></span>}
    appendix_html = %Q{
      <span class="chapterToc"><a href="https://breadco.de/kofi">Donate</a></span>
      <span class="chapterToc"><a href="https://breadco.de/hardcover-book">Hardcover Book</a></span>
    }
    menu.inner_html = "#{home_html} #{menu.inner_html} #{appendix_html}"
    doc.to_html
  end

  # Some of the links in the menu have an anchor. This makes clicking through
  # the menu frustrating as the browser jumps a lot on each request. Only do
  # this for the top level menu entries though.
  def fix_anchor_hyperlinks_menu(text)
    doc = build_doc(text)
    top_level_menus = doc.css(".menu-items > span.chapterToc > a")
    top_level_menus.each do |el|
      link = el.attribute("href").value
      splitted = link.split("#")
      next if splitted.length == 1

      el["href"] = splitted[0]
    end

    doc.to_html
  end

  def add_favicon(text)
    doc = build_doc(text)
    head = doc.css("head")[0]
    fav_html = %Q{<link rel="shortcut icon" type="image/x-icon" href="favicon.ico" />}
    head.inner_html = "#{head.inner_html} #{fav_html}"
    doc.to_html
  end

  def add_meta_tags(text, filename)
    doc = build_doc(text)
    head = doc.css("head")[0]
    title = head.css("title")[0].text
    cleaned_filename = extract_file_from_path(filename)
    description = extract_description(text, filename)
    og_image = og_image_for_chapter(cleaned_filename)
    meta_html = %Q{
      <meta property="og:locale" content="en_US">
      <meta property="og:site_name" content="The Sourdough Framework">
      <meta property="og:title" content="#{title}">
      <meta property="og:type" content="article">
      <meta property="og:url" content="https://www.the-sourdough-framework.com/#{cleaned_filename}">
      <meta property="og:description" content="#{description}">
      <meta property="description" content="#{description}">
      <meta property="og:image" content="https://www.the-sourdough-framework.com/#{og_image}" />
    }
    head.inner_html = "#{head.inner_html} #{meta_html}"
    doc.to_html
  end

  # Takes a name like "static_website_html/book.html" and returns "book.html"
  def extract_file_from_path(filename)
    result = filename.split("/")
    return filename if result.length == 1
    raise ArgumentError.new("The filename #{filename} is odd. Don't know how to handle it") if result.length > 2

    result[1]
  end

  def extract_description(text, filename)
    doc = build_doc(text)
    el = doc.css(".main-content p:first-of-type")[0]
    custom = custom_titles_per_filename(clean_filename(filename))
    return custom.strip if custom
    return "" if el.nil?
    el.text.strip
  end

  # static_website_html/Acknowledgements.html => "Acknowledgements.html"
  def clean_filename(filename)
    filename.split("/")[1]
  end

  def custom_titles_per_filename(filename)
    index_text = "The Sourdough Framework goes beyond just recipes and provides a solid knowledge foundation, covering the science of sourdough, the basics of bread making, and advanced techniques for achieving the perfect sourdough bread at home."
    data = {
      "book.html" => index_text,
      "index.html" => index_text
    }
    data[filename]
  end

  def remove_section_table_of_contents(text)
    doc = build_doc(text)
    el = doc.css(".sectionTOCS")[0]
    return text unless el

    el.remove
    doc.to_html
  end

  def og_image_for_chapter(chapter_name)
    open_graph_images_map[chapter_name] || open_graph_images_map["index.html"]
  end

  def open_graph_images_map
    {
      "Baking.html" => "og_image_baking.png",
      "Breadtypes.html" => "og_image_bread_types.png",
      "Flourtypes.html" => "og_image_flour_types.png",
      "index.html" => "og_image_general.png",
      "Howsourdoughworks.html" => "og_image_how_sourdough_works.png",
      "Makingasourdoughstarter.html" => "og_image_making_a_sourdough_starter.png",
      "Nonwheatsourdough.html" => "og_image_non_wheat_sourdough.png",
      "Sourdoughstartertypes.html" => "og_image_sourdough_starter_types.png",
      "Storingbread.html" => "og_image_storing_bread.png",
      "Thehistoryofsourdough.html" => "og_image_the_history_of_sourdough.png",
      "Wheatsourdough.html" => "og_image_troubleshooting.png",
    }
  end

  def mark_menu_as_selected_if_on_page(text, filename)
    doc = build_doc(text)
    selected = doc.css(".menu-items .chapterToc > a").find do |el|
      el["href"] == ""
    end

    # Special case for index page
    if ["index.html", "book.html"].include?(filename)
      doc.css(".menu-items .chapterToc.home-link")[0].add_class("selected")
      return doc.to_html
    end
    return doc.to_html unless selected

    # Fix that when the menu is selected the href is empty. This way users can
    # click the menu and the page will reload.
    selected["href"] = filename
    selected.parent.add_class("selected")
    doc.to_html
  end

  def add_canonical_for_duplicates(text, filename)
    # Only applies to book.html which is a duplicate for index.html. The file
    # is still needed though for proper display.
    return text unless filename == "book.html"
    doc = build_doc(text)
    head = doc.css("head")[0]
    canonical_html = %Q{
      <link rel="canonical" href="https://www.the-sourdough-framework.com" />
    }
    head.inner_html = "#{head.inner_html} #{canonical_html}"
    doc.to_html
  end

  def include_javascript(text)
    doc = build_doc(text)
    head = doc.css("head")[0]
    js_tag_html = %Q{
      <script type="text/javascript" src="script.js"></script>
    }
    head.inner_html = "#{head.inner_html} #{js_tag_html}"
    doc.to_html
  end

  def add_text_to_coverpage(text, filename)
    return text unless is_cover_page?(filename)
    doc = build_doc(text)
    content = doc.css(".titlepage")[0]
    raise ArgumentError.new(".titlepage not found in HTML") if content.nil?

    content.add_class("main-content")
    content.inner_html = "#{build_cover_page_content} #{content.inner_html}"
    doc.to_html
  end

  def build_cover_page_content
    %Q{
    <h2 class="chapterHead">
      🍞 The Sourdough Framework 📓
    </h2>
    <p class="noindent">
       The Sourdough Framework goes beyond just recipes and provides you a solid
       knowledge foundation, covering the science of sourdough, the basics of
       bread making, and advanced techniques for achieving the perfect sourdough bread at home.
    </p>

    <p class="noindent">
       Creating this book has been a labor of love. My
       main goal has always been to spread the joy of baking and empower bread
       enthusiasts like yourself. To ensure that the book remains accessible
       to everyone, I have decided to make it available as a free digital download.
    </p>

    <p class="noindent">
      However, producing and maintaining resources like this requires
      considerable time, effort, and financial investment. If you find value
      in "The Sourdough Framework" and appreciate the effort that went into
      creating it, I kindly request your support <a href="https://breadco.de/book">
      through a donation</a> or by
      <a href="https://www.breadco.de/hardcover-book">considering the purchase of
      the hardcover version of this book.</a>
    </p>

    <p class="noindent">
      Your generous contribution will not only help me cover the costs associated
      with this project but will also enable me to continue creating more valuable
      content in the future.
    </p>

    <p class="noindent">
      If you feel inspired to contribute, please consider making a donation of
      any amount through <a href="https://breadco.de/book">my donation page</a>.
      Your support will go a long way in ensuring
      that this knowledge can reach even more bread enthusiasts worldwide.
    </p>

    <p class="noindent">
      Remember, your donation is entirely voluntary and any amount you
      contribute is deeply appreciated. If you are unable to make a donation at
      this time, please know that your readership and support in spreading the
      word about "The Sourdough Framework" are invaluable contributions as well.
    </p>

    <p class="noindent">
      Thank you for being a part of this journey, and I hope that
      "The Sourdough Framework" enriches your bread-making adventures.
      Together, we can continue to share the love of baking and cultivate a
      community passionate about the art of sourdough.
    </p>
    <p class="noindent">
      You can either browse through this page or download the full book directly:
    </p>
    <p class="noindent">
      PDF: <a href="https://www.the-bread-code.io/book.pdf">https://www.the-bread-code.io/book.pdf</a><br>
      PDF (no serif): <a href="https://www.the-bread-code.io/book-sans-serif.pdf">https://www.the-bread-code.io/book-sans-serif.pdf</a>
    </p>

    <p class="noindent">
      EPUB: <a href="https://www.the-bread-code.io/book.epub">https://www.the-bread-code.io/book.epub</a><br>
      EPUB (no serif): <a href="https://www.the-bread-code.io/book-sans-serif.epub">https://www.the-bread-code.io/book-sans-serif.epub</a>
    </p>

    <p class="noindent">
      Kindle: <a href="https://www.the-bread-code.io/book.azw3">https://www.the-bread-code.io/book.azw3</a><br>
      Kindle (no serif): <a href="https://www.the-bread-code.io/book-sans-serif.azw3">https://www.the-bread-code.io/book-sans-serif.azw3</a>
    </p>

    <p class="noindent">
      The full source code of the book can be found here:
      <a href="https://www.github.com/hendricius/the-sourdough-framework">https://www.github.com/hendricius/the-sourdough-framework</a>
    </p>

    <p class="noindent">
      There's also a hardcover version of the book available featuring an even more awesome design. You can read more information here:
      <a href="https://www.breadco.de/hardcover-book">https://www.breadco.de/hardcover-book</a>
    </p>

    <p class="noindent">
      Thank you and may the gluten be strong with you,<br>
      Hendrik
    </p>
    }
  end

  def build_doc(text)
    Nokogiri::HTML(text)
  end
end

ModifyBuild.build