require "test_helper"

class LessonTest < ActiveSupport::TestCase
  setup do
    @lesson = build_kindness_lesson
  end

  test "code+locale uniqueness is enforced by the database, not just validations" do
    dup = Lesson.new(
      unit: @lesson.unit, position: 99, code: @lesson.code, locale: @lesson.locale,
      title: "Duplicate"
    )
    assert_raises(ActiveRecord::RecordNotUnique) { dup.save!(validate: false) }
  end

  test "a sibling row with the same code and the other locale is the i18n model" do
    arabic = Lesson.create!(
      unit: @lesson.unit, position: @lesson.position, code: @lesson.code,
      locale: "ar", title: "اللطف حين لا يصفق أحد"
    )
    assert arabic.persisted?
  end

  test "locale must be en or ar" do
    @lesson.locale = "fr"
    assert_not @lesson.valid?
  end

  test "published scope returns only lessons with published_at set" do
    draft = Lesson.create!(unit: @lesson.unit, position: 98, code: "AR-TEST-DRAFT", title: "Draft")
    assert_includes Lesson.published, @lesson
    assert_not_includes Lesson.published, draft
    assert_not draft.published?
  end

  test "tags default to an empty array" do
    lesson = Lesson.create!(unit: @lesson.unit, position: 97, code: "AR-TEST-TAGS", title: "Tagless")
    assert_equal [], lesson.reload.tags
  end

  test "search finds the kindness fixture" do
    assert_includes Lesson.search("kindness"), @lesson
    assert_includes Lesson.search("no one claps"), @lesson
    assert_empty Lesson.search("photosynthesis")
  end

  test "slides come back ordered by page_number" do
    assert_equal (1..8).to_a, @lesson.slides.map(&:page_number)
  end
end
