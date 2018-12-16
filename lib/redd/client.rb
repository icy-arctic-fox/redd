# frozen_string_literal: true

require 'excon'
require 'json'

module Redd
  # The base class for JSON-based HTTP clients. Generic enough to be used for basically anything.
  class Client
    # The default User-Agent to use if none was provided.
    USER_AGENT = "Ruby:Redd:v#{Redd::VERSION} (by unknown)"

    # Holds a returned HTTP response.
    Response = Struct.new(:code, :headers, :raw_body) do
      def body
        @body ||= JSON.parse(raw_body, symbolize_names: true)
      end
    end

    # Create a new client.
    # @param endpoint [String] the base endpoint to make all requests from
    # @param user_agent [String] a user agent string
    def initialize(endpoint:, user_agent: USER_AGENT)
      @endpoint = endpoint
      @user_agent = user_agent
    end

    # Make an HTTP request.
    # @param verb [:get, :post, :put, :patch, :delete] the HTTP verb to use
    # @param path [String] the path relative to the endpoint
    # @param options [Hash] the request parameters
    # @option options [Hash] :params the parameters to supply with the url
    # @option options [Hash] :form the parameters to supply in the body
    # @option options [Hash] :body the direct body contents
    # @return [Response] the response
    def request(verb, path, options = {})
      # puts "#{verb.to_s.upcase} #{path}", '  ' + options.inspect

      full_path = if (params = options[:params])
        uri = URI.parse(path)
        qs  = URI.encode_www_form(params)
        uri.query = if uri.query
          [uri.query, qs].join('&')
        else
          qs
        end
        uri.to_s
      else
        path
      end

      args = {
        method: verb,
        path:   full_path,
        read_timeout:  5,
        write_timeout: 5
      }
      
      if (body = options[:body])
        args[:body] = body
      elsif (form = options[:form])
        args[:body] = URI.encode_www_form(form)
      end

      response = connection.request(args)
      Response.new(response.status, response.headers, response.body)
    end

    # Make a GET request.
    # @param path [String] the path relative to the endpoint
    # @param options [Hash] the parameters to supply
    # @return [Response] the response
    def get(path, options = {})
      request(:get, path, params: options)
    end

    # Make a POST request.
    # @param path [String] the path relative to the endpoint
    # @param options [Hash] the parameters to supply
    # @return [Response] the response
    def post(path, options = {})
      request(:post, path, form: options)
    end

    # Make a PUT request.
    # @param path [String] the path relative to the endpoint
    # @param options [Hash] the parameters to supply
    # @return [Response] the response
    def put(path, options = {})
      request(:put, path, form: options)
    end

    # Make a PATCH request.
    # @param path [String] the path relative to the endpoint
    # @param options [Hash] the parameters to supply
    # @return [Response] the response
    def patch(path, options = {})
      request(:patch, path, form: options)
    end

    # Make a DELETE request.
    # @param path [String] the path relative to the endpoint
    # @param options [Hash] the parameters to supply
    # @return [Response] the response
    def delete(path, options = {})
      request(:delete, path, form: options)
    end

    private

    # @return [HTTP::Connection] the base connection object
    def connection(options = {})
      # TODO: Make timeouts configurable
      headers = {
        'User-Agent' => @user_agent
      }
      if options.key?(:headers)
        headers.merge!(options[:headers])
        options.delete(:headers)
      end
      args = {
        persistent:      true,
        connect_timeout: 5,
        headers:         headers
      }.merge(**options)
      @connection ||= Excon.new(@endpoint, **args)
    end
  end
end
