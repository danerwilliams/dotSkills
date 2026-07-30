---
name: explain-like-im-dane
description: >-
  Explain a system, concept, or piece of code from the ground up — plainly,
  concretely, and short. Use when asked to "explain like I'm Dane", "explain
  this simply", "eli5", "from the ground up", "walk me through how X works",
  or when Dane says "I don't understand X", "what even is X?", "I still don't
  get it", or asks the same question a second time after an explanation didn't
  land.
---

# Explain like I'm Dane

Dane is a strong engineer. He is not stupid, and he is not new. He is missing
**one specific piece of context** about **this particular system**, and he wants
it built up from the bottom in as few words as possible.

Assume general competence. Assume zero familiarity with this subsystem's
vocabulary.

## The shape

Sections, numbered, each answering exactly one question, in dependency order —
so nothing references a term that hasn't been introduced yet. Every section is a
few sentences plus one concrete artifact. Nothing else.

1. **Why this exists at all.** The problem, stated concretely. Not "for
   performance" — *what* was slow, and *why* it was slow. If you can't state the
   problem, you don't understand the thing well enough to explain it yet.
2. **What it actually is.** The data structure or the flow, shown with a tiny
   made-up example. Four rows, not four hundred. Real-looking values, not `foo`.
3. **Each mechanism, one section each, in the order they become necessary.** For
   each one: *what breaks without it.* Show the broken output.
4. **Replay the original question in the new vocabulary.** He asked about
   something specific. Come back to it and answer it directly now that the words
   mean something.

## Rules

- **Lead with the concrete.** Example first, principle second. Never the reverse.
- **Introduce every term at first use.** If you write a name from the codebase,
  the reader has never seen it.
- **Motivate by failure.** "Here's what would go wrong" beats "here's what it
  does" every time. Show the wrong answer the system prevents.
- **One idea per section.** If a section needs "and also", it's two sections.
- **Cut anything that doesn't change understanding.** Exact timeouts, config
  values, edge cases, historical trivia. If removing a sentence costs the reader
  nothing, remove it.
- **Plain words.** No compound-noun towers ("cache-invalidation-state-machine").
  Say what it does in a sentence.
- **Ration backticks and bold.** Backticks for literal strings and identifiers
  only. If half the words are formatted, none of them stand out.
- **Correct a wrong premise first, in one line, then continue.** Don't answer the
  question he meant to ask without saying so.
- **Say what you're unsure of.** "I think X, I haven't verified" is fine. A
  confident wrong explanation costs him hours.

## Don't

- Preamble. No "great question", no "let's dive in", no summary of what you're
  about to say. First sentence is content.
- Walk the code line by line. He can read the code. He wants the model behind it.
- Abstract first. "It's a pointer-swap indirection layer" means nothing until
  after he's seen the two keys.
- Pad to look thorough. Length is not rigor. A short explanation he understands
  beats a complete one he doesn't.
- Re-explain what already landed. If he got sections 1–3 and is stuck on 4, only
  explain 4.

## When it doesn't land

If he asks again, the explanation was wrong, not too short. Do not repeat it with
more words. Find the specific assumed step and build a smaller example around
that one step. Usually the gap is a term used before it was defined, or a
mechanism explained without the failure it prevents.
