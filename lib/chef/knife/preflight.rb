#
# Author:: Jon Cowie (<jonlives@gmail.com>)
# Copyright:: Copyright (c) 2011 Jon Cowie
# License:: GPL

# Based on the knife chef plugin by:
# Adam Jacob (<adam@opscode.com>)
# Copyright:: Copyright (c) 2009 Opscode, Inc.

require 'chef/knife'
require 'chef/knife/core/node_presenter'

module KnifePreflight
  class Preflight < Chef::Knife

    deps do
      require 'chef/node'
      require 'chef/environment'
      require 'chef/api_client'
      require 'chef/search/query'
    end

    include Chef::Knife::Core::NodeFormattingOptions

    banner "knife preflight QUERY (options)"

    option :sort,
           :short => "-o SORT",
           :long => "--sort SORT",
           :description => "The order to sort the results in",
           :default => nil

    option :start,
           :short => "-b ROW",
           :long => "--start ROW",
           :description => "The row to start returning results at",
           :default => 0,
           :proc => lambda { |i| i.to_i }

    option :rows,
           :short => "-R INT",
           :long => "--rows INT",
           :description => "The number of rows to return",
           :default => 1000,
           :proc => lambda { |i| i.to_i }


    def run
      if config[:query] && @name_args[0]
        ui.error "please specify query as an argument or an option via -q, not both"
        ui.msg opt_parser
        exit 1
      end
      raw_query = config[:query] || @name_args[0]
      if !raw_query || raw_query.empty?
        ui.error "no query specified"
        ui.msg opt_parser
        exit 1
      end

      result_count_nodes = perform_query(raw_query, 'node')

      result_count_roles = perform_query(raw_query, 'role')

      ui.msg("Found #{result_count_nodes} nodes and #{result_count_roles} roles using the specified search criteria")
    end

    def perform_query(raw_query, type='node')
      q = Chef::Search::Query.new

      if type == 'node'
        cookbook = raw_query.split("::").first
        unconstrained_env_search = Chef::Search::Query.new
        unconstrained_envs = unconstrained_env_search.search('environment', "NOT cookbook_versions:#{cookbook}").first.map{|e|e.name}
      end

      # strip default if it exists to simplify logic
      raw_query = raw_query.sub("::default", "")
      escaped_query = raw_query.sub( "::", "\\:\\:")

      if !raw_query.include? "::"
        if type == 'node'
          search_query = "recipes:#{escaped_query} OR recipes:#{escaped_query}\\:\\:default"
          search_query += " OR " + search_query.gsub("recipes", "last_seen_recipes")
        else
          search_query = "run_list:recipe\\[#{escaped_query}\\] OR run_list:recipe\\[#{escaped_query}\\:\\:default\\]"
        end
        ui.msg("Searching for #{type}s containing #{raw_query} OR #{raw_query}::default in their expanded run_list or added via include_recipe...\n")
      else
        if type == 'node'
          search_query = "recipes:#{escaped_query}"
          search_query += " OR " + search_query.gsub("recipes", "last_seen_recipes")
        else
          search_query = "run_list:recipe\\[#{escaped_query}\\]"
        end
        ui.msg("Searching for #{type}s containing #{raw_query} in their expanded run_list or added via include_recipe......\n")
      end

      query = URI.escape(search_query, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))

      result_items = []
      result_count = 0

      rows = config[:rows]
      start = config[:start]
      begin
        q.search(type, query, config[:sort], start, rows) do |item|
          formatted_item = format_for_display(item)
          if formatted_item.respond_to?(:has_key?) && !formatted_item.has_key?('id')
            formatted_item.normal['id'] = item.has_key?('id') ? item['id'] : item.name
          end
          result_items << formatted_item
          result_count += 1
        end
      rescue Net::HTTPServerException => e
        msg = Chef::JSONCompat.from_json(e.response.body)["error"].first
        ui.error("knife preflight failed: #{msg}")
        exit 1
      end

      if ui.interchange?
        output({:results => result_count, :rows => result_items})
      else
        ui.msg "#{result_count} #{type.capitalize}s found"
        ui.msg("\n")
        result_items.each do |item|
          if item.instance_of?(Chef::Node)
            output("#{item.name}#{unconstrained_envs.include?(item.chef_environment) ? " - in environment #{item.chef_environment}, no version constraint for #{cookbook} cookbook" : nil}")
          else
            output(item.name)
          end
        end
      end

      ui.msg("\n")
      ui.msg("\n")
      return result_count
    end
  end
end
