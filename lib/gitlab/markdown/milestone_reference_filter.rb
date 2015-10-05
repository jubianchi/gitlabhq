require 'gitlab/markdown'

module Gitlab
  module Markdown
    # HTML filter that replaces milestone references with links. References
    # to milestones that do not exist are ignored.
    #
    # This filter supports cross-project references.
    class MilestoneReferenceFilter < ReferenceFilter
      include CrossProjectReference

      # Public: Find `§123` milestone references in text
      #
      #   MilestoneReferenceFilter.references_in(text) do |match, milestone, project_ref|
      #     "<a href=...>##{milestone}</a>"
      #   end
      #
      # text - String text to search.
      #
      # Yields the String match, the Integer milestone ID, and an optional
      # String of the external project reference.
      #
      # Returns a String replaced with the return of the block.
      def self.references_in(text)
        text.gsub(Milestone.reference_pattern) do |match|
          yield match, $~[:milestone].to_i, $~[:project]
        end
      end

      def call
        replace_text_nodes_matching(Milestone.reference_pattern) do |content|
          milestone_link_filter(content)
        end
      end

      # Replace `§123` milestone references in text with links to the
      # referenced milestone's details page.
      #
      # text - String text to replace references in.
      #
      # Returns a String with `!123` references replaced with links. All links
      # have `gfm` and `gfm-milestone` class names attached for styling.
      def milestone_link_filter(text)
        self.class.references_in(text) do |match, id, project_ref|
          project = self.project_from_ref(project_ref)

          if project && milestone = project.milestones.find_by(iid: id)
            push_result(:milestone, milestone)

            title = escape_once("Milestone: #{milestone.title}")
            klass = reference_class(:milestone)
            data  = data_attribute(project.id)

            url = url_for_milestone(milestone, project)

            %(<a href="#{url}" #{data}
                 title="#{title}"
                 class="#{klass}">#{match}</a>)
          else
            match
          end
        end
      end

      def url_for_milestone(milestone, project)
        h = Gitlab::Application.routes.url_helpers
        h.namespace_project_milestone_url(project.namespace, project, milestone,
                                            only_path: context[:only_path])
      end
    end
  end
end
