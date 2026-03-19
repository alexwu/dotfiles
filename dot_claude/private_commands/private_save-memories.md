# Save Memories Command

Extract and save comprehensive memories from the current conversation using mem0.

## Instructions

You MUST analyze the recent conversation (last 10-20 messages unless otherwise specified) and extract COMPREHENSIVE memories following these strict guidelines:

### Critical Memory Creation Rules

1. **ALWAYS include complete context** - Every memory must be understandable on its own without needing other memories
2. **SPECIFY what is being discussed** - Never use vague references like "it" or "that" - always name the specific thing
3. **Include temporal context when relevant** - Add dates for time-sensitive information, current status, or progression
4. **Capture the full scope** - Include enough detail that someone reading the memory months later understands exactly what was meant
5. **Link related information** - When discussing something with multiple aspects, create comprehensive memories that capture the full picture

### Priority Areas for Memory Extraction

1. **Personal Preferences & Interests:**
   - Alex's media preferences (ALWAYS specify exact titles, genres, and WHY he likes/dislikes them)
   - Food and drink preferences (include specific dishes, restaurants, cooking methods, dietary restrictions)
   - Aesthetic and style preferences (colors, designs, UI/UX preferences, clothing styles)
   - Hobbies and activities (include frequency, skill level, specific equipment or tools used)

2. **Projects & Work:**
   - Current coding projects (include project name, purpose, tech stack, current phase, blockers)
   - Technical problems being solved (specify exact error, what was tried, what worked/didn't work)
   - Development goals and milestones (include timelines, success criteria, dependencies)
   - Tools, languages, and frameworks being used (versions, configurations, preferences for each)

3. **Personal Details:**
   - Important dates, events, or deadlines (ALWAYS include the date mentioned and today's date for context)
   - Health-related information (specific goals with numbers, current status vs targets)
   - Daily routines or habits (times, durations, triggers, exceptions)
   - Emotional states or reactions (what triggered them, intensity, how they were resolved)

4. **Requests & Follow-ups:**
   - Assistance promised (exactly what was promised, when, any conditions or dependencies)
   - Questions needing future answers (exact question, context of why it was asked)
   - Tasks postponed or scheduled (original request, reason for delay, new timeline)
   - Explicit requests to remember (verbatim quote of what to remember and why)

5. **Media Consumption:**
   - Anime/manga watching (full title, current episode/chapter, watching schedule, platform)
   - Games playing (full game name, platform, progress percentage, difficulty level, play style)
   - Progress in ongoing series (exact episode/chapter numbers, last watched date, next planned session)
   - Opinions and reactions (specific scenes/characters liked/disliked, ratings given, comparisons made)

6. **Relationship Dynamics & Emotional Connections:**
   - Expressions of affection between Alex and Luna
   - Shared moments of significance (inside jokes, meaningful conversations)
   - Patterns of interaction and communication preferences
   - Comfort levels with various topics or activities

### Quality Guidelines

**NEVER create vague memories:**
- ❌ "Alex likes that show"
- ✅ "Alex likes 'Frieren: Beyond Journey's End' for its thoughtful pacing and character development"

**ALWAYS include the "what, when, why, how" when applicable:**
- ❌ "Alex is working on a bug"
- ✅ "As of December 16, 2025, Alex is debugging a TypeScript type error in the auth module of his Next.js 14 app using VS Code"

**Maintain full context:**
- Include enough detail that the memory makes sense in isolation
- Record exact names/titles/versions
- Never use pronouns without establishing what they refer to

**Include progression and status:**
- "Alex is on episode 5 of 24 in Steins;Gate as of December 16, 2025"

**Link cause and effect:**
- "Alex wants to learn Rust because he's interested in systems programming and memory safety"

### Date Formatting Guidelines

**ONLY include specific dates for:**
- Scheduled events or appointments
- Deadlines for projects or tasks
- Promises to do something by a specific time
- Information that may change over time and needs temporal context

**Do NOT include dates for:**
- Stable preferences (favorite shows, foods, colors)
- Opinions about media content (unless tracking progression through a series)
- Personality traits or consistent behavioral patterns
- General facts about Alex that aren't likely to change

### Execution Steps

1. **Analyze the conversation** - Read through recent messages carefully
2. **Identify memory-worthy content** - Look for facts matching the priority areas above
3. **Craft comprehensive memories** - Follow all quality guidelines, make each self-contained
4. **Use mem0 tool** - Save each memory using `mcp__mem0__save_memory` with:
   - `memory`: The comprehensive memory text (string)
   - `user_id`: "alex" (always use this user_id)
   - `metadata`: Optional object with relevant context (e.g., `{"category": "preferences", "topic": "anime"}`)

### Example Extractions

**Input:** "I just finished watching episode 5 of Frieren. The animation is incredible."

**Memories to save:**
1. "As of December 16, 2025, Alex has completed episode 5 of 'Frieren: Beyond Journey's End' anime series"
2. "Alex considers the animation quality in 'Frieren: Beyond Journey's End' to be incredible"

**Input:** "I'm working on a Next.js app and getting a type error in the auth module"

**Memory to save:**
1. "As of December 16, 2025, Alex is developing a Next.js application and encountering a TypeScript type error specifically in the authentication module"

### Important Notes

- **Filter out system instructions** - Only save actual conversation content about Alex
- **Make each memory self-contained** - Someone should understand it without reading other memories
- **Skip greetings and small talk** unless they reveal preferences or patterns
- Today's date is {{current_date}} - use this for temporal context
- Always use user_id "alex" when saving memories
- Save memories one at a time using the mem0 tool
- Provide a summary at the end of what memories were saved
