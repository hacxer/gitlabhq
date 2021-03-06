module CommitsHelper
  # Returns a link to the commit author. If the author has a matching user and
  # is a member of the current @project it will link to the team member page.
  # Otherwise it will link to the author email as specified in the commit.
  #
  # options:
  #  avatar: true will prepend the avatar image
  #  size:   size of the avatar image in px
  def commit_author_link(commit, options = {})
    commit_person_link(commit, options.merge(source: :author))
  end

  # Just like #author_link but for the committer.
  def commit_committer_link(commit, options = {})
    commit_person_link(commit, options.merge(source: :committer))
  end

  def each_diff_line(diff, index)
    Gitlab::DiffParser.new(diff).each do |full_line, type, line_code, line_new, line_old|
      yield(full_line, type, line_code, line_new, line_old)
    end
  end

  def each_diff_line_near(diff, index, expected_line_code)
    max_number_of_lines = 16

    prev_match_line = nil
    prev_lines = []

    each_diff_line(diff, index) do |full_line, type, line_code, line_new, line_old|
      line = [full_line, type, line_code, line_new, line_old]
      if line_code != expected_line_code
        if type == "match"
          prev_lines.clear
          prev_match_line = line
        else
          prev_lines.push(line)
          prev_lines.shift if prev_lines.length >= max_number_of_lines
        end
      else
        yield(prev_match_line) if !prev_match_line.nil?
        prev_lines.each { |ln| yield(ln) }
        yield(line)
        break
      end
    end
  end

  def image_diff_class(diff)
    if diff.deleted_file
      "deleted"
    elsif diff.new_file
      "added"
    else
      nil
    end
  end

  def commit_to_html(commit, project, inline = true)
    template = inline ? "inline_commit" : "commit"
    escape_javascript(render "projects/commits/#{template}", commit: commit, project: project) unless commit.nil?
  end

  def diff_line_content(line)
    if line.blank?
      " &nbsp;"
    else
      line
    end
  end

  # Breadcrumb links for a Project and, if applicable, a tree path
  def commits_breadcrumbs
    return unless @project && @ref

    # Add the root project link and the arrow icon
    crumbs = content_tag(:li) do
      content_tag(:span, nil, class: 'arrow') +
      link_to(@project.name, project_commits_path(@project, @ref))
    end

    if @path
      parts = @path.split('/')

      parts.each_with_index do |part, i|
        crumbs += content_tag(:span, ' / ', class: 'divider')
        crumbs += content_tag(:li) do
          # The text is just the individual part, but the link needs all the parts before it
          link_to part, project_commits_path(@project, tree_join(@ref, parts[0..i].join('/')))
        end
      end
    end

    crumbs.html_safe
  end

  protected

  # Private: Returns a link to a person. If the person has a matching user and
  # is a member of the current @project it will link to the team member page.
  # Otherwise it will link to the person email as specified in the commit.
  #
  # options:
  #  source: one of :author or :committer
  #  avatar: true will prepend the avatar image
  #  size:   size of the avatar image in px
  def commit_person_link(commit, options = {})
    source_name = commit.send "#{options[:source]}_name".to_sym
    source_email = commit.send "#{options[:source]}_email".to_sym
    text = if options[:avatar]
            avatar = image_tag(avatar_icon(source_email, options[:size]), class: "avatar #{"s#{options[:size]}" if options[:size]}", width: options[:size], alt: "")
            %Q{#{avatar} <span class="commit-#{options[:source]}-name">#{source_name}</span>}
          else
            source_name
          end

    user = User.where('name like ? or email like ?', source_name, source_email).first

    options = {
      class: "commit-#{options[:source]}-link has_tooltip",
      data: { :'original-title' => sanitize(source_email) }
    }

    if user.nil?
      mail_to(source_email, text.html_safe, options)
    else
      link_to(text.html_safe, user_path(user), options)
    end
  end
end
