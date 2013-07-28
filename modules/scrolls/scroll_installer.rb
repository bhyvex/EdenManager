class ScrollInstaller
  def initialize(s, options = {})
    @scroll = s
    @scroll_file = s.downcase
    @options=options
  end

  def get_scroll
    if File.exists?("./scrolls/#{@scroll}/#{@scroll_file}.rb")
      require "./scrolls/#{@scroll}/#{@scroll_file}"
      klass = Object.const_get(@scroll)
      raise InvalidScrollError if !klass.ancestors.include?(Scroll)
      klass
    else
      Console.show "Can't find the scroll #{@scroll}", 'error'
      raise UnknownScrollError
    end
  end

  def install
    scroll = get_scroll.new
    begin
      scroll.install_dependencies
      scroll.install(@options)
    rescue NoMethodError
      Console.show 'The scroll is invalid, a method is missing.', 'error'
    rescue AlreadyInstalledError
      Console.show "#{@scroll} is already installed", 'info'
    end
  end

  def install_dependency
    scroll = get_scroll.new
    begin
      scroll.install_dependencies
      scroll.install
    rescue NoMethodError
      Console.show 'The scroll is invalid, a method is missing.', 'error'
    rescue AlreadyInstalledError
      Console.show "Dependency #{@scroll} is already installed", 'info'
    end
  end
end