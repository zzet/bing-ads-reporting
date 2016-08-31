require_relative 'bing-ads-reporting/service'
require_relative 'bing-ads-reporting/version'
require 'logger'
require 'savon'

module BingAdsReporting
  class TokenExpired < Exception; end
  class ClientDataError < Exception; end
end
