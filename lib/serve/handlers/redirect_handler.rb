module Serve #:nodoc:
  class RedirectHandler < FileTypeHandler  #:nodoc:
    extension 'redirect'
    
    def process(request, response)
      url = super.strip
      unless url =~ %r{^\w[\w\d+.-]*:.*}
        url = request.protocol + request.host_with_port + url
      end
      response.redirect(url, '302')
    end

    def export(path)
      return <<-EOF
<script type="text/javascript" language="javascript" charset="utf-8">
//<![CDATA[
  location.href = '#{parse(open(@script_filename){|io| io.read }).strip}'
//]]>
</script>
EOF
    end
  end
end
