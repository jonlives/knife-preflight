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

        cookbook = raw_query.split("::").first
        unconstrained_env_search = Chef::Search::Query.new
        unconstrained_envs = unconstrained_env_search.search('environment', "NOT cookbook_versions:#{cookbook}").first.map{|e|e.name}

        q_nodes = Chef::Search::Query.new

        escaped_query = raw_query.sub( "::", "\\:\\:")
        
        if !raw_query.include? "::"
          node_query = "recipes:*#{escaped_query} OR recipes:*#{escaped_query}\\:\\:default"
          ui.msg("Searching for nodes containing #{raw_query} OR #{raw_query}::default in their expanded run_list...\n")
        elsif raw_query.include? "::default"
          node_query = "recipes:*#{escaped_query} OR recipes:*#{escaped_query.gsub( "\\:\\:default","")}"
          ui.msg("Searching for nodes containing #{raw_query} OR #{raw_query.gsub( "::default","")} in their expanded run_list...\n")
        else
          node_query = "recipes:*#{escaped_query}"
          ui.msg("Searching for nodes containing #{raw_query} in their expanded run_list...\n")
        end
        query_nodes = URI.escape(node_query, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))

        result_items_nodes = []
        result_count_nodes = 0

        rows = config[:rows]
        start = config[:start]
        begin
          q_nodes.search('node', query_nodes, config[:sort], start, rows) do |node_item|
            formatted_item_node = format_for_display(node_item)
            if formatted_item_node.respond_to?(:has_key?) && !formatted_item_node.has_key?('id')
                formatted_item_node['id'] = node_item.has_key?('id') ? node_item['id'] : node_item.name
            end
            result_items_nodes << formatted_item_node
            result_count_nodes += 1
          end
        rescue Net::HTTPServerException => e
          msg = Chef::JSONCompat.from_json(e.response.body)["error"].first
          ui.error("knife preflight failed: #{msg}")
          exit 1
        end

        if ui.interchange?
          output({:results => result_count_nodes, :rows => result_items_nodes})
        else
          ui.msg "#{result_count_nodes} Nodes found"
          ui.msg("\n")
          result_items_nodes.each do |item|
            output("#{item.name}#{unconstrained_envs.include?(item.chef_environment) ? " - in environment #{item.chef_environment}, no version constraint for #{cookbook} cookbook" : nil}")
          end
        end

        ui.msg("\n")
        ui.msg("\n")


        q_roles = Chef::Search::Query.new
        
        if !raw_query.include? "::"
          role_query = "run_list:recipe\\[#{escaped_query}\\] OR run_list:recipe\\[#{escaped_query}\\:\\:default\\]"
          ui.msg("Searching for roles containing #{raw_query} OR #{raw_query}::default in their expanded run_list...\n")
        elsif raw_query.include? "::default"
          role_query = "run_list:recipe\\[#{escaped_query}\\] OR run_list:recipe\\[#{escaped_query.gsub( "\\:\\:default","")}\\]"
          ui.msg("Searching for roles containing #{raw_query} OR #{raw_query.gsub( "::default","")} in their expanded run_list...\n")
        else
          role_query = "run_list:recipe\\[#{escaped_query}\\]"
          ui.msg("Searching for roles containing #{raw_query} in their expanded run_list...\n")
        end

        query_roles = URI.escape(role_query,
                           Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))

        result_items_roles = []
        result_count_roles = 0

        rows = config[:rows]
        start = config[:start]
        begin
          q_roles.search('role', query_roles, config[:sort], start, rows) do |role_item|
            formatted_item_role = format_for_display(role_item)
            if formatted_item_role.respond_to?(:has_key?) && !formatted_item_role.has_key?('id')
              formatted_item_role['id'] = role_item.has_key?('id') ? role_item['id'] : role_item.name
            end
            result_items_roles << formatted_item_role
            result_count_roles += 1
          end
        rescue Net::HTTPServerException => e
          msg = Chef::JSONCompat.from_json(e.response.body)["error"].first
          ui.error("knife preflight failed: #{msg}")
          exit 1
        end

        if ui.interchange?
          output({:results => result_count_roles, :rows => result_items_roles})
        else
          ui.msg "#{result_count_roles} Roles found"
          ui.msg("\n")
          result_items_roles.each do |role_item|
            output(role_item.name)
          end
        end

        ui.msg("\n")
        ui.msg("\n")
        ui.msg("Found #{result_count_nodes} nodes and #{result_count_roles} roles using the specified search criteria")
      end
    end
  end
