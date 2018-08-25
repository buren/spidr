require 'set'

module Spidr
  class Agent
    # Common locations for Sitemap(s)
    COMMON_SITEMAP_LOCATIONS = %w[
      sitemap.xml
      sitemap.xml.gz
      sitemap.gz
      sitemap_index.xml
      sitemap-index.xml
      sitemap_index.xml.gz
      sitemap-index.xml.gz
    ].freeze

    #
    # Initializes the sitemap fetcher.
    #
    def initialize_sitemap(options)
      @sitemap = options.fetch(:sitemap, false)
    end

    #
    # Returns the URLs found as per the sitemap.xml spec.
    #
    # @return [Array<URI::HTTP>, Array<URI::HTTPS>]
    #   The URLs found.
    #
    # @see https://www.sitemaps.org/protocol.html
    def sitemap_urls(url)
      return [] unless @sitemap
      base_url = to_base_url(url)

      # Support passing sitemap: '/path/to/sitemap.xml'
      if @sitemap.is_a?(String)
        sitemap_path = @sitemap
        sitemap_path = "/#{@sitemap}" unless @sitemap.start_with?('/')
        return get_sitemap_urls(url: "#{base_url}#{sitemap_path}")
      end

      # Check /robots.txt
      if sitemap_robots
        if urls = sitemap_robots.other_values(base_url)['Sitemap']
          return urls.flat_map { |u| get_sitemap_urls(url: u) }
        end
      end

      # Check for sitemap.xml in common locations
      COMMON_SITEMAP_LOCATIONS.each do |path|
        if (page = get_page("#{base_url}/#{path}")).code == 200
          return get_sitemap_urls(page: page)
        end
      end

      []
    end

    private

    def sitemap_robots
      return @robots if @robots
      return unless @sitemap == :robots

      unless Object.const_defined?(:Robots)
        raise(ArgumentError,":robots option given but unable to require 'robots' gem")
      end

      Robots.new(@user_agent)
    end

    def get_sitemap_urls(url: nil, page: nil)
      page = get_page(url) if page.nil?
      return [] unless page

      if page.sitemap_index?
        page.each_sitemap_index_url.flat_map { |u| get_sitemap_urls(url: u) }
      else
        page.sitemap_urls
      end
    end

    def to_base_url(url)
      uri = url
      uri = URI.parse(url) unless url.is_a?(URI)

      "#{uri.scheme}://#{uri.host}"
    end
  end
end
