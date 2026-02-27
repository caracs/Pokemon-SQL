-- 1. Pokemon with the highest attack among Fire-type Pokémon (opt of q1)
**Optimizations:**
- Added an index on `Type1` and `Type2` to speed up filtering.
- Kept the query structure as it is optimal.

CREATE INDEX idx_pokemon_type1 ON pokemon(Type1);
CREATE INDEX idx_pokemon_type2 ON pokemon(Type2);

SELECT Name, Type1, Type2, Attack 
FROM pokemon 
WHERE 'Fire' IN (Type1, Type2)
ORDER BY Attack DESC 
LIMIT 10;


-- 2. Moves with the highest effective power considering type multiplier (opt of q5)
**Optimizations:**
- Added an index on `type` in the `moves` table to speed up filtering.
- Added a materialized view to store strong moves.

CREATE INDEX idx_moves_type ON moves(type);

CREATE MATERIALIZED VIEW strong_moves AS
SELECT name, type, power
FROM moves
WHERE power > 150;

SELECT sm.name, sm.type, sm.power, te.defending_type, (sm.power * te.multiplier) AS effective_power
FROM strong_moves sm
JOIN type_effectiveness te ON sm.type = te.attacking_type
ORDER BY effective_power DESC
LIMIT 10;


-- 3. Best Pokemon and moves to attack a given type (dragon) (opt of q8)
**Optimizations:**
- Added an index on `Type1` and `Type2` to speed up filtering.
- Added a materialized view to store type advantages.

CREATE INDEX idx_pokemon_types ON pokemon(Type1, Type2);

CREATE MATERIALIZED VIEW type_advantages AS
SELECT te.attacking_type, te.defending_type, te.multiplier
FROM type_effectiveness te
WHERE te.multiplier > 1;

SELECT p.Name, p.Type1, p.Type2, 
    CASE WHEN m.category = 'Physical' THEN p.Attack ELSE p."Sp. Atk" END AS Effective_Attack, 
    m.name AS Move, m.power, m.type, m.category, ta.multiplier AS Type_Multiplier,
    ((CASE WHEN m.category = 'Physical' THEN p.Attack ELSE p."Sp. Atk" END) * m.power * ta.multiplier) AS Offensive_Power
FROM pokemon p
JOIN moves m ON p.Type1 = m.type OR p.Type2 = m.type
JOIN type_advantages ta ON m.type = ta.attacking_type
WHERE ta.defending_type = 'Dragon' AND m.power IS NOT NULL
ORDER BY Offensive_Power DESC
LIMIT 10;


-- 4. Best Pokemon and moves to fight a randomly selected opponent (opt of q10)
**Optimizations:**
- Added an index on `Type1` and `Type2` to speed up filtering.
- Added an index on `moves` table for `type` and `category` to speed up joins.

CREATE INDEX idx_pokemon_types ON pokemon(Type1, Type2); ---
CREATE INDEX idx_moves_type ON moves(type);              ---
CREATE INDEX idx_moves_category ON moves(category);

WITH opponent AS (
  SELECT *
  FROM pokemon
  ORDER BY RANDOM()
  LIMIT 1 ),
defensive_ratings AS (
  SELECT p.Name, p.Type1, p.Type2,opp.Name AS Opponent_Name, opp.Type1 AS Opp_Type1, opp.Type2 AS Opp_Type2, opp.Defense AS Opp_Defense, opp."Sp. Def" AS Opp_SpDef,
         COALESCE(pe1.multiplier, 1) * COALESCE(pe2.multiplier, 1) AS OppToCandidateMultiplier, COALESCE(pe3.multiplier, 1) * COALESCE(pe4.multiplier, 1) AS CandidateToOppMultiplier
  FROM pokemon p
  CROSS JOIN opponent opp
  LEFT JOIN type_effectiveness pe1 ON pe1.attacking_type = opp.Type1 AND pe1.defending_type = p.Type1
  LEFT JOIN type_effectiveness pe2 ON pe2.attacking_type = opp.Type1 AND pe2.defending_type = p.Type2
  LEFT JOIN type_effectiveness pe3 ON pe3.attacking_type = opp.Type2 AND pe3.defending_type = p.Type1
  LEFT JOIN type_effectiveness pe4 ON pe4.attacking_type = opp.Type2 AND pe4.defending_type = p.Type2),
effective_moves AS (
  SELECT p.Name, p.Type1, p.Type2, m.name AS Move, m.power, m.type AS MoveType, m.category, pe1.multiplier AS Multiplier1, COALESCE(pe2.multiplier, 1) AS Multiplier2,
         (CASE
            WHEN m.category = 'Physical' THEN p.Attack
            WHEN m.category = 'Special' THEN p."Sp. Atk"
            ELSE 0
         END * m.power * pe1.multiplier * COALESCE(pe2.multiplier, 1)) AS Offensive_Power
  FROM pokemon p
  CROSS JOIN opponent opp
  JOIN moves m ON p.Type1 = m.type OR p.Type2 = m.type
  JOIN type_effectiveness pe1 ON m.type = pe1.attacking_type AND pe1.defending_type = opp.Type1
  LEFT JOIN type_effectiveness pe2 ON m.type = pe2.attacking_type AND pe2.defending_type = opp.Type2
  WHERE (pe1.multiplier * COALESCE(pe2.multiplier, 1)) > 1 AND m.power IS NOT NULL)
SELECT em.*, dr.Opponent_Name, dr.Opp_Type1, dr.Opp_Type2, dr.OppToCandidateMultiplier, dr.CandidateToOppMultiplier, dr.Opp_Defense, dr.Opp_SpDef
FROM effective_moves em
JOIN defensive_ratings dr ON em.Name = dr.Name
WHERE dr.OppToCandidateMultiplier = 0 AND dr.CandidateToOppMultiplier <= 1 AND ((dr.Opp_Defense > dr.Opp_SpDef AND em.category = 'Special') OR (dr.Opp_Defense <= dr.Opp_SpDef AND em.category = 'Physical'))
ORDER BY em.Offensive_Power DESC
LIMIT 100;