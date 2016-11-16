require_relative "helpers"

module Jekyll
  class ContentfulGenerator < Generator
    include Helpers

    priority :high # Execute first
    safe true

    # Generates Jekyll::Collections and Documents from the YAML file written by Contentful's Jekyll
    # plugin. Documents are similar to Pages in Jekyll, but work better for data-driven use case,
    # e.g. by automatically parsing Collection-level frontmatter defaults from _config.yml.
    def generate(site)
      # TODO Select space based on environment or build flag
      data = site.data["contentful"]["spaces"]["acc"]

      @sections = {}

      data["section"].each do |attributes|
        find_or_generate_section(site, attributes)
      end

      data["page"].each do |attributes|
        # Pages within a section render within that section, like /:section/:page/
        section = @sections[attributes["section"]["sys"]["id"]] if attributes.key?("section")

        # Pages without a section go in "orphans" and render at the root level, like /:page/. The
        # orphans collection is defined by _config.yml.
        section ||= site.collections["orphans"]

        generate_page(site, section, attributes)
      end

      data["pressRelease"].each do |attributes|
        attributes["date"] = attributes["date"].utc # Undo implicit time zone conversion
        generate_page(site, site.collections["press-releases"], attributes)
      end
    end

    private

    def find_or_generate_section(site, attributes)
      return @sections[attributes["sys"]["id"]] if @sections.key?(attributes["sys"]["id"])

      label = Utils.slugify(attributes["slug"])
      section = Collection.new(site, label)
      section.metadata["output"] = true
      section.metadata["permalink"] = "/#{label}/:slug/" # Child page URL template

      site.collections[label] = section

      if attributes.key?("parentSection")
        parent = find_or_generate_section(site, attributes["parentSection"])

        # Prepend parent path to this section's child page URL template
        section.metadata["permalink"] = parent.metadata["permalink"].sub(":slug", "#{label}/:slug")
      else
        # Add root-level section pages to default collection (defined in _config.yml)
        parent = site.collections["sections"]
      end

      page = generate_page(site, parent, attributes)
      page.data["docs"] = section.docs

      # Inherit section layout from default defined in _config.yml
      unless page.relative_path =~ /^_templates/
        page.data["layout"] = site.frontmatter_defaults.find(page.relative_path, "sections", "layout")
      end

      # Breadcrumbs inherited by child pages (includes parents of this section, if any)
      section.metadata["breadcrumbs"] = page.data["breadcrumbs"]

      @sections[attributes["sys"]["id"]] = section
    end

    def generate_page(site, section, attributes)
      slug = Utils.slugify(attributes["slug"])
      path = section.collection_dir("#{slug}.html")

      doc = Document.new(path, site: site, collection: section)

      # A Page with the same URL as a Section extends the existing section doc
      if existing_doc = section.docs.find { |existing| existing.url == doc.url }
        doc = existing_doc
      else
        doc = match_optional_custom_template(section, doc)
        section.docs << doc
      end

      doc.data["title"] = attributes["title"]
      doc.data["slug"] = slug
      doc.data["date"] = attributes["date"] if attributes.key?("date")
      doc.data["contentful"] = attributes

      # Pass redirects from Contentful to jekyll-redirect-from
      doc.data["redirect_from"] = attributes["redirectFrom"] if attributes["redirectFrom"]

      set_breadcrumbs(doc, section)

      doc
    end

    # If _templates contains a file with the same URL (i.e. path, by default) as the Page, we render
    # that file instead of the default layout.
    def match_optional_custom_template(section, doc)
      templates = section.site.collections["templates"].docs

      if template = templates.find { |template| template.url.sub("/templates", "") == doc.url }
        template.instance_variable_set(:@collection, section)
      end

      template || doc
    end

  end
end
