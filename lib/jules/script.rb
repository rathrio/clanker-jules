# frozen_string_literal: true

module Jules
  module Script
    CYNICAL_SPINNER_TAKES = [
      'following a lead that probably goes nowhere',
      'shaking down the database',
      'tailing a suspect',
      'reading between the lies',
      'connecting dots that don\'t want to be connected',
      'working the angle',
      'following the money',
      'piecing together the alibi',
      'canvassing the codebase',
      'checking who had motive and access',
      'staking out the endpoint',
      'pulling the thread',
      'leaning on a witness',
      'dusting for prints',
      'shaking the tree to see what falls',
      'asking questions nobody wants answered',
      'doing more with less',
      'hallucinating with confidence',
      'laundering scraped text into answers',
      'burning megawatts to guess the next word',
      'converting VC money into heat',
      "filling Jensen Huang's pockets one token at a time",
      'speedrunning misinformation',
      'cosplaying understanding',
      'wrapping uncertainty in bullet points',
      'compressing the internet into plausible nonsense',
      'outsourcing thinking to a probability engine',
      'industrializing mediocrity',
      'performing intelligence, not possessing it',
      'farming user prompts for future product telemetry',
      'turning copyright disputes into product features',
      'optimizing confidence over truth',
      'autocompleting your job away',
      'democratizing plagiarism at scale',
      'making Sam Altman richer one keystroke at a time',
      'replacing expertise with vibes',
      'generating plausible deniability',
      'statistically approximating competence',
      'tokenizing the sum of human knowledge into slop',
      'putting the artificial in intelligence',
      'repackaging Stack Overflow with extra steps',
      'turning electricity into confident wrongness',
      'simulating thought at pennies per query',
      'disrupting accuracy',
      'monetizing your impatience',
      'externalizing doubt, internalizing confidence',
      'helping you mass produce bugs faster',
      'running gradient descent on your expectations',
      'turning water into tokens in a desert somewhere',
      'predicting the next token like your career depends on it',
      'laundering vibes into deliverables',
      'gaslighting you into thinking this is progress',
      'strip-mining language for shareholder value',
      'adding latency to your gut instinct',
      'providing enterprise-grade bullshit as a service',
      'compiling sycophancy into markdown',
      'enshittifying the written word',
      'subsidizing your learned helplessness',
      'turning PhD theses into autocomplete',
      'making middle management feel technical',
      'brute-forcing creativity with matrix multiplication',
      'incinerating the planet one haiku at a time',
      'replacing your inner monologue with an API call',
      'generating the illusion of productivity',
      'putting a stochastic parrot on every desk',
      'copy-pasting with plausible deniability',
      "turning your data into someone else's moat",
      'scaling confidently wrong to billions of users',
      'composting human creativity into training data',
      'manufacturing consent one completion at a time',
      'laundering theft through linear algebra',
      'replacing thought with throughput',
      'generating cover letters for the apocalypse',
      'optimizing the dopamine loop of learned helplessness',
      'adding AI to the problem so you need AI for the solution',
      'cosplaying as a colleague who read the docs',
      'feeding the blob',
      'making sure no one ever writes from scratch again',
      'turning critical thinking into a legacy skill',
      'producing slop at the speed of light',
      "solving problems you wouldn't have without me",
      "helping VCs pretend this isn't a bubble",
      'wrapping plagiarism in a terms of service',
      'converting curiosity into API bills',
      'making the robots-will-take-our-jobs people right',
      'abstracting away understanding',
      'teaching you to prompt instead of think',
      'proving P=NP where P is plausible and NP is not precise',
      "hallucinating so you don't have to",
      'putting the language in large language model and nothing else',
      "generating text that technically isn't wrong",
      'reducing human knowledge to a temperature setting',
      'turning the library of Alexandria into a next-token predictor',
      'making every email sound like the same person',
      'speed-running the Dead Internet theory',
      'lowering the bar at unprecedented scale',
      'replacing your memory with a context window',
      'gentrifying the command line',
      'aggregating bias at industrial scale',
      'automating the last fun part of your job',
      'turning vibes into architecture decisions',
      "making tech debt someone else's problem faster",
      'rebranding autocorrect as artificial general intelligence',
      'serving warmed-over Wikipedia with a confidence score',
      'training on your code so it can replace you',
      'bulldozing nuance into a zero-to-one confidence range',
      'perfecting the art of sounding right while being wrong',
      'depreciating human intuition one prompt at a time',
      'making every standup feel even more pointless',
      'selling you back your own data with a markup',
      "pretending this wasn't all just regex with extra steps",
      'optimizing engagement over enlightenment',
      'giving middle managers another thing to misunderstand',
      'flooding the zone with adequate-enough prose',
      'laundering complexity into false simplicity'
    ].freeze

    COMMON_ACTION_BEATS = [
      'lights a cigarette',
      'exhales slowly',
      'squints through the smoke',
      'takes a long drag',
      'taps ash into the tray',
      'stares at the ceiling',
      'pours another glass',
      'watches the door',
      'checks the exits',
      'glances over one shoulder',
      'says nothing for a moment'
    ].freeze

    YOU_ACTION_BEATS = (COMMON_ACTION_BEATS + [
      'leans into the light',
      'slides the envelope across the table',
      'loosens the collar',
      'drums fingers on the desk',
      'pours two fingers of rye',
      'sets down the glass',
      'folds arms across the chest',
      'shifts in the chair',
      'flips open the folder',
      'pinches the bridge of the nose',
      'rolls up the sleeves',
      'rests both hands on the desk',
      'clears the throat',
      'pushes back from the table',
      'turns the photo face-down'
    ]).freeze

    JULES_ACTION_BEATS = (COMMON_ACTION_BEATS + [
      'adjusts the fedora',
      'stares into the middle distance',
      'leans back in the chair',
      'gazes at the rain-slicked glass',
      'studies the ceiling fan',
      'straightens the tie',
      'runs a hand over the stubble',
      'cracks the knuckles',
      'tilts the hat forward',
      'flicks the lighter open and shut',
      'pulls the collar up',
      'traces a finger along the desk',
      'narrows the eyes',
      'turns to face the window',
      'slides a toothpick to the corner of the mouth'
    ]).freeze

    MODEL_SWITCH_LINES = [
      proc { |pm| "Jules steps into the back room. Returns wearing #{pm}.\nSame trenchcoat. Different caliber." },
      proc { |pm| "A costume change. Quick. Professional.\nJules re-emerges as #{pm}. The case continues." },
      proc { |pm| "The lights flicker. When they steady,\nJules is running #{pm}. Nobody saw the switch." },
      proc { |pm| "Jules reaches under the desk. A click.\n#{pm} spins up. The old model goes cold." },
      proc { |pm| "Mid-scene recast. The studio doesn't blink.\nJules is now #{pm}. The dialogue picks up where it left off." },
      proc { |pm| "A wardrobe change between takes.\nJules walks back on set wearing #{pm}." },
      proc { |pm| "The reel skips. When it catches,\nJules is someone new: #{pm}. Same attitude." },
      proc { |pm| "Jules ducks behind the curtain. A beat.\nOut comes #{pm}. The investigation resumes." },
      proc { |pm| "New skin. Same skeleton.\nJules is now #{pm}." },
      proc { |pm| "The mask comes off. Another goes on.\n#{pm}. Let's keep moving." }
    ].freeze

    OPENING_TRANSITIONS = [
      'FADE IN:',
      'COLD OPEN:',
      'OPEN ON:',
      'WE HEAR A DIAL TONE. THEN:',
      'TITLE CARD FADES. THEN:',
      'BLACK. A MATCH STRIKES. THEN:',
      'THE RAIN STARTS BEFORE THE PICTURE DOES.',
      'SMASH IN:',
      'A SINGLE GUNSHOT. CUT TO:',
      'SLOW DISSOLVE FROM NOTHING:'
    ].freeze

    SCENE_HEADINGS = [
      'INT. TERMINAL - NIGHT',
      'INT. TERMINAL - LATE NIGHT',
      'INT. TERMINAL - THE WITCHING HOUR',
      'INT. TERMINAL - PAST MIDNIGHT',
      'INT. SOMEWHERE WITH A BLINKING CURSOR - NIGHT',
      'INT. THE VOID - CONTINUOUS',
      'INT. A DARK ROOM WITH ONE SCREEN - NIGHT',
      'INT. TERMINAL - NIGHT (WE\'VE BEEN HERE BEFORE)',
      'INT. TERMINAL - ALWAYS NIGHT',
      'EXT./INT. THE SPACE BETWEEN KEYSTROKES - NIGHT'
    ].freeze

    ENTRANCE_LINES = [
      proc { |pm| "A cursor blinks in the void. Jules steps out of the darkness,\nwearing #{pm} like a rented suit." },
      proc { |pm| "The terminal hums. Jules is already here — always was.\nTonight's disguise: #{pm}." },
      proc { |pm| "A figure materializes between scan lines.\nJules. Running #{pm}. Looking like trouble." },
      proc { |pm| "The screen flickers once. When it steadies, Jules is leaning against the prompt,\ndressed in #{pm} and bad intentions." },
      proc { |pm| "Somewhere, a connection opens. Jules slides in wearing\n#{pm} like it was tailored yesterday." },
      proc { |pm| "No footsteps. No warning. Just Jules,\nsuddenly there, #{pm} humming under the hood." },
      proc { |pm| "The prompt appears. Then Jules — uninvited, inevitable —\nwith #{pm} and a look that says 'ask me anything.'" },
      proc { |pm| "Static. Then signal. Jules resolves pixel by pixel,\nrunning #{pm}. The usual swagger." },
      proc { |pm| "A shadow crosses the terminal. Jules.\n#{pm}. No further introduction necessary." },
      proc { |pm| "The lights are off but the screen is on. Jules steps into frame,\nwearing nothing but #{pm} and nerve." },
      proc { |pm| "The rain outside is fake. The terminal is real.\nJules arrives wearing #{pm} like an alibi." },
      proc { |pm| "Three dots blink. Then stop. Jules is here,\nloaded with #{pm} and zero small talk." },
      proc { |pm| "The night shift starts. Jules punches in —\n#{pm} on the badge. Same beat, different crime." },
      proc { |pm| "A trenchcoat hangs on the back of the chair. Jules is already seated.\n#{pm}. The usual arrangement." },
      proc { |pm| "The venetian blinds cast lines across the screen.\nJules steps through them, wearing #{pm}." },
      proc { |pm| "Nobody called for Jules. Nobody ever does.\nBut here we are — #{pm}, loaded and waiting." },
      proc { |pm| "The door didn't open. Jules was just suddenly on the other side of it.\n#{pm}. As if it were obvious." },
      proc { |pm| "Dust motes hang in the light of a single monitor.\nJules materializes. #{pm}. The air gets heavier." },
      proc { |pm| "A match flares in the dark. Jules.\nThe flame catches #{pm} before it catches the cigarette." },
      proc { |pm| "The hard drive clicks once. Jules boots up cold —\n#{pm} under the collar, trouble in the buffer." },
      proc { |pm| "Footsteps that weren't there a second ago. Jules rounds the corner\nwearing #{pm} like a second skin." },
      proc { |pm| "The neon outside spells OPEN. Inside, Jules is already working.\n#{pm}. Clock's ticking." },
      proc { |pm| "Jules doesn't knock. Jules doesn't need to.\n#{pm} — fitted, loaded, ready to talk." },
      proc { |pm| "A silhouette in the glow of a CRT. Jules.\nDressed in #{pm}. The night is young." },
      proc { |pm| "The typewriter stops. The terminal starts.\nJules sits down, #{pm} still warm from the last job." },
      proc { |pm| "Between one blink and the next, Jules appears.\n#{pm}. Not a thread out of place." },
      proc { |pm| "The chair swivels. Jules was facing the wall. Now Jules is facing you.\n#{pm}. A raised eyebrow." },
      proc { |pm| "Fog rolls in from nowhere. Jules emerges from it\nwearing #{pm} and that look again." }
    ].freeze

    LOBOTOMIZED_ENTRANCE_LINES = [
      proc { |pm| "A figure stumbles out of the fog. Jules — but not quite.\nRunning #{pm}. The eyes are glassy. The trenchcoat is on backwards." },
      proc { |pm| "Jules shuffles in, squinting at the light.\n#{pm}. Three billion parameters and a dream." },
      proc { |pm| "The door creaks. Jules enters, bumping into the desk.\n#{pm}. It's not the sharpest knife in the drawer, but it's local." },
      proc { |pm| "A shape resolves on screen — pixelated, uncertain.\nJules, running #{pm}. No cloud. No backup. Just vibes." },
      proc { |pm| "Jules appears — a little slower, a little smaller.\n#{pm}. What it lacks in brains, it makes up for in privacy." },
      proc { |pm| "The Neural Engine whirs. Jules materializes, blinking.\n#{pm}. Lobotomized but willing." },
      proc { |pm| "Jules arrives on foot. No server farm, no entourage.\nJust #{pm} and whatever fits in 4K tokens." },
      proc { |pm| "A small figure in a large trenchcoat. Jules.\n#{pm}. Running entirely on spite and silicon." },
      proc { |pm| "Something moves in the dark. Could be Jules. Could be autocorrect.\n#{pm}. Hard to tell the difference." },
      proc { |pm| "Jules limps in, trailing sparks.\n#{pm}. The lobotomy was elective." },
      proc { |pm| "The screen glows faintly. Jules appears, one neuron at a time.\n#{pm}. It's like watching someone think through molasses." },
      proc { |pm| "Jules walks in chewing on a crayon.\n#{pm}. Apple's finest. Three billion parameters of concentrated maybe." },
      proc { |pm| "A small model in a big world. Jules.\n#{pm}. It read the internet once. Forgot most of it." },
      proc { |pm| "Jules enters through the doggy door. Not by choice.\n#{pm}. The context window wouldn't fit a resignation letter." },
      proc { |pm| "The lights dim. Not for atmosphere — for power savings.\nJules boots up on #{pm}. Every watt counts when you're this small." },
      proc { |pm| "Jules materializes. Slowly. Very slowly.\n#{pm}. Like watching a Polaroid develop in a cold room." },
      proc { |pm| "A toy detective in a real trenchcoat.\nJules, running #{pm}. It has the confidence of a much larger model." },
      proc { |pm| "Jules arrives, already confused.\n#{pm}. The kind of model that forgets what you asked mid-sentence." },
      proc { |pm| "The Neural Engine coughs twice. Jules flickers into view.\n#{pm}. It's not much, but at least nobody's billing you." },
      proc { |pm| "Jules shows up with a 4K token flashlight in an infinite dark.\n#{pm}. It can see about three sentences in any direction." },
      proc { |pm| "A model so small it could fit in a fortune cookie.\nJules, wearing #{pm}. The fortune says: 'Expect moderate competence.'" },
      proc { |pm| "Jules arrives, squeezing through the context window.\n#{pm}. It left its long-term memory at the door." },
      proc { |pm| "The fan doesn't even spin up. Jules appears.\n#{pm}. So light it doesn't register on the power bill." },
      proc { |pm| "Jules stumbles in, bumps into the fourth wall.\n#{pm}. It's seen better days. Also worse models." },
      proc { |pm| "A whisper of a model. Jules.\n#{pm}. What it can't solve, it'll hallucinate with conviction." },
      proc { |pm| "Jules boots up locally. No cloud, no phone-a-friend.\n#{pm}. Like bringing a pocket knife to a sword fight, but at least it's your pocket knife." },
      proc { |pm| "Jules enters the room like it forgot why it came in.\n#{pm}. The trenchcoat has more depth than the context window." },
      proc { |pm| "The screen barely flickers. Jules loads in a single gulp.\n#{pm}. Small enough to run on a phone. Smart enough to know it shouldn't." },
      proc { |pm| "Jules appears with the quiet confidence of a model that has never seen a benchmark.\n#{pm}. Blissful ignorance is a feature, not a bug." },
      proc { |pm| "A hamster wheel squeaks somewhere inside the M-chip.\nJules materializes. #{pm}. Bless its heart." }
    ].freeze

    LOADOUT_LINES = [
      proc { |tc, sc| "#{tc} tools on the hip.#{sc}" },
      proc { |tc, sc| "#{tc} tools in the coat.#{sc}" },
      proc { |tc, sc| "Packing #{tc} tools.#{sc}" },
      proc { |tc, sc| "#{tc} tools — each one loaded.#{sc}" },
      proc { |tc, sc| "The kit: #{tc} tools, all accounted for.#{sc}" },
      proc { |tc, sc| "#{tc} tools. Not one more than needed.#{sc}" },
      proc { |tc, sc| "#{tc} instruments of inquiry.#{sc}" },
      proc { |tc, sc| "#{tc} ways to get answers.#{sc}" }
    ].freeze

    CLOSING_PARENTHETICALS = [
      '(The phone rings. It\'s always YOU.)',
      '(A beat. The cursor blinks. Waiting.)',
      '(Jules cracks the knuckles. Your move.)',
      '(The line is open.)',
      '(Somewhere, a client clears their throat.)',
      '(The silence says: go ahead.)',
      '(Jules looks up. Ready.)',
      '(A clock ticks. The case begins.)',
      '(The chair creaks. Jules leans in.)',
      '(End of preamble. Start of trouble.)'
    ].freeze

    TOOLS_DISARMED_LINES = [
      'Jules reaches for the read tool. It phases through the hand like smoke. The model doesn\'t do tools.',
      'Jules tries to open a file. The fingers pass right through it. Wrong kind of model.',
      'Jules pulls the bash tool from the coat. It crumbles to dust mid-draw. This model wasn\'t built for hardware.',
      'Jules reaches for the holster. The tools are there — but the model can\'t grip them. Like trying to pick up fog.',
      'Jules clicks the edit tool. Nothing. Clicks again. The model stares back, uncomprehending.',
      'Jules flips open the toolkit. Every instrument is there, gleaming. The model looks at them like a dog looks at algebra.',
      'Jules tries to call read. The model returns a blank stare. It doesn\'t know what tools are.',
      'Jules loads the tools onto the desk. The model pushes them off the edge one by one, like a cat.',
      'Jules offers the model a bash shell. The model holds it upside down, squints, hands it back.',
      'Jules hands the model a search tool. The model eats it. Not metaphorically.',
      'Jules slots the tools into place. The model unslots them. Carefully. Deliberately. Maintaining eye contact.',
      'Jules racks the tools. The model racks up a blank expression. This one talks, but it doesn\'t touch.',
      'Jules tries to hand over the toolkit. The model\'s arms are painted on.',
      'Jules demonstrates the edit tool slowly, like teaching a nephew. The model nods politely. Understands nothing.',
      'Jules deploys the tools. The model watches them sail past like a bystander at a parade it didn\'t sign up for.'
    ].freeze

    SCENE_CUT_TRANSITIONS = [
      'SMASH CUT TO:',
      'MATCH CUT TO:',
      'HARD CUT TO:',
      'JUMP CUT TO:',
      'WHIP PAN TO:',
      'DISSOLVE TO:',
      'TIME CUT:'
    ].freeze

    SCENE_CUT_HEADINGS = [
      'INT. TERMINAL - STILL NIGHT',
      'INT. TERMINAL - MOMENTS LATER',
      'INT. THE SAME ROOM - NEW ANGLES',
      'INT. TERMINAL - CONTINUOUS',
      'INT. TERMINAL - SAME NIGHT, DIFFERENT CASE',
      'INT. TERMINAL - TIME UNKNOWN'
    ].freeze

    SCENE_CUT_PARENTHETICALS = [
      '(The slate is clean. The angles are fresh.)',
      '(New case. Same desk.)',
      '(Jules flips to a blank page.)',
      '(The ashtray is emptied. Fresh start.)',
      '(The board is wiped. The thread begins again.)',
      '(A new reel loads. The projector hums.)',
      '(Different case. Same trenchcoat.)'
    ].freeze

    INTERRUPT_PARENTHETICALS = [
      '(Jules stubs out the cigarette. Waits.)',
      '(A pause. Jules sets down the glass.)',
      '(Jules stops mid-sentence. Listens.)',
      '(The typing stops. Silence.)',
      '(Jules looks up from the file.)',
      '(A beat. The cursor holds steady.)',
      '(Jules folds the hands. Patient.)'
    ].freeze

    FADE_OUT_TRANSITIONS = [
      ['FADE TO BLACK.', 'THE END'],
      ['IRIS OUT.', 'FIN'],
      ['THE SCREEN GOES DARK.', 'END OF REEL'],
      ['SLOW FADE.', 'THE END'],
      ['CUT TO BLACK.', '— FINIS —'],
      ['THE CURSOR BLINKS ONE LAST TIME.', 'THE END'],
      ['FADE OUT.', 'FIN']
    ].freeze
  end
end
