# Builds the canonical Kindness · Grade 6 fixture lesson from the same data
# module the seed uses (db/seeds/data/kindness_lesson_data.rb), so tests and
# seeds can never drift apart. This is the worked specimen later system tests
# (library, lesson page, presenter) run against.
require Rails.root.join("db/seeds/data/kindness_lesson_data")

module KindnessLessonBuilder
  def build_kindness_lesson(attach_files: false)
    track = Track.find_or_create_by!(slug: "arete") do |t|
      t.name = "Arête"
      t.position = 2
    end

    unit = Unit.find_or_create_by!(
      track: track,
      grade: KindnessLessonData::UNIT[:grade],
      position: KindnessLessonData::UNIT[:position]
    ) { |u| u.title = KindnessLessonData::UNIT[:title] }

    lesson = Lesson.create!(
      unit: unit,
      published_at: Time.current,
      **KindnessLessonData::LESSON
    )

    KindnessLessonData::SLIDES.each do |attrs|
      slide = lesson.slides.create!(**attrs)
      next unless attach_files

      slide.image.attach(
        io: File.open(KindnessLessonData.slide_image_file(attrs[:page_number])),
        filename: "kindness-slide-#{attrs[:page_number]}.png",
        content_type: "image/png"
      )
    end

    if attach_files
      lesson.deck.attach(
        io: File.open(KindnessLessonData::DECK_FILE),
        filename: "kindness-deck-placeholder.pdf",
        content_type: "application/pdf"
      )
    end

    lesson
  end
end

ActiveSupport.on_load(:active_support_test_case) do
  include KindnessLessonBuilder
end
