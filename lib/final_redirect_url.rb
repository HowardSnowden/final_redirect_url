require 'final_redirect_url/version'
require 'net/http'
require 'logger'

module FinalRedirectUrl

  def self.final_redirect_url(url, options={})
    final_url = ''
    if is_valid_url?(url)
      begin
        redirect_lookup_depth = options[:depth].to_i > 0 ? options[:depth].to_i : 10
        response_uri = get_final_redirect_url(url, redirect_lookup_depth)
        final_url =  url_string_from_uri(response_uri)
      rescue Exception => ex
        logger = Logger.new(STDOUT)
        logger.error(ex.message)
      end
    end
    final_url
  end

  private
  def self.is_valid_url?(url)
    url.to_s =~ /\A#{URI::regexp(['http', 'https'])}\z/
  end

  def self.get_final_redirect_url(url, limit = 10)
    uri = URI.parse(url)
    return uri if limit <= 0
    response = self.get_response(uri)
    if response.class == Net::HTTPOK
      return uri
    elsif %w{302 301 308}.include?(response.code)
      redirect_location = response['location']
      location_uri = URI.parse(redirect_location)
      if location_uri.host.nil?
        redirect_location = uri.scheme + '://' + uri.host + redirect_location
      end
      warn "redirected to #{redirect_location}"
      get_final_redirect_url(redirect_location, limit - 1)
    else 
      warn "final redirect returned HTTP code: #{response.code}"
      return uri
    end
  end

  def self.url_string_from_uri(uri)
    url_str = "#{uri.scheme}://#{uri.host}#{uri.request_uri}"
    if uri.fragment
      url_str = url_str + "##{uri.fragment}"
    end
    url_str
  end

  def self.get_response(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.port == 443)
    http.ciphers = ['ALL']
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    request = Net::HTTP::Get.new(uri.request_uri.to_s) 
    request['User-Agent'] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.90 Safari/537.36"
    http.request(request)
  end
end
