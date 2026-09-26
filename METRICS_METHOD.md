# How our numbers are counted

Every figure we publish — in a grant application, in the README, on the website
— comes from one of the queries below, and carries the date it was taken. This
file exists so that a reviewer can ask "where does that number come from" and
get an answer that is checkable rather than reassuring.

We do not have analytics. There is no event pipeline, no attribution, no
session tracking, and no way to count "users" in the sense an advertising
dashboard would mean it. What the servers hold is what the service needs to
deliver messages, and that is all we can honestly count. Where a number would
require data we deliberately do not collect, we say so instead of estimating.

---

## What we can count, and what it really means

### Profiles

An account is a keypair. A profile row is created when someone first opens the
app and never opens it again just the same as when they use it daily, and
nothing links two profiles belonging to the same person.

```sql
-- on the key server
SELECT COUNT(*) FROM profiles;
```

**Read it as:** how many times the app has been set up, minus deletions. Not
people. Someone who reinstalls without their recovery kit becomes a second
profile; a household sharing one phone is one.

### Devices active in a window

```sql
-- on the relay, window in days
SELECT COUNT(*) FROM device_activity
 WHERE last_pump_at_ms >= (strftime('%s','now') - :days * 86400) * 1000;
```

`last_pump_at_ms` is written when a device fetches its mailbox. A phone that is
switched off, or has no network, does not appear; a desktop left in the tray
does. `ops/rollout_status.sh` runs this query by build number and is what we use
to decide when a compatibility gate can close.

**Read it as:** devices that talked to the relay in that window. One person with
a phone and two computers counts three.

### Builds in the field

Same table, grouped by `client_build`. The build number arrives in an unsigned
header, so it is good enough for rollout decisions and not good enough to gate
anything security-related — a point the threat model makes as well.

### Store figures

Downloads, installs and active-device counts in App Store Connect and Google
Play Console are theirs, not ours: we can quote them with a date, and anyone
with access can check them. They count differently from the queries above (an
install that never opened the app is a download but never a profile).

---

## What we do not count, and will not

- **Monthly active users.** Doing it properly means recording when a person was
  last seen, per person. We do not have "person" as a concept, and adding one to
  count it would be a worse trade than not publishing the number.
- **Retention, funnels, session length, feature use.** No analytics SDK ships in
  the app; `flutter pub deps` shows it and the Exodus report shows it.
- **Country breakdowns.** IP addresses reach the servers, but we do not keep
  them in a form that supports counting by country, and we are not going to
  start in order to have a nicer slide.
- **Anything about message content, size distributions or who talks to whom**
  beyond what the threat model already admits the relay must see.

---

## Rules we hold ourselves to when quoting a number

1. **A number without a date is not publishable.** Every figure is written as
   "N, on DD MM YYYY".
2. **Name the query.** If a number is not produced by something in this file,
   this file gets updated first.
3. **A count of devices is never called a count of users**, and a count of
   profiles is never called a count of people.
4. **Store numbers stay attributed to the store**, with the console they came
   from.
5. **If a figure is stale, it is replaced or removed** — not quietly carried
   forward. Applications are re-checked on the day they are sent.

---

## Test and code size figures

Line counts in the README come from `wc -l` over tracked files, split by
directory, with generated localisations and vendored third-party code counted
separately. Test counts come from an actual run — `flutter test` and
`cargo test --workspace` — on the day quoted, not from a count of `test(`
occurrences, which over-reports by including parameterised cases that never run.
