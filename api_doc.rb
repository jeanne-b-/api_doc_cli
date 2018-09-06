require 'rubygems'
require 'bundler/setup'
Bundler.require(:default)
require 'terminfo'

class ApiDoc
  include CommandLineReporter

  def initialize
    doc = JSON.parse(HTTP.get('https://api.intra.42.fr/apidoc/2.0.json'))
    @doc = doc["docs"]["resources"]
    @prompt = TTY::Prompt.new
    @width = TermInfo.screen_size[1]
  end

  def select_resource
    resource_name = @prompt.select('Browse resource', @doc.keys, filter: true, marker: "🤖")
    resource = @doc[resource_name]
    select_method resource
    select_resource
  end

  def select_method(resource)
    choices = resource['methods'].map {|m| ["[#{m['name']}] #{m['doc_url']}", m['name']]}.to_h
    action = @prompt.select('Choose a method', choices, marker: "👮")
    show_method(resource, action)
  end

  def show_method(resource, action)
    docs = resource['methods'].select {|m| m['name'] == action}
    print_resource_description resource, docs.first
    keys = %w(full_name description required expected_type validator)
    table(border: true) do
      row header: true do
        keys.each do |k|
          column k, width: @width / keys.count - 3
        end
      end
      docs.each do |doc|
        print_param doc, keys
      end
    end
    if docs.first['examples'].any?
      print_example docs.first['examples'].first
    end
  end

  private
  def print_resource_description(resource, action)
    horizontal_rule width: @width, color: 'blue'
    print((resource['name'] + ': ').blue)
    puts strip_html resource['short_description']
    print((action['name'].capitalize + ': ').blue)
    puts strip_html action['full_description']
    horizontal_rule width: @width, color: 'blue'
    puts
  end

  def print_example(example)
    puts
    puts((example['verb'] + ' ' + example['path']).blue)
    puts 'with params:'.yellow
    ap example['request_data']
    puts 'response:'.yellow
    ap example['response_data']
    horizontal_rule width: @width, color: 'blue'
  end

  def print_param(doc, keys)
    doc['params'].each do |param|
      row do
        keys.each do |k|
          column strip_html(param[k].to_s)
        end
      end
      if param['params'] and !param['params'].empty?
        print_param param, keys
      end
    end
  end

  def strip_html(string)
    string.strip.gsub(/<\/?[^>]*>/, "")
  end
end

api_doc = ApiDoc.new()
api_doc.select_resource
