-- ===========================================================================
-- 0038  Okoli-2026-0001
-- ===========================================================================
--
-- Membership numbers were `YK-` and six random characters. That is a fine
-- identifier and a poor membership number: it says nothing, sorts into no
-- order, and two people comparing theirs learn nothing about either.
--
-- The new shape carries the year somebody joined and how many had joined
-- before them, which is what a membership number is actually for in a
-- community that will still be adding people in fifty years.
--
-- ---------------------------------------------------------------------------
-- WHY THE EXISTING ONES ARE REISSUED
-- ---------------------------------------------------------------------------
--
-- Changing an identifier somebody already holds is normally a bad idea, and it
-- is being done here deliberately and once.
--
-- These numbers are days old, were generated automatically, have never been
-- printed on anything, and nobody has been told theirs — the profile page is
-- the only place any of them appears. Leaving them would give this archive two
-- permanent numbering schemes forever so that three rows could keep a random
-- string none of their owners has read.
--
-- They are ordered by when each person actually joined, so the numbers mean
-- what they claim to.
-- ---------------------------------------------------------------------------

-- D1 has no PL/pgSQL and no sequences, so the running count comes from a
-- window function over the rows themselves, partitioned by the year each
-- person joined.
DROP TABLE IF EXISTS _renumbered_members;
CREATE TABLE _renumbered_members AS
SELECT
  id,
  'Okoli-'
    || strftime('%Y', COALESCE(joined_at, created_at))
    || '-'
    || substr(
         '0000' || CAST(
           ROW_NUMBER() OVER (
             PARTITION BY strftime('%Y', COALESCE(joined_at, created_at))
             ORDER BY COALESCE(joined_at, created_at), id
           ) AS TEXT
         ),
         -4
       ) AS new_number
FROM member_profiles;

UPDATE member_profiles
SET membership_number = (
      SELECT r.new_number FROM _renumbered_members r WHERE r.id = member_profiles.id
    ),
    updated_at = datetime('now')
WHERE EXISTS (SELECT 1 FROM _renumbered_members r WHERE r.id = member_profiles.id);

DROP TABLE _renumbered_members;

-- The lookup the generator makes on every new registration: the highest number
-- issued for a given year.
CREATE INDEX IF NOT EXISTS idx_member_profiles_number
  ON member_profiles (membership_number);
