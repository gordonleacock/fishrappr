require 'digest'
module ApplicationHelper

  # extend RangeLimitHelper

  ##
  # Link to the previous document in the current search context
  def link_to_previous_issue_page(previous_document)
    link_opts = {}
    link_to_unless previous_document.nil?, raw(t('views.issue.previous')), url_for_document(previous_document), link_opts do
      content_tag :span, raw(t('views.issue.previous')), :class => ''
    end
  end

  ##
  # Link to the next document in the current search context
  def link_to_next_issue_page(next_document)
    link_opts = {}
    link_to_unless next_document.nil?, raw(t('views.issue.next')), url_for_document(next_document), link_opts do
      content_tag :span, raw(t('views.issue.next')), :class => ''
    end
  end

  def current_page_number(document)
    page_number = document.fetch('page_no_t').first
    unless page_number
      page_number = "(seq #{document.fetch('sequence')})"
    end
    page_number
  end

  def hathitrust_pdf_link(document, **kw)
    namespace = document.fetch('ht_namespace')
    barcode = document.fetch('ht_barcode')
    id = namespace + "." + barcode
    seq = document.fetch('text_link').gsub(/[^\d+]/, '').to_i.to_s
    Rails.configuration.download_service + '?id=' + id + ';seq=' + seq + ';attachment=1'
  end

  def hathitrust_image_src(document, **kw)
    path_info = []
    namespace = document.fetch('ht_namespace')

    if namespace == 'fake'
      return '#'
    end

    barcode = document.fetch('ht_barcode')
    path_info << "#{namespace}.#{barcode}"

    img_link = document.fetch('img_link')
    path_info << img_link

    format = nil
    unless kw.empty?
      path_info << kw.fetch(:region, 'full')
      path_info << kw.fetch(:size, 'full')
      path_info << kw.fetch(:rotation, '0')
      path_info << kw.fetch(:quality, 'default')
      format = kw.fetch(:format, 'jpg')
    end

    path_info = path_info.join('/')
    path_info += "." + format if ( format )

    "#{Rails.configuration.iiif_service}#{path_info}"
  end

  def hathitrust_thumbnail_src(document, **kw)
    size = kw.fetch(:size, ',250')
    hathitrust_image_src(document, size: size)
  end

  def hathitrust_thumbnail_style(document, **kw)
    namespace = document.fetch('ht_namespace')

    if namespace == 'fake'
      image_height = 1600
      image_width = 1185
    else
      image_height = document.fetch('image_height_ti')
      image_width = document.fetch('image_width_ti')
    end
    size = kw.fetch(:size, ',250')
    width, height = size.split(',')
    if not width.blank?
      width = width.to_i
      height = ( image_height * ( width.to_f / image_width ) ).to_i
    else
      height = height.to_i
      width = ( image_width * ( height.to_f / image_height ) ).to_i
    end

    # { 'min-width' => width, 'min-height' => height }
    "min-width: #{width}px; min-height: #{height}px"

  end

  def hathitrust_image(document, **kw)
    namespace = document.fetch('ht_namespace')
    return fake_image(document).html_safe if namespace == 'fake'
    %Q{<img src="#{hathitrust_image_src(document, **kw)}" />}.html_safe
  end

  def hathitrust_thumbnail(document, **kw)
    namespace = document.fetch('ht_namespace')
    return fake_image(document, kw.fetch(:size, ',250')) if namespace == 'fake'
    %Q{<img src="#{hathitrust_thumbnail_src(document, **kw)}" />}.html_safe
  end

  # TO DO: Needs to be moved into a style using a data attribute
  def hathitrust_background_thumbnail(document, **kw)
    namespace = document.fetch('ht_namespace')
    tn = "style=\'background: url(\""
    if namespace == 'fake'
      tn += "#{image_url("fake_image.png")}"
    else
      tn += "#{hathitrust_thumbnail_src(document, **kw)}"
    end
    tn += "\") top left no-repeat;\'"
    tn.html_safe
  end

  def render_date_format(args)
    args.to_date.strftime("%B %d, %Y")
  end  

  def highlight_search_terms(full_text)
    search_params = current_search_session.try(:query_params) 
    search_field = search_params["q"] 
    if search_field
      highlighted_field = '<strong>'+ search_field + '</strong>'.html_safe 
      @document["page_text"].first.gsub! search_field,highlighted_field 
    end
    return @document["page_text"].first 
  end

  def render_plain_text(document, field, breaks=true)
    retval = []
    texts = document.has_highlight_field?(field) ? document.highlight_field(field) : document.fetch(field)
    prefix = breaks ? '' : '&#8230;'.html_safe
    retval = ActiveSupport::SafeBuffer.new
    Array(texts).each do |text|
      next if text.strip.blank?
      retval << '<p>'.html_safe
      retval << prefix + text + prefix # .gsub("\n", " ")
      retval << '</p>'.html_safe
    end
    retval.gsub!(/\n\n+/, "\n\n")
    retval.gsub!(/\n/, breaks ? "<br />\n".html_safe : " ")
    (retval.gsub('[[[[', '<span class="highlight">'.html_safe).gsub(']]]]', '</span>'.html_safe)).html_safe
  end

  NON_LEXEMES = Regexp.new("^[^a-zA-Z0-9]+|[^a-zA-Z0-9]+$|'s$")
  def cleanup_word(text)
    text.gsub(NON_LEXEMES, '').strip
  end

  def blank_identifier(*args)
    "_:N" + hash_words(*args)
  end

  def hash_words(*args)
    Digest::MD5.hexdigest args.join('')
  end

  require 'ffaker'
  def fake_image(document, size=nil)
    namespace = document.fetch('ht_namespace')
    barcode = document.fetch('ht_barcode')
    text_link = document.fetch('text_link')
    issue_no = document.fetch("issue_no_t").first
    page_sequence = document.fetch("sequence")
    key = namespace + "." + barcode + "/" + text_link
    bgcolor = Rails.cache.fetch("#{namespace}.#{barcode}/bgcolor") do
      # [ 'sky', 'vine', 'lava', 'gray', 'industrial', 'social' ].sample
      "#%06x" % rand(0..0xffffff)
    end
    text = "#{issue_no} / #{page_sequence}"
    if size == ',150'
      return holder_tag "110x150", text, nil, {}, { bg: bgcolor }
    elsif size == ",250"
      return holder_tag "187x250", text, nil, {}, { bg: bgcolor }
    elsif size == '200,'
      return holder_tag "200x270", text, nil, {}, { bg: bgcolor }
    else
      # text = Rails.cache.fetch(key) do
      #   FFaker::CheesyLingo.sentence
      # end
      return holder_tag "375x500", text, nil, {}, { bg: bgcolor }
    end
  end

  # SEARCH SELECT OPTIONS  
  # See blacklight_range_limit/app/helpers/range_limit_helper.rb, use date_issued_yyy_ti
  # Used by date search box
  def get_solr_years_options
    min_year = range_results_endpoint("date_issued_yyyy_ti", 'min')
    max_year = range_results_endpoint("date_issued_yyyy_ti", 'max')
    if (!min_year.nil? && !max_year.nil?)
      years_range = (min_year..max_year) 
    else
      years_range = (1890..1970)
    end
    years_options = [];
    years_range.each do |y| 
      item = [y, y]
      years_options.push item
    end
    years_options
  end

  # Used by date search box
  def get_month_options
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    months_range = (1..12)
    month_options = [];
    months_range.each do |m| 
      item = [months[m-1], m]
      month_options.push item
    end
    month_options
  end

  # Used by date search box
  def get_date_options
    date_range = (1..31)
    date_options = [];
    date_range.each do |d| 
      item = [d, d]
      date_options.push item
    end
    date_options
  end  
  
  # BROWSE OPTIONS  
  # Used by browse page
  def get_decade_browse_options
    decades = [1890, 1900, 1910, 1920, 1930, 1940, 1950, 1960, 1970, 1980, 1990, 2000, 2010, 2010]
    decades_range = (1..decades.count)
    decade_options = [];

    item = ["Any Decade", "Any Decade"]
    decade_options.push item

    decades_range.each do |m| 
      item = [decades[m-1], decades[m-1]]
      decade_options.push item
    end
    decade_options
  end

  # Used by browse page as initial year options; see js for how this changes for different decades
  def get_year_browse_options
    years_range = (1890..2016)
    year_options = [];

    years_range.each do |m| 
      item = [m, m]
      year_options.push item
    end
    year_options.reverse!

    item = ["Any Year", "Any Year"]
    year_options.insert(0, item)

  end

end
