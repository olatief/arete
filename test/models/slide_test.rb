require "test_helper"

class SlideTest < ActiveSupport::TestCase
  setup do
    @lesson = build_kindness_lesson
  end

  test "lesson_id+page_number uniqueness is enforced by the database" do
    dup = Slide.new(lesson: @lesson, page_number: 1)
    assert_raises(ActiveRecord::RecordNotUnique) { dup.save!(validate: false) }
  end

  test "page_number must be a positive integer" do
    assert_not Slide.new(lesson: @lesson, page_number: 0).valid?
    assert_not Slide.new(lesson: @lesson, page_number: nil).valid?
  end

  test "suggested_seconds must be a positive integer when present" do
    assert Slide.new(lesson: @lesson, page_number: 9, suggested_seconds: nil).valid?
    assert Slide.new(lesson: @lesson, page_number: 9, suggested_seconds: 180).valid?
    assert_not Slide.new(lesson: @lesson, page_number: 9, suggested_seconds: 0).valid?
    assert_not Slide.new(lesson: @lesson, page_number: 9, suggested_seconds: 2.5).valid?
  end

  test "the fixture slides carry titles and pacing targets" do
    slide = @lesson.slides.find_by!(page_number: 5)
    assert_equal "When no one claps", slide.title
    assert_equal 180, slide.suggested_seconds
  end
end
