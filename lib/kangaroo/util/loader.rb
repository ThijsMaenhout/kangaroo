require 'active_support/core_ext/enumerable'
require 'kangaroo/ruby_adapter/base'

module Kangaroo
  module Util
    class Loader
      autoload :Model,                 'kangaroo/util/loader/model'
      autoload :Namespace,             'kangaroo/util/loader/namespace'
      autoload :RootNamespace,         'kangaroo/util/loader/root_namespace'
      autoload :Reflection,            'kangaroo/util/loader/reflection'
      autoload :InformationRepository, 'kangaroo/util/loader/information_repository'

      attr_accessor :model_names, :models, :database, :namespace

      # Initialize a Loader instance
      #
      # @param [Array] model_names List of model names / patterns to load
      def initialize model_names, database, namespace = "Oo"
        @namespace = namespace[0,2] == "::" ? namespace : "::#{namespace}"
        @database = database
        @model_names = model_names
        sanitize_model_names
        root_module.database = database
      end

      # Loads matching models and uses {Kangaroo::RubyAdapter::Base RubyAdapter} to
      # create the neccessary Ruby classes.
      #
      # @return [Array] list of ruby models
      def load!
        load_oo_models
        sort_oo_models
        adapt_oo_models
      end

      def create_namespace!
        root_module
      end

      protected
      def root_module
        namespace.constantize.tap do |ns|
          unless ns.respond_to?(:namespace)
            ns.send :extend, Kangaroo::Util::Loader::Namespace
            ns.namespace = ns
          end

          unless ns.respond_to?(:oo_to_ruby)
            ns.send :extend, Kangaroo::Util::Loader::RootNamespace
          end
        end

      rescue NameError
        eval <<-RUBY
          module #{namespace}
            extend Kangaroo::Util::Loader::RootNamespace
            self.namespace = #{namespace}
          end
        RUBY
      end

      def reflection_model
        root_module.reflection_model
      end

      def load_oo_models
        @models = model_names.sum([]) do |model_name|
          reflection_model.where("model ilike #{model_name}").all
        end.uniq
      end

      def sort_oo_models
        @models = @models.sort_by &:length_of_model_name
      end

      def adapt_oo_models
        @models.map do |model|
          RubyAdapter::Base.new(model).to_ruby
        end
      end

      def sanitize_model_names
        @model_names = case @model_names
        when nil, []
          []
        when :all
          ['%']
        when String
          [replace_wildcard(@model_names)]
        when Array
          @model_names.map do |model_name|
            replace_wildcard model_name
          end
        else
          raise "Expected list of models or :all, got #{@model_names.inspect}"
        end
      end

      def replace_wildcard string
        string.gsub '*', '%'
      end
    end
  end
end
