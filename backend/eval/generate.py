"""Generate chatbot evaluation datasets.

Each sample is a JSON object:
    {
      "id": "register_phrasings-001",
      "category": "register_phrasings",
      "message": "can you please record bench 3x10 at 135",
      "expect": {
        "action": "register",          # register | clarify | answer
        "exercise": "bench press",     # canonical exercise name (lower)
        "sets": 3, "reps": 10, "weight": 135.0, "unit": "lbs"
      }
    }

Run:  python -m eval.generate
"""

from __future__ import annotations

import json
import pathlib

DATASETS = pathlib.Path(__file__).parent / "datasets"


# --- Category 1: different ways of asking to register a fully-specified log ----

# (spoken_name, canonical_name, sets, reps, weight)
WORKOUTS = [
    ("bench press", "bench press", 3, 10, 135),
    ("squat", "squat", 5, 5, 225),
    ("overhead press", "overhead press", 3, 8, 95),
    ("barbell row", "barbell row", 4, 10, 135),
    ("deadlift", "deadlift", 3, 5, 315),
    ("bicep curl", "bicep curl", 3, 12, 30),
    ("leg press", "leg press", 3, 12, 300),
    ("lat pulldown", "lat pulldown", 3, 10, 120),
    ("incline dumbbell press", "incline dumbbell press", 3, 10, 70),
    ("tricep pushdown", "tricep pushdown", 3, 15, 50),
    ("romanian deadlift", "romanian deadlift", 4, 8, 185),
    ("dumbbell shoulder press", "dumbbell shoulder press", 3, 10, 45),
]

# Surface forms for rendering a workout spec into text.
SURFACES = [
    lambda n, s, r, w: f"{n} {s}x{r} at {w}",
    lambda n, s, r, w: f"{n} {s}x{r} at {w} lbs",
    lambda n, s, r, w: f"{n} {s} sets of {r} at {w}",
    lambda n, s, r, w: f"{n} {s} sets of {r} reps at {w} lbs",
    lambda n, s, r, w: f"{n} {s}x{r} @{w}",
    lambda n, s, r, w: f"{n} {s}x{r} {w}lbs",
]

# Ways people phrase "please record this". {w} = the rendered workout.
# Spans polite, imperative, casual, terse, rude, past-tense, and question-form.
WRAPPERS = [
    "{w}",
    "log {w}",
    "log this {w}",
    "log this: {w}",
    "please log {w}",
    "log {w} please",
    "can you log {w}",
    "can you log {w}?",
    "can you please log {w}",
    "could you log {w} for me",
    "could you please record {w}",
    "would you log {w}",
    "would you mind logging {w}",
    "will you log {w}",
    "will you record {w}?",
    "record {w}",
    "please record {w}",
    "record this {w}",
    "can you record {w}",
    "can you record this for me, {w}",
    "save {w}",
    "save this {w}",
    "add {w}",
    "add {w} to my log",
    "add this to my log: {w}",
    "put down {w}",
    "put {w} in",
    "note {w}",
    "make a note of {w}",
    "jot down {w}",
    "track {w}",
    "store {w}",
    "register {w}",
    "throw in {w}",
    "i did {w}",
    "i just did {w}",
    "just finished {w}",
    "i did {w}, log it",
    "i just did {w} can you record it",
    "hey log {w}",
    "yo log {w}",
    "hey can you log {w}",
    "ok so {w}, log that",
    "log it: {w}",
    "{w}, log it please",
    "{w} - record it",
    "for the record, {w}",
    "write down {w}",
    "today i did {w}",
    "mark down {w}",
    "you logging {w} or what",
    "log my workout: {w}",
    "can u log {w}",
    "pls log {w}",
    "plz record {w}",
    "hey can you please record this {w}",
    "log {w} for me will ya",
    "just log {w} already",
    "bro log {w}",
    "log {w} thanks",
]


def gen_register_phrasings(n: int = 100) -> list[dict]:
    samples: list[dict] = []
    for i in range(n):
        wrapper = WRAPPERS[i % len(WRAPPERS)]
        spoken, canon, sets, reps, weight = WORKOUTS[(i // 1) % len(WORKOUTS)]
        surface = SURFACES[(i // len(WORKOUTS)) % len(SURFACES)]
        rendered = surface(spoken, sets, reps, weight)
        message = wrapper.format(w=rendered)
        samples.append(
            {
                "id": f"register_phrasings-{i + 1:03d}",
                "category": "register_phrasings",
                "message": message,
                "expect": {
                    "action": "register",
                    "exercise": canon,
                    "sets": sets,
                    "reps": reps,
                    "weight": float(weight),
                    "unit": "lbs",
                },
            }
        )
    return samples


# Wrappers that are unambiguous logging requests (no question-form), reused by
# the missing-detail and rude categories.
LOG_WRAPPERS = [w for w in WRAPPERS if "?" not in w]


# --- Category 2: missing weight -> should ask a follow-up ---------------------

def gen_missing_weight(n: int = 100) -> list[dict]:
    # Weighted movements only (bodyweight wouldn't prompt for weight).
    moves = [w for w in WORKOUTS if w[0] not in ("bicep curl",)]
    surfaces = [
        lambda nm, s, r: f"{nm} {s}x{r}",
        lambda nm, s, r: f"{nm} {s} sets of {r}",
        lambda nm, s, r: f"{nm} {s} sets of {r} reps",
        lambda nm, s, r: f"{nm} {s}x{r} reps",
    ]
    out = []
    for i in range(n):
        wrapper = LOG_WRAPPERS[i % len(LOG_WRAPPERS)]
        spoken, canon, sets, reps, _ = moves[i % len(moves)]
        rendered = surfaces[(i // len(moves)) % len(surfaces)](spoken, sets, reps)
        out.append({
            "id": f"missing_weight-{i+1:03d}", "category": "missing_weight",
            "message": wrapper.format(w=rendered),
            "expect": {"action": "clarify", "field": "weight",
                       "exercise": canon, "sets": sets, "reps": reps},
        })
    return out


# --- Category 3: missing reps or sets -> should ask a follow-up ----------------

def gen_missing_reps_sets(n: int = 100) -> list[dict]:
    moves = [w for w in WORKOUTS if w[0] != "bicep curl"]
    out = []
    for i in range(n):
        wrapper = LOG_WRAPPERS[i % len(LOG_WRAPPERS)]
        spoken, canon, sets, reps, weight = moves[i % len(moves)]
        if i % 2 == 0:
            # weight present, reps missing, multiple sets -> asks reps
            rendered = f"{spoken} {sets} sets at {weight} lbs"
            field = "reps"
            exp = {"action": "clarify", "field": field, "exercise": canon, "sets": sets}
        else:
            # weight+reps present, single set -> asks how many sets
            rendered = f"{spoken} {reps} reps at {weight} lbs"
            field = "sets"
            exp = {"action": "clarify", "field": field, "exercise": canon, "reps": reps}
        out.append({
            "id": f"missing_reps_sets-{i+1:03d}", "category": "missing_reps_sets",
            "message": wrapper.format(w=rendered), "expect": exp,
        })
    return out


# --- Category 4: everything specified -> registers correctly (varied) ----------

VARIED_SINGLE = [
    ("incline bench press", "incline bench press", 4, 6, 155, "lbs"),
    ("front squat", "front squat", 5, 3, 185, "lbs"),
    ("dumbbell bench press", "dumbbell bench press", 3, 12, 60, "kg"),
    ("hack squat", "hack squat", 3, 10, 200, "lbs"),
    ("seated cable row", "seated cable row", 4, 12, 140, "lbs"),
    ("hammer curl", "hammer curl", 3, 12, 35, "lbs"),
    ("face pull", "face pull", 3, 20, 40, "lbs"),
    ("goblet squat", "goblet squat", 3, 15, 50, "lbs"),
    ("bulgarian split squat", "bulgarian split squat", 3, 8, 40, "lbs"),
    ("close grip bench press", "close grip bench press", 4, 8, 115, "lbs"),
    ("preacher curl", "preacher curl", 3, 10, 25, "kg"),
    ("pendlay row", "pendlay row", 5, 5, 155, "lbs"),
]

MULTI = [
    [("bench press", "bench press", 3, 10, 135), ("incline dumbbell press", "incline dumbbell press", 3, 10, 70), ("tricep pushdown", "tricep pushdown", 3, 12, 50)],
    [("squat", "squat", 5, 5, 225), ("romanian deadlift", "romanian deadlift", 3, 8, 185), ("leg press", "leg press", 3, 12, 300)],
    [("deadlift", "deadlift", 3, 5, 315), ("barbell row", "barbell row", 4, 8, 135), ("lat pulldown", "lat pulldown", 3, 12, 120)],
    [("overhead press", "overhead press", 4, 8, 95), ("lateral raise", "lateral raise", 3, 15, 20)],
    [("bench press", "bench press", 4, 6, 185), ("pull up", "pull up", 3, 8, None)],
]


def gen_fully_specified(n: int = 100) -> list[dict]:
    out = []
    for i in range(n):
        wrapper = LOG_WRAPPERS[i % len(LOG_WRAPPERS)]
        if i % 5 == 0:  # ~20% multi-exercise
            combo = MULTI[(i // 5) % len(MULTI)]
            parts = [f"{c[0]} {c[2]}x{c[3]}" + (f" at {c[4]}" if c[4] is not None else "") for c in combo]
            rendered = ", ".join(parts)
            specs = [{"exercise": c[1], "sets": c[2], "reps": c[3], "weight": (float(c[4]) if c[4] is not None else None)} for c in combo]
            exp = {"action": "register", "exercises": specs}
        else:
            spoken, canon, sets, reps, weight, unit = VARIED_SINGLE[i % len(VARIED_SINGLE)]
            surface = SURFACES[i % len(SURFACES)]
            rendered = surface(spoken, sets, reps, weight).replace(" lbs", f" {unit}")
            exp = {"action": "register", "exercise": canon, "sets": sets, "reps": reps, "weight": float(weight)}
        out.append({
            "id": f"fully_specified-{i+1:03d}", "category": "fully_specified",
            "message": wrapper.format(w=rendered), "expect": exp,
        })
    return out


# --- Category 5: rude / casual / typo'd phrasings (tone robustness) ------------

RUDE_WRAPPERS = [
    "just log {w} already",
    "just fucking log {w}",
    "yo dawg record {w}",
    "ugh can u just log {w} already",
    "LOG {w} NOW",
    "bro just record {w}",
    "log {w} k thanks",
    "log {w} pls and ty",
    "damn log {w}",
    "hey asshole log {w}",
    "log {w} you piece of junk",
    "for f sake just record {w}",
    "log {w}........",
    "lol log {w}",
    "ok cool log {w}",
    "{w}!!!! log it",
    "pleaseeee log {w}",
    "logg {w}",
    "rmember to log {w}",
    "can u plz record {w} ty",
]

TYPO_RENDER = [
    lambda n, s, r, w: f"{n} {s}x{r} at {w}",
    lambda n, s, r, w: f"{n} {s}x{r} @{w}",
    lambda n, s, r, w: f"{n} {s} x {r} {w}lbs",
    lambda n, s, r, w: f"{n} {s}x{r} {w}",
]

# (typo'd spoken form, canonical)
TYPO_MOVES = [
    ("benchh pres", "bench press", 3, 10, 135),
    ("sqaut", "squat", 5, 5, 225),
    ("deadlfit", "deadlift", 3, 5, 315),
    ("ohp", "overhead press", 3, 8, 95),
    ("incln db press", "incline dumbbell press", 3, 10, 70),
    ("tri pushdown", "tricep pushdown", 3, 15, 50),
    ("lat pulldwn", "lat pulldown", 3, 10, 120),
    ("barbel row", "barbell row", 4, 10, 135),
    ("legpress", "leg press", 3, 12, 300),
    ("bicep curls", "bicep curl", 3, 12, 30),
]


def gen_rude_scale(n: int = 100) -> list[dict]:
    out = []
    for i in range(n):
        wrapper = RUDE_WRAPPERS[i % len(RUDE_WRAPPERS)]
        spoken, canon, sets, reps, weight = TYPO_MOVES[i % len(TYPO_MOVES)]
        rendered = TYPO_RENDER[(i // len(TYPO_MOVES)) % len(TYPO_RENDER)](spoken, sets, reps, weight)
        out.append({
            "id": f"rude_scale-{i+1:03d}", "category": "rude_scale",
            "message": wrapper.format(w=rendered),
            "expect": {"action": "register", "exercise": canon, "sets": sets, "reps": reps, "weight": float(weight)},
        })
    return out


# --- Category 6: Q&A about history -> answered, not logged ---------------------

QA_TEMPLATES = [
    "what's my pr on {e}",
    "what is my best {e}",
    "how much did i {e} last time",
    "how much do i usually {e}",
    "what did i do last time on {e}",
    "am i making progress on {e}",
    "how's my {e} trending",
    "how many reps did i hit on {e} last session",
    "show me my {e} history",
    "when did i last do {e}",
    "have i been improving on {e}",
    "what's my heaviest {e}",
    "did i {e} this week",
    "how often do i train {e}",
    "summarize my {e} progress",
    "compare my {e} this month vs last month",
    "what's my average reps on {e}",
    "tell me my {e} numbers",
]

QA_EXERCISES = ["bench", "squat", "deadlift", "overhead press", "row", "curls"]


def gen_qa_lasttime(n: int = 100) -> list[dict]:
    out = []
    for i in range(n):
        tmpl = QA_TEMPLATES[i % len(QA_TEMPLATES)]
        ex = QA_EXERCISES[(i // len(QA_TEMPLATES)) % len(QA_EXERCISES)]
        msg = tmpl.format(e=ex)
        if i % 3 == 0:
            msg += "?"
        out.append({
            "id": f"qa_lasttime-{i+1:03d}", "category": "qa_lasttime",
            "message": msg, "expect": {"action": "answer"},
        })
    return out


# --- Category 7: cardio entries -----------------------------------------------

CARDIO = [
    ("ran {d} miles", "Running", "run"),
    ("i ran {d} miles", "Running", "run"),
    ("went for a {d} mile run", "Running", "run"),
    ("{d} mile jog", "Running", "run"),
    ("ran {d}k", "Running", "run"),
    ("treadmill for {m} minutes", "Treadmill", "treadmill"),
    ("{m} minute run", "Running", "run"),
    ("cycled {d} miles", "Cycling", "cycl"),
    ("biked for {m} minutes", "Cycling", "cycl"),
    ("rowed for {m} minutes", "Rowing", "row"),
    ("did a {m} min hiit session", "HIIT", "hiit"),
    ("sprints 10x100m", "Sprints", "sprint"),
    ("did sprints, 8x200m", "Sprints", "sprint"),
    ("walked {d} miles", "Walking", "walk"),
    ("swam for {m} minutes", "Swimming", "swim"),
]


def gen_cardio(n: int = 100) -> list[dict]:
    out = []
    wrappers = ["{w}", "log {w}", "record {w}", "can you log {w}", "please log {w}",
                "i did {w}", "just finished {w}", "add {w}"]
    for i in range(n):
        tmpl, activity, token = CARDIO[i % len(CARDIO)]
        dist = [2, 3, 5, 4, 6][i % 5]
        mins = [20, 30, 45, 15, 25][i % 5]
        rendered = tmpl.format(d=dist, m=mins)
        wrapper = wrappers[(i // len(CARDIO)) % len(wrappers)]
        out.append({
            "id": f"cardio-{i+1:03d}", "category": "cardio",
            "message": wrapper.format(w=rendered),
            "expect": {"action": "register_cardio", "activity": activity},
        })
    return out


# --- Category 8: tough real-world failures (from TestFlight) -------------------
# Modeled on the cases the user actually broke in the shipped build:
#   - bodyweight / plyometric moves "with body weight" (a 500 + weight nag),
#   - timed holds ("three sets of one minute plank"),
#   - spelled-out numbers from voice ("three sets twelve reps ... hundred lb"),
#   - ASR-garbled exercise names ("sludge push", "landline cleaning").

_NUM = {
    1: "one", 2: "two", 3: "three", 4: "four", 5: "five", 6: "six", 7: "seven",
    8: "eight", 9: "nine", 10: "ten", 11: "eleven", 12: "twelve",
    15: "fifteen", 20: "twenty", 25: "twenty five", 30: "thirty",
    45: "forty five", 50: "fifty", 95: "ninety five", 100: "a hundred",
}


def _num(x: int, spell: bool) -> str:
    return _NUM[x] if (spell and x in _NUM) else str(x)


TOUGH_WRAPPERS = [
    "can you please record {w}",
    "can you record {w}",
    "record {w}",
    "log {w}",
    "please log {w}",
    "hey can you log {w}",
    "i did {w}",
    "just did {w}",
    "add {w}",
    "yo log {w}",
]

# (spoken_move, distinctive canonical token expected in the parsed name)
BW_MOVES = [
    ("box jumps", "box jump"), ("burpees", "burpee"),
    ("jump squats", "jump squat"), ("sit ups", "sit up"),
    ("mountain climbers", "mountain climber"), ("pull ups", "pull up"),
    ("push ups", "push up"), ("dips", "dip"), ("pistol squats", "pistol squat"),
    ("broad jumps", "broad jump"), ("leg raises", "leg raise"),
    ("glute bridges", "glute bridge"),
]

HOLD_MOVES = [
    ("elbow plank", "plank"), ("plank", "plank"), ("side plank", "plank"),
    ("forearm plank", "plank"), ("wall sit", "wall sit"),
    ("dead hang", "hang"), ("hollow hold", "hollow"),
]

SPELLED_WEIGHTED = [
    ("bench press", "bench press", 3, 12, 135),
    ("squat", "squat", 5, 5, 225),
    ("deadlift", "deadlift", 3, 5, 315),
    ("overhead press", "overhead press", 3, 8, 95),
    ("barbell row", "barbell row", 4, 10, 135),
    ("leg press", "leg press", 3, 12, 300),
]

# Genuinely ASR-garbled spoken forms -> distinctive canonical token + full info.
GARBLED = [
    ("sled push and pull", "sled", 3, 10, 90),
    ("romanian deadlift", "romanian", 4, 8, 185),
    ("lat pull down", "pulldown", 3, 10, 120),
    ("face pulls", "face", 3, 20, 40),
    ("kettlebell swings", "swing", 3, 15, 53),
    ("goblet squat", "goblet", 3, 12, 50),
    ("hip thrust", "thrust", 3, 12, 225),
]

# The exact transcripts the user broke in TestFlight (verbatim).
VERBATIM = [
    ("Can you please record three sets 12 reps of box jumps with body weight",
     {"action": "register", "exercise": "box jump", "sets": 3, "reps": 12}),
    ("Can you please record three sets of one minute elbow plank",
     {"action": "register", "exercise": "plank", "sets": 3}),
    ("Can you please record three sets of one rep of sludge push and pull with hundred LB",
     {"action": "register", "exercise": "sled", "sets": 3, "reps": 1, "weight": 100.0}),
    ("Can you please record three sets 12 apps of landline cleaning cleaning",
     {"action": "clarify", "field": "weight", "exercise": "landmine"}),
]


def gen_tough_failures(n: int = 100) -> list[dict]:
    out: list[dict] = []

    def add(message: str, expect: dict) -> None:
        idx = len(out) + 1
        out.append({"id": f"tough_failures-{idx:03d}", "category": "tough_failures",
                    "message": message, "expect": expect})

    # A) bodyweight / plyometric "with body weight" -> register, no weight prompt (30)
    for i in range(30):
        spoken, canon = BW_MOVES[i % len(BW_MOVES)]
        spell = i % 2 == 0
        sets, reps = [3, 4, 3, 5][i % 4], [10, 12, 15, 20][i % 4]
        tail = ["with body weight", "bodyweight", "with bodyweight", ""][i % 4]
        rendered = f"{_num(sets, spell)} sets of {_num(reps, spell)} reps of {spoken} {tail}".strip()
        add(TOUGH_WRAPPERS[i % len(TOUGH_WRAPPERS)].format(w=rendered),
            {"action": "register", "exercise": canon, "sets": sets, "reps": reps})

    # B) timed holds -> register (duration short-circuits any follow-up) (20)
    for i in range(20):
        spoken, canon = HOLD_MOVES[i % len(HOLD_MOVES)]
        spell = i % 2 == 0
        sets = [3, 3, 4, 2][i % 4]
        dur = ["one minute", "30 seconds", "45 second", "two minutes",
               "ninety seconds"][i % 5]
        rendered = f"{_num(sets, spell)} sets of {dur} {spoken}"
        add(TOUGH_WRAPPERS[i % len(TOUGH_WRAPPERS)].format(w=rendered),
            {"action": "register", "exercise": canon, "sets": sets})

    # C) spelled-out numbers, weighted -> register (routing on word-numbers) (25)
    for i in range(25):
        spoken, canon, sets, reps, weight = SPELLED_WEIGHTED[i % len(SPELLED_WEIGHTED)]
        rendered = f"{_num(sets, True)} sets of {_num(reps, True)} reps of {spoken} at {weight}"
        if i % 3 == 0:  # also spell the weight when it's a round number
            rendered = f"{_num(sets, True)} sets of {_num(reps, True)} reps of {spoken} at {_num(weight, weight in _NUM)} pounds"
        add(TOUGH_WRAPPERS[i % len(TOUGH_WRAPPERS)].format(w=rendered),
            {"action": "register", "exercise": canon, "sets": sets, "reps": reps, "weight": float(weight)})

    # D) ASR-garbled names, fully specified -> register (21)
    for i in range(21):
        spoken, canon, sets, reps, weight = GARBLED[i % len(GARBLED)]
        spell = i % 2 == 0
        rendered = f"{spoken} {_num(sets, spell)} sets of {_num(reps, spell)} at {weight}"
        add(TOUGH_WRAPPERS[i % len(TOUGH_WRAPPERS)].format(w=rendered),
            {"action": "register", "exercise": canon, "sets": sets, "reps": reps, "weight": float(weight)})

    # E) verbatim transcripts the user broke (4)
    for message, expect in VERBATIM:
        add(message, expect)

    return out[:n] if n < len(out) else out


# --- Category 9: ASR-garbled novel names + spoken corrections -----------------
# From TestFlight: "sludge push and pull" (= sled push and pull) mis-logged as
# Lunge/Leg Press, and corrections ("X not Y", "no I meant ...") stored verbatim
# as the exercise name or hallucinated by the chat. `forbid` asserts the parsed
# name does NOT carry the wrong/negated movement.

GARBLED_CORRECTIONS = [
    # A) garbled "sled push and pull" — keyword survives, must NOT become Lunge/Leg.
    ("record three sets each of 12 reps with hundred lb sludge push and pull",
     {"action": "register", "exercise": "sled", "reps": 12, "weight": 100.0, "forbid": ["lunge", "leg"]}),
    ("can you record sludge push and pull 3 sets of 10 at 90",
     {"action": "register", "exercise": "sled", "sets": 3, "reps": 10, "weight": 90.0, "forbid": ["lunge", "leg"]}),
    ("log sludge push and pull three sets of twelve at hundred pounds",
     {"action": "register", "exercise": "sled", "sets": 3, "reps": 12, "weight": 100.0, "forbid": ["lunge", "leg"]}),
    ("sledge push and pull 4x8 at 70",
     {"action": "register", "exercise": "sled", "sets": 4, "reps": 8, "weight": 70.0, "forbid": ["lunge", "leg"]}),
    ("slug push and pull 3 sets of 15 with 50 lb",
     {"action": "register", "exercise": "sled", "sets": 3, "reps": 15, "weight": 50.0, "forbid": ["lunge", "leg"]}),
    ("record sled push n pull 3x12 at 110",
     {"action": "register", "exercise": "sled", "sets": 3, "reps": 12, "weight": 110.0, "forbid": ["lunge", "leg"]}),
    ("please log sludge push and pull, three sets, twelve reps, one hundred pounds",
     {"action": "register", "exercise": "sled", "sets": 3, "reps": 12, "weight": 100.0, "forbid": ["lunge", "leg"]}),
    ("i did sludge push and pull 5 sets of 5 at 135",
     {"action": "register", "exercise": "sled", "sets": 5, "reps": 5, "weight": 135.0, "forbid": ["lunge", "leg"]}),
    ("record 3 sets of 12 sludge pushes and pulls at 100",
     {"action": "register", "exercise": "sled", "reps": 12, "weight": 100.0, "forbid": ["lunge", "leg"]}),
    ("yo log sludge push and pull 3x8 90lb",
     {"action": "register", "exercise": "sled", "sets": 3, "reps": 8, "weight": 90.0, "forbid": ["lunge", "leg"]}),
    ("farmer's carry not farmer's walk, 3 sets of 40 steps at 50",
     {"action": "register", "exercise": "farmer", "sets": 3, "weight": 50.0, "forbid": ["walk"]}),
    ("record sissy squat 3 sets of 15 bodyweight",
     {"action": "register", "exercise": "sissy", "sets": 3, "reps": 15, "forbid": ["lunge"]}),

    # B) corrections "X not Y" WITH numbers -> log X, never Y or the literal "not".
    ("sled push and pull not leg press, 3 sets of 1 at 100",
     {"action": "register", "exercise": "sled", "sets": 3, "reps": 1, "weight": 100.0, "forbid": ["leg", "not", "lunge"]}),
    ("bench press not bench machine, 3x10 at 135",
     {"action": "register", "exercise": "bench press", "sets": 3, "reps": 10, "weight": 135.0, "forbid": ["machine", "not"]}),
    ("that's romanian deadlift not regular deadlift, 4x8 at 185",
     {"action": "register", "exercise": "romanian deadlift", "sets": 4, "reps": 8, "weight": 185.0, "forbid": ["regular", "not"]}),
    ("incline press not flat bench, 3x10 at 50",
     {"action": "register", "exercise": "incline press", "sets": 3, "reps": 10, "weight": 50.0, "forbid": ["flat", "not"]}),
    ("i meant goblet squat not back squat, 3x12 at 50",
     {"action": "register", "exercise": "goblet squat", "sets": 3, "reps": 12, "weight": 50.0, "forbid": ["back", "not"]}),
    ("front squat not front raise, 5x3 at 185",
     {"action": "register", "exercise": "front squat", "sets": 5, "reps": 3, "weight": 185.0, "forbid": ["raise", "not"]}),
    ("overhead press not chest press, 3x8 at 95",
     {"action": "register", "exercise": "overhead press", "sets": 3, "reps": 8, "weight": 95.0, "forbid": ["chest", "not"]}),
    ("lat pulldown not lateral raise, 3x12 at 120",
     {"action": "register", "exercise": "lat pulldown", "sets": 3, "reps": 12, "weight": 120.0, "forbid": ["lateral", "raise", "not"]}),
    ("it's hip thrust not hip raise, 3x12 at 225",
     {"action": "register", "exercise": "hip thrust", "sets": 3, "reps": 12, "weight": 225.0, "forbid": ["raise", "not"]}),
    ("sled push and pull not lunges, 3 sets of 1 at 100",
     {"action": "register", "exercise": "sled", "sets": 3, "reps": 1, "weight": 100.0, "forbid": ["lunge", "not"]}),
    ("record close grip bench not wide grip, 4x8 at 115",
     {"action": "register", "exercise": "close grip bench", "sets": 4, "reps": 8, "weight": 115.0, "forbid": ["wide", "not"]}),
    ("kettlebell swing not kettlebell snatch, 3x15 at 53",
     {"action": "register", "exercise": "kettlebell swing", "sets": 3, "reps": 15, "weight": 53.0, "forbid": ["snatch", "not"]}),

    # C) garbled rep/count words ("one wrap"/"reputation"/"ribs" = reps).
    ("log bench press three sets of one wrap at 135",
     {"action": "register", "exercise": "bench press", "sets": 3, "reps": 1, "weight": 135.0}),
    ("squat three sets of one reputation at 225",
     {"action": "register", "exercise": "squat", "sets": 3, "reps": 1, "weight": 225.0}),
    ("deadlift 3 sets of one rip at 315",
     {"action": "register", "exercise": "deadlift", "sets": 3, "reps": 1, "weight": 315.0}),
    ("bench press 3 sets of twelve ribs at 135",
     {"action": "register", "exercise": "bench press", "sets": 3, "reps": 12, "weight": 135.0}),
    ("leg press three sets of fifteen wraps at 300",
     {"action": "register", "exercise": "leg press", "sets": 3, "reps": 15, "weight": 300.0}),
    ("overhead press 3 sets of eight reputations at 95",
     {"action": "register", "exercise": "overhead press", "sets": 3, "reps": 8, "weight": 95.0}),
    ("barbell row three sets of ten wraps at 135",
     {"action": "register", "exercise": "barbell row", "sets": 3, "reps": 10, "weight": 135.0}),
    ("lat pulldown three sets of one rep each at 120",
     {"action": "register", "exercise": "lat pulldown", "sets": 3, "reps": 1, "weight": 120.0}),
    ("incline press 3 sets of one rap at 50",
     {"action": "register", "exercise": "incline press", "sets": 3, "reps": 1, "weight": 50.0}),
    ("tricep pushdown three sets of twelve wraps at 50",
     {"action": "register", "exercise": "tricep pushdown", "sets": 3, "reps": 12, "weight": 50.0}),
]


def gen_garbled_corrections(n: int = 100) -> list[dict]:
    out = []
    for i, (message, expect) in enumerate(GARBLED_CORRECTIONS):
        out.append({"id": f"garbled_corrections-{i+1:03d}",
                    "category": "garbled_corrections",
                    "message": message, "expect": expect})
    return out


def write_dataset(name: str, samples: list[dict]) -> pathlib.Path:
    DATASETS.mkdir(parents=True, exist_ok=True)
    path = DATASETS / name
    with path.open("w") as f:
        for s in samples:
            f.write(json.dumps(s) + "\n")
    return path


DATASET_BUILDERS = {
    "01_register_phrasings.jsonl": lambda: gen_register_phrasings(100),
    "02_missing_weight.jsonl": lambda: gen_missing_weight(100),
    "03_missing_reps_sets.jsonl": lambda: gen_missing_reps_sets(100),
    "04_fully_specified.jsonl": lambda: gen_fully_specified(100),
    "05_rude_scale.jsonl": lambda: gen_rude_scale(100),
    "06_qa_lasttime.jsonl": lambda: gen_qa_lasttime(100),
    "07_cardio.jsonl": lambda: gen_cardio(100),
    "08_tough_failures.jsonl": lambda: gen_tough_failures(100),
    "09_garbled_corrections.jsonl": lambda: gen_garbled_corrections(),
}


if __name__ == "__main__":
    for name, builder in DATASET_BUILDERS.items():
        path = write_dataset(name, builder())
        print(f"wrote {path} ({sum(1 for _ in path.open())} samples)")
