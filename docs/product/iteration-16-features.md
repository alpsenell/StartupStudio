# Iteration 16 — seating, the move down, real product names, a city you can touch

*Record of the round. Each lane's report, measurements, deviations,
merge dry-run and screenshots are under `iteration-16-lanes/`. The
seating spec is `iteration-15-pm/meta.md` §3; the other three came from
the owner's message after iteration 15 shipped.*

## How it ran

After iteration 15 went to origin the owner asked for "a new playable
game feature", then added three more in one message: an office
downgrade, more generated product names (the same type kept offering the
same one), and a more detailed, interactive city. Four Opus lanes in
worktrees off `scaffold-16` (= main at c88e04d; no marker scaffold this
round — each lane opened its own `S<n>` pairs), each measuring first,
building, running the five suites on its own simulator and dry-running
the merge against the others. Merged S3 → S2 → S1 → S4 in finishing
order; the only conflicts were the appended `Balance.json` blocks. One
tune at merge: seating's `mentorGainScale` 1.0 → 0.5, on the lane's own
finding that one mentor pair added 46.6 skill points in a quarter
against a target of about 3, so teaching almost always won.

## The four features

**S1 — seating.** A *Desks* row on the office card opens a move mode:
tap a person, then a desk (or someone to swap with), and a pixel panel
lists everything the move starts or stops before the tap. The manage
sheet gets a Desk section with the same preview for players who would
rather not tap small pixels. Once any seat is set, neighbours matter: a
mentor teaches a weaker neighbour weekly and gives up 10% of their own
output; a grumbler costs each neighbour 0.1 morale a day; two friends at
bond 60 grow closer, and are where romances and cliques start; whoever
sits behind the founder gains bond with them weekly; the desk by the
door moves its occupant up the recruiters' list. Build cards and the Now
card print the teaching factor beside K3's lead factor. Before any seat
is set nothing changes: seating is empty on every bot and fixture, and
no draw was added. A seat saved in a bigger office is range-checked
against the current tier, so a downgrade never indexes past the scene.

**S2 — move down.** *Move down* beside the upgrade on the office card,
with the quote on the button: it saves the rent difference every week
and the upkeep of amenities the smaller office cannot hold; an owned
office is sold at today's value first. It costs $2,000 plus two weeks of
the old rent, everyone's morale target −5 for thirteen weeks, reputation
−3, and the boxed amenities' lost bonus (printed as part of the whole
−23 on the studio). Refused with the reason while there are more people
than desks ("Let 6 people go first"), more builds than slots, during an
earn-out, or without the cash. Boxed amenities come back free on the
next upgrade. Measured on the studio: $2,450 a week saved, paid back in
2.3 weeks, $23k ahead by a quarter; average morale 88.7 → 55.6 for the
quarter, 69.5 after.

**S3 — product names.** A new `ProductNames.json` (12 stems per topic,
12 suffixes per type, 80 words, 32 prefixes, 12 tails, nine patterns,
104 real brands never suggested) and a generator seeded from the run's
seed, the product count and the shuffle count, touching no game RNG and
storing nothing. The name step shows three pixel chips and a shuffle
die; a typed name is never overwritten; a taken name is refused inline
("You already have a Round 6", "Ironwood already sells a Kite"); K2's v2
path offers "X 2 / X II / X Next" first. Measured: 1,894 distinct names
over 1,000 shuffles for one type × topic, about 9,600 reachable, zero
collisions against the campus fixture's 62 names in use. Rival studios
still name products the old way because their names are bytes in the
pinned fixtures.

**S4 — the city.** The scene grows from 224×160 to 320×224 with
district character (Old Town brick, Suburbs gardens, Midtown cafés, Tech
Park glass, Downtown towers), a river, a park, traffic that moves with
the clock, richer day, night and season ambience. Everything is a
labelled hit region: your office, your home, each rival's building and
pin, the five networking rooms (tonight's lit, with a crowd), the
hospital, courthouse and school when they apply, and the office you used
to rent. The district panel gains a "who's here" block with a *Visit*
row per room. Hit regions 5 → 18 (22 with every landmark); the warm
compose fell from 7 ms to 0.11 ms because the ground plate is now cached
per hour and season. The pinned map scale and panel clearance still
pass unchanged.

## Suites after the merge

Engine 943, content 52, save 34, PixelKit 336, app `Executed 385 tests,
with 0 failures` on the merged tree. No test added, no re-pin, no engine
fixture moved. Strings catalog synced with one `make strings`.

## Not done, honestly

- Rival product names still come from the old word list (S3); moving
  them means re-pinning the fixtures — the owner's call.
- The mentor's 10% cost skips research output; desk numbers only survive
  the garage → loft upgrade; the engine keeps its own copy of PixelKit's
  desk grid (S1).
- There is no shelve verb, so the downgrade's refusal says "Ship N
  builds first"; no before screenshots (S2).
- The first compose of each hour is about 15 ms (pre-warm the next hour);
  the former office's district is read from the capped event log rather
  than stored; booking a named networking room from the map is a route,
  not an action (S4).

## Debug flags added

S1 `-autoSeating dress|now`, `-autoRoute s1-office|s1-pick|s1-move|s1-desk`;
S2 `-autoRoute s2-downgrade|s2-refused|s2-owned|s2-moved|s2-storage`;
S3 `-autoRoute s3-names|s3-names-shuffle|s3-names-taken|s3-names-v2`;
S4 `-autoCity rich`, `-autoCityDistrict <district>`, `-autoCityFocus
office|home|rival|venue|hospital|courthouse|school|former`.
