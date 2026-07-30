module ApplicationHelper
  # The layout's dir attribute hangs off this; everything else mirrors via
  # logical-property Tailwind utilities (ms-*, pe-*, …) — see bin/lint-rtl.
  def rtl?
    I18n.locale.to_s == "ar"
  end
end
