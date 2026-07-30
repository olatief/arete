# Canonical data for the Kindness · Grade 6 fixture lesson, transcribed from
# docs/mizan-kindness-lesson-en.pdf ("One Lesson, End to End"). This is the one
# fully-worked specimen the whole platform is tested against; db/seeds and the
# test-suite builder both read from here so they can never drift apart.
module KindnessLessonData
  UNIT = {
    grade: 6,
    title: "Kindness",
    position: 2 # "Unit 2: Kindness" in the specimen's breadcrumb
  }.freeze

  # The four lessons of the Kindness unit as listed in the library mockup.
  # Only lesson 3 is fully populated; its siblings are title-only drafts.
  SIBLING_LESSONS = [
    { position: 1, code: "AR-G06-U2-L01", title: "What Kindness Is" },
    { position: 2, code: "AR-G06-U2-L02", title: "Kindness and How We Feel" },
    { position: 4, code: "AR-G06-U2-L04", title: "Kindness That Costs Something" }
  ].freeze

  LESSON = {
    position: 3,
    code: "AR-G06-U2-L03",
    locale: "en",
    title: "Kindness When No One Claps",
    estimated_minutes: 40,
    tags: %w[kindness virtue character],
    prime: <<~PRIME.strip,
      Read this once, slowly, before you stand up. This lesson does not work if you teach it from above the students, as someone who has kindness figured out. It works when you teach it from inside the same struggle they have. So before class, answer the question you are about to ask them: who is the one person it is hard for you to be kind to right now? Hold that person in mind. You will not name them aloud — you will teach honestly because of them.

      Two things to protect. First, do not rescue Slide 5. When you ask "would you still be kind if no one ever knew?", the room may go quiet and uncomfortable. Let it. The discomfort is the lesson; do not fill the silence. Second, keep the handout private. No one reads theirs aloud. The moment it becomes a performance for the class, the honesty leaves the room. Timing is a guide, not a rule — if a real conversation opens, let it run and cut a later slide.
    PRIME
    close_prompt: "Did you do it? One word for how it felt."
  }.freeze

  # Timing lives in suggested_seconds (a Slide column), not in the notes text.
  SLIDES = [
    {
      page_number: 1,
      title: "A quiet start",
      suggested_seconds: 180,
      notes: <<~NOTES.strip
        Settle the room first; lower the lights if you can. Read the prompt slowly, then stop talking. Give a real thirty seconds of silence — count it. Resist explaining. You are teaching them that this subject is worth slowing down for.

        No hands yet — the silence is the point.
      NOTES
    },
    {
      page_number: 2,
      title: "Two words that look alike",
      suggested_seconds: 240,
      notes: <<~NOTES.strip
        Read both. Then a fast example: "A nice person laughs at your joke. A kind person tells you, gently, that you have spinach in your teeth — because they'd rather you be okay than comfortable for ten more seconds." Ask for a quick show of hands: which is easier? (Nice.) Right. Hold that.

        One example — don't over-teach it.
      NOTES
    },
    {
      page_number: 3,
      title: "The lunch table",
      suggested_seconds: 300,
      notes: <<~NOTES.strip
        Read it. Take two or three answers, no more. Listen for the gap: nice feels bad and stays put; kind actually gets up and moves. Say it back plainly: "So nice is a feeling. Kind is a thing you do with your legs." Let that land.

        Surface feeling-versus-action.
      NOTES
    },
    {
      page_number: 4,
      title: "Kindness costs something",
      suggested_seconds: 240,
      notes: <<~NOTES.strip
        Name it directly: "If kindness were free and easy, everyone would already be doing it. The reason it's rare is that it costs. And the cost is exactly what turns a nice feeling into a real kindness." Don't rush — let them feel that kindness is supposed to cost.
      NOTES
    },
    {
      # The heart of the lesson.
      page_number: 5,
      title: "When no one claps",
      suggested_seconds: 180,
      notes: <<~NOTES.strip
        This is the center of the lesson. Read it, then stop. Do not answer your own question. Let the room be quiet and a little uncomfortable — that discomfort is them meeting the real question. Count to ten in your head before you say anything. If someone answers fast and easily, push gently: "Even if you never got to tell anyone?"

        Protect the silence — do not rescue it.
      NOTES
    },
    {
      page_number: 6,
      title: "A quiet experiment",
      suggested_seconds: 180,
      notes: <<~NOTES.strip
        Explain the one rule and why it matters: "The tell no one part is the whole experiment. The second you tell someone, you've traded the kindness for a little bit of credit — and that's fine, but it's a different thing. This week, keep it for yourself and see what's left." Keep it light, not heavy.
      NOTES
    },
    {
      # On the handout.
      page_number: 7,
      title: "One hard person",
      suggested_seconds: 360,
      notes: <<~NOTES.strip
        Hand out the half-sheet now. Say clearly: "This is private. No one reads yours, not even me — unless you want me to." Then give real quiet time: three to four minutes, not thirty seconds. Walk the room slowly; don't hover. Some kids need to see you are not reading over their shoulder.

        Private writing — protect it.
      NOTES
    },
    {
      page_number: 8,
      title: "Where to start",
      suggested_seconds: 180,
      notes: <<~NOTES.strip
        Land it gently; don't preach. "You don't have to feel kind to act kind. The feeling often shows up after, not before. So start with the person it's hard with, do the small thing, and let the feeling catch up." Thank them. Collect the handouts folded, or let them keep them — their choice.

        Close warm — no homework-y tone.
      NOTES
    }
  ].freeze

  ASSETS_DIR = File.expand_path("../assets", __dir__)
  DECK_FILE = File.join(ASSETS_DIR, "kindness-deck-placeholder.pdf")
  HANDOUT_FILE = File.join(ASSETS_DIR, "one-hard-person-handout.pdf")

  def self.slide_image_file(page_number)
    File.join(ASSETS_DIR, "kindness-slide-#{page_number}.png")
  end
end
