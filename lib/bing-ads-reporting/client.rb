require 'pry'
module BingAdsReporting
  class Client
    include Formatter
    API_CALL_RETRY_COUNT = 3

    def initialize(settings, logger)
      soap_header = header(settings)
      log_level = settings[:log_level] || :info
      @logger = logger
      @soap_client = Savon.client({
        wsdl: "https://api.bingads.microsoft.com/Api/Advertiser/Reporting/V9/ReportingService.svc?wsdl",
        namespaces: {"xmlns:arr" => 'http://schemas.microsoft.com/2003/10/Serialization/Arrays'},
        soap_header: soap_header,
        log_level: log_level,
        pretty_print_xml: true
      })
    end

    def call(service, message, retry_count = API_CALL_RETRY_COUNT)
      1.upto(retry_count + 1) do |retry_index|
        begin
          binding.pry
          response = @soap_client.call(service, message: message)
          break response
        rescue Savon::SOAPFault => error
          next if retry_index <= retry_count
          break handle_soap_fault(error)
        end
      end
    end

    def download(url, retry_count = API_CALL_RETRY_COUNT)
      1.upto(retry_count + 1) do |retry_index|
        begin
          @logger.info "Downloading Bing material from: #{url}"
          curl = Curl::Easy.new(url)
          curl.perform
          body = curl.body_str
          break body
        rescue => ex
          next if retry_index <= retry_count
          raise DownloadError, ex.message
        end
      end
    end

    private

    def header(settings)
      base_header = {
        ns('ApplicationToken') => settings[:application_token],
        ns('CustomerAccountId') => settings[:account_id],
        ns('CustomerId') => settings[:customer_id],
        ns('DeveloperToken') => settings[:developer_token]
      }

      append_authentication_params(base_header, settings)
    end

    def append_authentication_params(header, settings)
      if settings[:username] && settings[:password]
        header[ns('UserName')] = settings[:username]
        header[ns('Password')] = settings[:password]
      elsif settings[:authentication_token]
        header[ns('AuthenticationToken')] = settings[:authentication_token]
      else
        raise AuthenticationParamsMissing, 'no username/password combination or authentication token specified'
      end
      header
    end

    def handle_soap_fault(error)
      msg = 'unexpected error'
      err = error.to_hash[:fault][:detail][:ad_api_fault_detail][:errors][:ad_api_error][:error_code] rescue nil
      msg = error.to_hash[:fault][:detail][:ad_api_fault_detail][:errors][:ad_api_error][:message] if err
      if err.nil?
        err = error.to_hash[:fault][:detail][:api_fault_detail][:operation_errors][:operation_error][:error_code] rescue nil
        msg = error.to_hash[:fault][:detail][:api_fault_detail][:operation_errors][:operation_error][:message] if err
      end
      if err == 'AuthenticationTokenExpired'
        @logger.error err
        raise TokenExpired, msg
      end
      @logger.error error.http.code
      @logger.error msg
      raise ClientDataError, "HTTP error code: #{error.http.code}\n#{msg}"
    end
  end
end
