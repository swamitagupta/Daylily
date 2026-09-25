import Foundation

/// Picks an icon for an item from the name the user typed.
///
/// Deliberately a lookup table rather than a model: the answer has to be the
/// same on every device and every launch, it has to work with no network and no
/// hardware requirement, and it has to be a member of `IconCatalog` so the
/// editor never selects an icon its own grid cannot offer. A generated
/// suggestion could not promise any of those.
///
/// Stems are matched against whole words, not substrings, so "running shoes"
/// reaches Run without "sho" reaching Shopping. Irregular forms ("run" against
/// "running") are listed explicitly, which keeps the rule short enough to
/// predict by reading it.
enum IconSuggestion {
    /// The symbol each stem group belongs to, in catalog order. Order decides
    /// ties, so equal-scoring names resolve the same way every time.
    private static let activityStems: [(symbol: String, stems: [String])] = [
        ("building.2.fill", ["office", "desk", "meeting", "meetings", "client", "clients", "corporate", "cubicle"]),
        ("tennis.racket", ["tennis", "racket", "racquet", "padel", "squash", "badminton"]),
        ("figure.walk", ["walk", "walks", "walking", "stroll", "strolling", "steps", "wander"]),
        ("figure.run", ["run", "runs", "running", "jog", "jogging", "sprint", "sprinting", "cardio"]),
        ("figure.mind.and.body", ["meditate", "meditation", "meditating", "mindful", "mindfulness", "breath", "breathing", "breathe", "zen"]),
        ("bicycle", ["cycle", "cycling", "bike", "biking", "bicycle", "spinning"]),
        ("figure.strengthtraining.traditional", ["workout", "workouts", "gym", "lift", "lifting", "weights", "weight", "strength", "strengthtraining", "crossfit", "calisthenics"]),
        ("figure.pool.swim", ["swim", "swimming", "swam", "pool", "laps"]),
        ("figure.yoga", ["yoga", "stretch", "stretching", "pilates", "mobility"]),
        ("mountain.2.fill", ["hike", "hikes", "hiking", "trail", "trails", "mountain", "mountains", "trek", "trekking"]),
        ("books.vertical.fill", ["read", "reading", "book", "books", "novel", "novels", "kindle"]),
        ("pencil.line", ["write", "writes", "writing", "wrote", "journal", "journaling", "diary", "essay", "essays", "blog", "blogging", "draft", "drafting", "poem", "poetry"]),
        ("laptopcomputer", ["work", "working", "laptop", "computer", "code", "coding", "programming", "email", "emails", "project", "projects", "deadline"]),
        ("graduationcap.fill", ["learn", "learning", "study", "studying", "studied", "course", "courses", "class", "classes", "school", "university", "lesson", "lessons", "language", "exam"]),
        ("cup.and.saucer.fill", ["coffee", "espresso", "latte", "cappuccino", "cafe", "caffeine", "tea"]),
        ("frying.pan.fill", ["cook", "cooks", "cooking", "cooked", "meal", "meals", "dinner", "lunch", "breakfast", "recipe", "recipes", "baking", "bake", "baked", "kitchen", "mealprep"]),
        ("fork.knife", ["eat", "eats", "eating", "ate", "food", "nutrition", "diet", "healthy", "vegetables", "veggies", "protein", "fork", "knife"]),
        ("drop.fill", ["water", "hydrate", "hydration", "hydrating", "drink", "drinking", "drank", "fluids"]),
        ("paintpalette.fill", ["create", "creates", "creating", "creative", "creativity", "art", "arts", "paint", "painting", "draw", "drawing", "design", "designing", "craft", "crafting", "diy"]),
        ("music.note", ["music", "song", "songs", "sing", "singing", "sang", "guitar", "piano", "band", "instrument", "concert"]),
        ("sparkles", ["clean", "cleans", "cleaning", "cleaned", "tidy", "chores", "laundry", "dishes", "vacuum", "vacuuming", "declutter", "organise", "organize", "organising", "organizing"]),
        ("bed.double.fill", ["sleep", "sleeps", "sleeping", "slept", "nap", "naps", "napping", "bed", "bedtime", "insomnia", "night"]),
        ("leaf.fill", ["nature", "tree", "trees", "garden", "gardening", "forest", "park", "plant", "plants"]),
        ("sun.max.fill", ["outside", "outdoors", "outdoor", "sun", "sunlight", "sunshine", "daylight", "air"]),
        ("person.2.fill", ["friend", "friends", "social", "socialising", "socializing", "hangout", "hangouts", "party", "people", "community"]),
        ("house.fill", ["family", "home", "kids", "children", "parents", "parent", "partner", "spouse", "household", "housemates"]),
        ("pawprint.fill", ["pet", "pets", "dog", "dogs", "cat", "cats", "puppy", "kitten", "vet", "animal", "animals"]),
        ("airplane", ["travel", "traveling", "travelling", "trip", "trips", "flight", "flying", "airport", "vacation", "holiday", "abroad", "plane"]),
        ("car.fill", ["drive", "drives", "driving", "drove", "car", "commute", "commuting", "taxi", "uber", "traffic"]),
        ("gamecontroller.fill", ["game", "games", "gaming", "gamed", "videogames", "console", "playstation", "xbox", "puzzle", "puzzles"]),
        ("bag.fill", ["shopping", "shop", "shops", "groceries", "grocery", "store", "buy", "buying", "errands"]),
        ("iphone", ["phone", "phones", "call", "calls", "calling", "called", "iphone", "scroll", "scrolling", "texting", "texts"]),
        ("bubble.left.fill", ["talk", "talks", "talking", "talked", "chat", "chatting", "conversation", "conversations", "therapy", "therapist", "counselling", "counseling", "catchup"]),
        ("cross.case.fill", ["medicine", "medication", "medications", "meds", "pill", "pills", "supplement", "supplements", "vitamin", "vitamins", "prescription", "antibiotic"]),
        ("heart.fill", ["self", "selfcare", "care", "skincare", "bath", "massage", "pamper", "kindness", "boundaries", "treat"]),
        ("moon.fill", ["rest", "rests", "resting", "relax", "relaxing", "relaxation", "downtime", "break", "breaks", "quiet"])
    ]

    private static let outcomeStems: [(symbol: String, stems: [String])] = [
        ("face.smiling.fill", ["happy", "happi", "happier", "happiness", "joy", "joyful", "joyous", "glad", "cheer", "cheerful", "smile", "smiling", "upbeat", "delighted"]),
        ("wind", ["calm", "calmer", "calmness", "relaxed", "relaxing", "serene", "settled", "steady", "tranquil"]),
        ("bolt.fill", ["energy", "energies", "energized", "energised", "energetic", "vitality", "alert", "vibrant", "wired"]),
        ("leaf.fill", ["peace", "peaceful", "harmony", "grounded", "ease", "gentle", "still"]),
        ("heart.fill", ["loved", "love", "loving", "adored", "affection", "cherished", "valued"]),
        ("person.2.fill", ["connected", "connection", "connectedness", "belonging", "together", "seen", "close"]),
        ("star.fill", ["confident", "confidence", "capable", "assured", "bold", "proud"]),
        ("flame.fill", ["motivated", "motivation", "driven", "determined", "ambitious", "inspired"]),
        ("scope", ["focused", "focus", "sharp", "clear", "productive", "attentive"]),
        ("paintbrush.pointed.fill", ["creative", "creativity", "imaginative", "artistic", "inventive"]),
        ("hands.sparkles.fill", ["grateful", "gratitude", "thankful", "blessed", "appreciative"]),
        ("sun.max.fill", ["hopeful", "hope", "optimistic", "encouraged"]),
        ("moon.stars.fill", ["rested", "restful", "refreshed", "recharged", "recovered", "restored"]),
        ("bed.double.fill", ["sleepy", "sleepiness", "tired", "drowsy", "exhausted", "fatigued", "weary"]),
        ("waveform.path", ["anxious", "anxiety", "nervous", "worry", "worried", "worrying", "panic", "uneasy", "tense", "edge"]),
        ("cloud.rain.fill", ["sad", "sadness", "down", "low", "blue", "tearful", "miserable", "unhappy", "heavy", "gloomy"]),
        ("exclamationmark.circle.fill", ["stressed", "stress", "overwhelmed", "pressure", "swamped", "burnout", "burned", "frantic", "rushed"]),
        ("bolt.heart.fill", ["angry", "anger", "frustrated", "frustration", "irritated", "irritable", "annoyed", "furious", "mad", "resentful"]),
        ("brain.head.profile", ["thoughtful", "thinking", "think", "reflective", "contemplative", "pensive", "curious", "ruminating"]),
        ("questionmark.circle.fill", ["uncertain", "uncertainty", "unsure", "doubt", "doubts", "confused", "ambivalent", "torn"]),
        ("circle.lefthalf.filled", ["balanced", "balance", "even", "centered", "centred", "stable", "moderate"]),
        ("tree.fill", ["growing", "growth", "progress", "progressing", "improving", "developing", "evolving", "thriving"]),
        ("sparkles", ["bright", "brightness", "light", "radiant", "sunny", "lively", "vivacious"]),
        ("checkmark.seal.fill", ["good", "great", "fine", "well", "solid", "positive", "okay", "content"])
    ]

    /// A symbol from the catalog, or `nil` when the name says nothing about what
    /// the item is. Callers keep whatever they were showing in that case.
    ///
    /// An exact word is the strongest signal, so it decides first; between two
    /// exact words the earlier one wins, because names lead with the activity
    /// and qualify it afterwards ("Walk to the shops", "Run in the park").
    /// Ranking on length instead would file the first of those under Shopping,
    /// and ranking on position alone would file "Play Tennis" under Games, from
    /// the "play" in "playstation". Equal ranks keep catalog order.
    static func symbol(for name: String, kind: IconCatalog.Kind) -> String? {
        var best: (symbol: String, match: Match)?
        for (position, word) in tokens(in: name).enumerated() {
            for entry in table(for: kind) {
                for stem in entry.stems {
                    guard let match = match(word: word, stem: stem, position: position) else { continue }
                    if let incumbent = best?.match, !match.beats(incumbent) { continue }
                    best = (entry.symbol, match)
                }
            }
        }
        return best?.symbol
    }

    /// How well one word matched one stem, ordered by `beats`.
    private struct Match {
        let exact: Bool
        let position: Int
        let length: Int

        func beats(_ other: Match) -> Bool {
            if exact != other.exact { return exact }
            if position != other.position { return position < other.position }
            return length > other.length
        }
    }

    private static func table(for kind: IconCatalog.Kind) -> [(symbol: String, stems: [String])] {
        kind == .activity ? activityStems : outcomeStems
    }

    /// Whole words only: case, accents and punctuation are folded away so
    /// "Morning Walk!", "walk" and "WALK" all reach the same stem, while
    /// "walking" still counts as one word rather than matching anything
    /// containing "walk".
    private static func tokens(in name: String) -> [String] {
        let folded = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let separated = String(folded.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " })
        return separated.split(separator: " ").map(String.init).filter { !$0.isEmpty }
    }

    /// Four characters is the floor for a prefix match, so "run" cannot be
    /// swallowed by "running" or the other way round — those pairs are listed
    /// explicitly in the table instead.
    private static func match(word: String, stem: String, position: Int) -> Match? {
        if word == stem { return Match(exact: true, position: position, length: stem.count) }
        if stem.count >= 4, word.hasPrefix(stem) {
            return Match(exact: false, position: position, length: min(word.count, stem.count))
        }
        if word.count >= 4, stem.hasPrefix(word) {
            return Match(exact: false, position: position, length: min(word.count, stem.count))
        }
        return nil
    }
}
