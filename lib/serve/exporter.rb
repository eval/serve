require 'pathname'

module Serve
  class Exporter
    def initialize(source_folder, destination_folder, options={})
      @source_folder = source_folder
      @destination_folder = destination_folder
      @static_files = options[:static_files] || ['public/.']
    end

    def ensure_empty_destination_folder
      FileUtils.mkdir_p(@destination_folder) unless File.exist?(@destination_folder)
      Dir["#{@destination_folder}/**/*"].sort.reverse.each{|f| File.directory?(f) ? Dir.rmdir(f) : File.delete(f) }
    end

    def source_files
      @source_files ||= begin
        all_but_templates = Dir["#{@source_folder}/**/[^_]*"]
        supported_extensions = Serve::FileTypeHandler.handlers.keys
        supported_extensions_re = Regexp.new("\.(%s)$" % supported_extensions.join('|'))
        all_but_templates.delete_if{|f| !f[supported_extensions_re] }
      end
    end

    def destination_for(path)
      # TODO refactor
      # views/top/home.html.erb   => output/top/home/index.html
      # views/top/index.html.erb  => output/top/index.html
      # views/index.redirect      => output/index.html
      ##basename = File.basename(path)
      #path = begin
      #  case File.extname(path)
      #  when '.redirect'
      #    path.sub(/.redirect$/, '.html')
      #  else
      #    path.sub(/#{basname.extname}$/, '')
      #  end
      #end

      root_pathname = Pathname.new(@source_folder)
      export_root_pathname = Pathname.new(@destination_folder)
      pathname = Pathname.new(path)

      rel_pathname = pathname.relative_path_from(root_pathname)
      rel_pathname = begin
        case rel_pathname.extname
        when '.redirect'
          Pathname.new(rel_pathname.to_s.sub(/#{rel_pathname.extname}$/, '.html'))
        else
          Pathname.new(rel_pathname.to_s.sub(/#{rel_pathname.extname}$/, ''))
        end
      end
      basename = rel_pathname.basename
      unless basename.to_s == 'index.html'
        rel_pathname = Pathname.new(File.join(rel_pathname.dirname, basename.to_s.split('.').first, 'index.html'))
      end
      export_root_pathname.join(rel_pathname).to_s
    end

    def content_for(path)
      handler_klass = Serve::FileTypeHandler.find(path)
      return nil unless handler_klass

      dest = destination_for(path)
      request, response = Rack::Request.new({}), Rack::Response.new
      handler = handler_klass.new(@source_folder, Pathname.new(path).relative_path_from(Pathname.new(@source_folder)).to_s)
      if handler.respond_to?(:export)
        handler.export(path)
      else 
        handler.process(request, response)
        response.body
      end
    end

    def export_page(path)
      if content = content_for(path)
        dest = destination_for(path)
        FileUtils.mkdir_p(File.dirname(dest))
        File.open(dest, 'w'){|f| f.puts(content) }
      end
    end

    def export_static_files
      FileUtils.cp_r(@static_files, @destination_folder)
    end

    def export
      ensure_empty_destination_folder
     
      source_files.each do |path|
        export_page(path)
      end

      export_static_files

      puts "Done exporting."
    end
  end
end
