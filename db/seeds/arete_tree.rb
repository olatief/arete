# The real Arête K–12 tree, transcribed from docs/arete-k12-curriculum.pdf
# ("Complete Scope & Sequence · 130 Lessons"). One unit per grade, titled with
# that year's formation theme; 10 lessons per grade, titles only, all drafts.
# Idempotent: natural keys are track slug, (track, grade, position) for units,
# (code, locale) for lessons.

ARETE_GRADES = [
  { grade: 0, theme: "Wonder, Safety, and the Gift of Being",
    lessons: [
      "I Am",
      "My Body Is a Gift",
      "Feelings Are Real",
      "Being Kind",
      "Telling the Truth",
      "Sharing",
      "Thank You",
      "We Are Different and the Same",
      "Making Mistakes Is Okay",
      "Who Made the World?"
    ] },
  { grade: 1, theme: "Habits, Feelings, and the Heart as a Mirror",
    lessons: [
      "My Heart",
      "Being Brave",
      "When I'm Angry",
      "Keeping Promises",
      "Friends",
      "Listening",
      "The World Is Beautiful",
      "Being Fair",
      "Helping Without Being Asked",
      "Before I Sleep"
    ] },
  { grade: 2, theme: "Identity, Repair, and the Self as a Story Being Written",
    lessons: [
      "My Name and My Story",
      "Being Patient",
      "Saying Sorry and Meaning It",
      "Why Do We Have Rules?",
      "Leaders Help Others",
      "The Earth Needs Us",
      "What I Love",
      "People Who Inspired Me",
      "Honest When It Is Hard",
      "Who Is the Source?"
    ] },
  { grade: 3, theme: "Inner Life, Habits, and the World as a Book of Signs",
    lessons: [
      "Who Am I Really?",
      "The Voices in My Head",
      "Courage Is Not Fearlessness",
      "Being Fair to Everyone",
      "Habits Make Character",
      "Where Does Knowledge Come From?",
      "What Makes a Good Friend?",
      "Gratitude Changes Everything",
      "Stories That Shape Us",
      "Signs in the World"
    ] },
  { grade: 4, theme: "Authenticity, Responsibility, and What We Actually Worship",
    lessons: [
      "The Self I Show vs. The Self I Am",
      "Peer Pressure: Who Do I Choose to Be?",
      "Patience in Difficulty",
      "What Is Justice?",
      "Being Responsible: The Trust We Carry",
      "Learning from Failure",
      "What Do We Actually Organize Our Lives Around?",
      "The Power of Words",
      "Why Does Evil Exist?",
      "Body and Soul"
    ] },
  { grade: 5, theme: "Values, Desire, Technology, and the Question of Knowledge",
    lessons: [
      "My Identity Map",
      "The Courage to Disagree",
      "Where Do My Values Come From?",
      "Envy and Contentment",
      "What Is a Good Life?",
      "Technology and Me",
      "Justice and Mercy: When They Conflict",
      "The Heart's Condition",
      "What Is Attention For?",
      "Is There an Ultimate Ground?"
    ] },
  { grade: 6, theme: "Transition, the Self's Layers, and Three Ways of Knowing",
    lessons: [
      "Who Am I Becoming?",
      "The Reactive Self and Its Patterns",
      "Digital Identity: Who Am I Online?",
      "What Is 'Cool' — And Who Decided?",
      "Honest With Myself",
      "Do I Believe What I Say I Believe?",
      "Anger and Its Wisdom",
      "The Comparison Trap",
      "What Makes Something Wrong?",
      "Three Ways of Knowing"
    ] },
  { grade: 7, theme: "Desire, Discipline, the Proper Place of Things, and Psychological Health",
    lessons: [
      "The Masks I Wear",
      "Desire and Discipline",
      "My Relationship With My Parents",
      "Popularity and Integrity",
      "What Does It Mean to Be Human?",
      "When the Interior Is in Pain",
      "The Problem of Evil — Deepened",
      "Knowing the Proper Place of Things",
      "Who Should I Walk With?",
      "The Gap Between Who I Say I Am and Who I Am"
    ] },
  { grade: 8, theme: "Self-Knowledge, the Examined Life, and What We Are Actually Organized Around",
    lessons: [
      "Conscience or Inner Critic?",
      "Shame vs. Guilt",
      "Identity, Nature, and the Modern Confusion",
      "The Examined Life",
      "What We Consume Consumes Us",
      "The Fragmented Self",
      "Freedom and Responsibility",
      "What We Are Actually Organized Around",
      "Doubt Without Resources",
      "The Middle School Arc: A Reckoning"
    ] },
  { grade: 9, theme: "Consciousness, the Cosmos, and the Architecture of Desire",
    lessons: [
      "The Floating Man",
      "Original Nature and Its Recovery",
      "What Is a Human Being For?",
      "The Ethics of Attention",
      "Virtue Ethics vs. Rule Ethics",
      "The Social Field as Formation",
      "The Architecture of Desire",
      "Levels of Knowing",
      "The Cosmos as Ongoing Act",
      "Why Be Good When No One Is Watching?"
    ] },
  { grade: 10, theme: "Narrative Identity, Exemplary Character, and the Epistemological Crisis of Modernity",
    lessons: [
      "The Examined Life: Who Have I Been?",
      "Knowledge as Gift vs. Knowledge as Power",
      "The Interior Life as a Science",
      "What Has Modernity Done to Us?",
      "Functional Devotion: The Full Diagnosis",
      "The Exemplary Character",
      "Justice Across Structures",
      "Love and Genuine Relationship",
      "The Intellectual Virtues",
      "Suffering and Trust"
    ] },
  { grade: 11, theme: "Metaphysics, Verified Knowledge, and the Integration of All Knowing",
    lessons: [
      "Formation as a Lifelong Journey",
      "The Human Being as Mirror of the Real",
      "The Meaning Crisis",
      "Verified Knowledge",
      "The Best Objections to What We Believe",
      "The Integration of All Knowing",
      "Character Embodied in Leadership",
      "Love as Cosmological Ground",
      "Character and Culture",
      "The Dissolution of the False Self"
    ] },
  { grade: 12, theme: "Integration, Vocation, and the Return",
    lessons: [
      "Who Have I Become?",
      "The Scholar-Practitioner",
      "Vocation: The Specific Gift",
      "The Good Life: Synthesis",
      "Reality: A Unified Account",
      "The Threshold",
      "My Manifesto",
      "The Long Game",
      "Sending Forward: What I Will Give",
      "Who Made the World? Revisited"
    ] }
].freeze

TRACKS = [
  { slug: "mizan", name: "Mīzān", position: 1 },
  { slug: "arete", name: "Arête", position: 2 },
  { slug: "ihsan", name: "Iḥsān", position: 3 }
].freeze

tracks = TRACKS.to_h do |attrs|
  track = Track.find_or_create_by!(slug: attrs[:slug]) do |t|
    t.name = attrs[:name]
    t.position = attrs[:position]
  end
  [ attrs[:slug], track ]
end

arete = tracks.fetch("arete")

ARETE_GRADES.each do |year|
  unit = Unit.find_or_create_by!(track: arete, grade: year[:grade], position: 1) do |u|
    u.title = year[:theme]
  end

  grade_token = format("G%02d", year[:grade]) # G00 = Kindergarten
  year[:lessons].each_with_index do |title, index|
    Lesson.find_or_create_by!(code: "AR-#{grade_token}-L#{format('%02d', index + 1)}", locale: "en") do |lesson|
      lesson.unit = unit
      lesson.position = index + 1
      lesson.title = title
      lesson.published_at = nil # drafts until authored
    end
  end
end

puts "Seeded Arête tree: #{Track.count} tracks, #{Unit.count} units, #{Lesson.count} lessons"
