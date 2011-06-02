module SimpleBreadcrumbs
  module Breadcrumbs
    Element = Struct.new(:name, :path, :controller)

    class Builder
      def initialize(context, elements, options)
        @context = context
        @elements = elements
        @options = {:separator => " &raquo; ", :wrapper => nil, :tag => nil}.merge(options)
      end

      def render
        raise NotImplementedError
      end

      protected

      def compute_name(name, controller)
        i18n_scope = [:breadcrumbs] + (controller.controller_path.split('/'))

        name = name.call(controller) if name.is_a?(Proc)

        case name
          when Symbol
            I18n.t(name, :scope => i18n_scope)
          when Array
            I18n.t(name.first, name.second.merge(:scope => i18n_scope))
          when String
            name
          else
            raise 'Simple Breadcrumbs: Unknown type of name.'
        end
      end

      def compute_path(path)
        case path
          when Proc
            path.call(@context)
          when Hash
            @context.url_for(path)
          when Symbol
            @context.send(path)
          when String
            path
          when NilClass
            nil
          else
            raise 'Simple Breadcrumbs: Unknown type of path.'
        end
      end
    end

    class SimpleBuilder < Builder
      def render
        elements = @elements.collect do |element|
          render_element(element, :last => (@elements.last == element))
        end.join(@options[:separator]).html_safe

        if @options[:wrapper]
          @context.content_tag(@options[:wrapper], elements)
        else
          elements
        end
      end

      def render_element(element, options)
        #content = @context.link_to_unless_current(compute_name(element.name, element.controller), compute_path(element.path))

        content = (options[:last] || !element.path ? compute_name(element.name, element.controller) : @context.link_to(compute_name(element.name, element.controller), compute_path(element.path)))

        if @options[:tag]
          @context.content_tag(@options[:tag], content)
        else
          content
        end
      end
    end
  end

  module ControllerMixin
    def self.included(base)
      base.extend ClassMethods
      base.send :helper, HelperMethods

      base.class_eval do
        include InstanceMethods
        helper HelperMethods
        helper_method :add_breadcrumb, :breadcrumbs
      end
    end

    module ClassMethods
      def add_breadcrumb(*args)
        options = args.extract_options!
        base_controller = self
        before_filter(options) do |controller|
          if args.count == 1
            name, path = controller.send("breadcrumb_#{args.first}")
          else
            name, path = args.first, args.second
          end

          controller.send(:add_breadcrumb, name, path, base_controller) if name
        end
      end
    end

    module InstanceMethods
      protected

      def add_breadcrumb(name, path, controller = self)
        self.breadcrumbs << Breadcrumbs::Element.new(name, path, controller)
      end

      def breadcrumbs
        @breadcrumbs ||= []
      end
    end

    module HelperMethods
      def render_breadcrumbs(options = {}, &block)
        builder = (options.delete(:builder) || Breadcrumbs::SimpleBuilder).new(self, breadcrumbs, options)
        content = builder.render

        if block_given?
          concat(capture(content, &block))
        else
          content
        end
      end
    end
  end
end

ActionController::Base.send :include, SimpleBreadcrumbs::ControllerMixin
