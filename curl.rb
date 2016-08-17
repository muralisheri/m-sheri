#!/usr/bin/ruby
require 'net/http'
require 'uri'

http_request 'posting data' do
  action :post
  uri = URI.parse ('curl -L https://52.91.41.6:8443/setup/api?api_key=Darling143') 
end