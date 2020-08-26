#!/usr/bin/env ruby
require 'json'
require 'tempfile'

class DSSLayout
  attr_accessor :layout_html,
                :safe_layout_html,
                :safe_inlined_html,
                :final_layout_html,
                :layout_vars

  def initialize(layout_html:)
    @layout_html = layout_html
  end

  def preserve_layout_vars
    @safe_layout_html = @layout_html.dup
    @layout_vars = @layout_html.scan /\${[a-zA-Z0-9_]+}/

    @layout_vars.each do |lvar|
      sanitized_lvar = sanitize(lvar)
      @safe_layout_html.gsub!(lvar, sanitized_lvar)
    end
  end

  def restore_layout_vars
    @final_layout_html = @safe_inlined_html.dup

    @layout_vars.each do |lvar|
      sanitized_lvar = sanitize(lvar)
      @final_layout_html.gsub!(sanitized_lvar, zephrize(sanitized_lvar))
    end
  end

  private

  def zephrize(lv)
    # `'lv-display_prop'` => `{{display-prop}}`
    lv.gsub("'lv-", '{{').chop.gsub('_', '-').concat('}}')  
  end

  def sanitize(lv)
    # `${display_prop}` => `'lv-display_prop'`
    lv.gsub('${', "'lv-").chop.concat("'")
  end
end

abort 'Error: Filename required.' unless ARGV[0]

layout = DSSLayout.new(layout_html: open(ARGV[0]).read)
timestamp = Time.now.to_i.to_s

# Write the safe but un-inlined version to a tempfile
Tempfile.create('trs-plv') do |tmp|
  layout.preserve_layout_vars
  tmp.write layout.safe_layout_html

  `juice #{tmp.path} trs-plv-tmp-#{timestamp}.html`
  layout.safe_inlined_html = open("trs-plv-tmp-#{timestamp}.html").read
end

# Open safe but un-inlined version and re-integrate the layout vars in zephr format
File.open("#{ARGV[0].gsub('.html', '')}-zephrized.html", 'w') do |f|
  layout.restore_layout_vars
  f.puts layout.final_layout_html
end

# Remove tmpfile
File.unlink "trs-plv-tmp-#{timestamp}.html"

# Write layout variable manifest
File.write('layout-vars.json', layout.layout_vars.to_json)