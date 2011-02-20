module Tabulous

  class Css
    attr_accessor :scaffolding
    attr_accessor :background_color
    attr_accessor :text_color
    attr_accessor :active_tab_color
    attr_accessor :hover_tab_color
    attr_accessor :inactive_tab_color
    def initialize
      @scaffolding = false
      @background_color = '#ccc'
      @text_color = '#444'
      @active_tab_color = 'white'
      @hover_tab_color = '#ddd'
      @inactive_tab_color = '#aaa'
    end
  end
  
  mattr_accessor :always_render_subtabs
  @@always_render_subtabs = false

  mattr_accessor :selected_tab_linkable
  @@selected_tab_linkable = false

  mattr_accessor :css
  @@css = Css.new

  def self.setup
    yield self
  end
  
  def self.tabs=(ary)
    @@tabs = []
    last_tab = nil
    ary.each do |tab_args|
      begin
        tab = Tab.new(*tab_args)
      rescue ArgumentError
        # TODO: friendlier error message
        raise "Wrong number of columns in your tabulous initializer."
      end
      if tab.subtab?
        tab.add_parent(last_tab)
      else
        last_tab = tab
      end
      @@tabs << tab
    end
  end
  
  def self.actions=(ary)
    @@actions = {}
    ary.each do |controller, action, tab|
      @@actions[controller] ||= {}
      @@actions[controller][action] ||= []
      @@actions[controller][action] << tab
    end
  end
  
  def self.main_tabs
    @@tabs.select { |t| !t.subtab? }
  end
  
  def self.selected_tab(view)
    controller = view.controller_name.to_sym
    action = view.action_name.to_sym
    for tab in @@tabs
      if selected?(controller, action, tab.name)
        if tab.subtab?
          return tab.parent
        else
          return tab
        end
      end
    end
    nil
  end

  def self.embed_styles
    return '' unless @@css.scaffolding
    %Q{
<style type="text/css">
body, ul#tabs, ul#tabs li, ul#tabs li span, ul#tabs li span a {
  margin: 0;
  padding: 0;
}

ul#tabs, ul#tabs a, ul#tabs a:visited, ul#tabs a:hover {
  color: #{@@css.text_color};
}

ul#tabs a {
  text-decoration: none;
}

ul#tabs {
  font-size: 24px;
  height: 59px;
  list-style-type: none;
  background-color: #{@@css.background_color};
  padding: 0 0 0 50px;
}

ul#tabs li {
  padding-top: 25px;
  padding-right: 5px;
  float: left;
}

ul#tabs li .tab {
  padding: 5px 15px 0px 15px;
  float: left;
	-webkit-border-top-left-radius: 8px;
	-khtml-border-radius-topleft: 8px;	
	-moz-border-radius-topleft: 8px;
	border-top-left-radius: 8px;
	-webkit-border-top-right-radius: 8px;
	-khtml-border-radius-topright: 8px;	
	-moz-border-radius-topright: 8px;
	border-top-right-radius: 8px;
}

ul#tabs li .tab {
  background-color: #{@@css.inactive_tab_color};
}

ul#tabs li.active .tab {
  background-color: #{@@css.active_tab_color};
  padding-bottom: 16px;
}

ul#tabs li a:hover {
  background-color: #{@@css.hover_tab_color};
}
</style>
    }
  end

  def self.render_tabs(view)
    html = ''
    html << embed_styles
    selected_tab_name = selected_tab(view).name
    html << '<ul id="tabs">'
    for tab in main_tabs
      next if !tab.visible?(view)
      html << render_tab(tab,
                         view,
                         :active => (tab.name == selected_tab_name),
                         :enabled => tab.enabled?(view))
    end
    html << '</ul>'
    view.raw(html)
  end
  
  def self.render_subtabs(view)
    controller = view.controller_name.to_sym
    action = view.action_name.to_sym
    tab = selected_tab(view)
    html = ''
    html << '<div id="subnav"><ul id="subtabs">'
    for subtab in tab.subtabs
      next if !subtab.visible?(view)
      html << render_tab(subtab,
                         view,
                         :active => selected?(controller, action, subtab.name),
                         :enabled => subtab.enabled?(view))
    end
    html << '</ul></div>'
    view.raw(html)
  end

  def self.render_tab(tab, view, options)
    html = ''
    klass = ''
    if options[:active]
      klass << 'active'
    else
      klass << 'inactive'
    end
    if options[:enabled]
      klass << ' enabled'
    else
      klass << ' disabled'
    end
    html << %Q{<li class="#{klass}">}
    if options[:active]
      html << %Q{<span class="tab">#{tab.text}</span>}
    else
      html << %Q{<a href="#{tab.path}" class="tab">#{tab.text}</a>}
    end
    html << '</li>'
    html
  end

  def self.selected?(controller, action, tab_name)
    if @@actions[controller][action].nil? && !@@actions[controller][:all_actions]
      # TODO: better error message or perhaps don't render tabs
      raise "No tab is defined for controller '#{controller}' action '#{action}'"
    end
    (@@actions[controller][action] && @@actions[controller][action].include?(tab_name)) ||
     (@@actions[controller][:all_actions] && @@actions[controller][:all_actions].include?(tab_name))
  end
  
  class Tab
    
    attr_reader :name, :text, :path, :parent
    attr_accessor :subtabs
    
    def initialize(name, text, path, visible, enabled)
      @name = name
      name = name.to_s
      if name.ends_with? '_tab'
        @kind = :tab
      elsif name.ends_with? '_subtab'
        @kind = :subtab
      else
        raise "tab name error"
      end
      @text = text
      @path = path
      @visible = visible
      @enabled = enabled
      @subtabs = []
    end
    
    def add_parent(tab)
      @parent = tab
      @parent.subtabs = @parent.subtabs + [self]
    end
    
    def subtab?
      @kind == :subtab
    end
    
    def visible?(view)
      if @visible.is_a? Proc
        view.instance_eval &@visible
      else
        !!@visible
      end
    end
    
    def enabled?(view)
      if @enabled.is_a? Proc
        view.instance_eval &@enabled
      else
        !!@enabled
      end
    end
    
  end

  module Helpers
    
    def tabs
      Tabulous.render_tabs(self)
    end

    def subtabs
      Tabulous.render_subtabs(self)
    end

  end

end

ActiveSupport.on_load(:action_view) { include Tabulous::Helpers }
