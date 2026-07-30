# The canonical fixture: Kindness · Grade 6, "Kindness When No One Claps",
# fully populated from docs/mizan-kindness-lesson-en.pdf and published — the
# only published lesson until real content is authored. The unit holds its
# three sibling lessons as title-only drafts (library mockup, Mockup C).
#
# The source deck PDF isn't available, so a committed placeholder deck
# (right page count, 16:9) is attached for M3's ingest to chew on, and its
# pdftoppm-rendered pages are attached as slide images so M2/M4 render today.

require_relative "data/kindness_lesson_data"

arete = Track.find_by!(slug: "arete")

unit = Unit.find_or_create_by!(
  track: arete,
  grade: KindnessLessonData::UNIT[:grade],
  position: KindnessLessonData::UNIT[:position]
) do |u|
  u.title = KindnessLessonData::UNIT[:title]
end

KindnessLessonData::SIBLING_LESSONS.each do |attrs|
  Lesson.find_or_create_by!(code: attrs[:code], locale: "en") do |lesson|
    lesson.unit = unit
    lesson.position = attrs[:position]
    lesson.title = attrs[:title]
  end
end

lesson = Lesson.find_or_initialize_by(
  code: KindnessLessonData::LESSON[:code],
  locale: KindnessLessonData::LESSON[:locale]
)
lesson.unit = unit
lesson.assign_attributes(KindnessLessonData::LESSON.except(:code, :locale))
lesson.published_at ||= Time.current
lesson.save! if lesson.changed?

KindnessLessonData::SLIDES.each do |attrs|
  slide = Slide.find_or_initialize_by(lesson: lesson, page_number: attrs[:page_number])
  slide.assign_attributes(attrs.except(:page_number))
  slide.save! if slide.changed?

  unless slide.image.attached?
    slide.image.attach(
      io: File.open(KindnessLessonData.slide_image_file(attrs[:page_number])),
      filename: "kindness-slide-#{attrs[:page_number]}.png",
      content_type: "image/png"
    )
  end
end

unless lesson.deck.attached?
  lesson.deck.attach(
    io: File.open(KindnessLessonData::DECK_FILE),
    filename: "kindness-deck-placeholder.pdf",
    content_type: "application/pdf"
  )
end

# Material labels are filenames — the "One Hard Person" half-page handout.
unless lesson.materials.attached?
  lesson.materials.attach(
    io: File.open(KindnessLessonData::HANDOUT_FILE),
    filename: "one-hard-person-handout.pdf",
    content_type: "application/pdf"
  )
end

puts "Seeded fixture lesson #{lesson.code} — #{lesson.title} " \
     "(#{lesson.slides.count} slides, published: #{lesson.published?})"
