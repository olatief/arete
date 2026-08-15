module ApplicationHelper
  # The layout's dir attribute hangs off this; everything else mirrors via
  # logical-property Tailwind utilities (ms-*, pe-*, …) — see bin/lint-rtl.
  def rtl?
    I18n.locale.to_s == "ar"
  end

  # Companion script register. Notes mix words-to-say with stage directions;
  # the `**…**` convention (UX-SPEC §5.2) renders as accented bold so the two
  # look different at a two-second glance.
  def script_html(notes)
    escaped = ERB::Util.html_escape(notes.to_s)
    marked = escaped.gsub(/\*\*(.+?)\*\*/m) { %(<strong class="stage-direction">#{$1}</strong>) }
    simple_format(marked, {}, sanitize: false)
  end
end
