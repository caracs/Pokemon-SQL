-- 1. pokemon con miglior attacco tra quelli di tipo fuoco
SELECT Name, Type1, Type2, Attack 
FROM pokemon 
WHERE Type1 = 'Fire' OR Type2 = 'Fire'
ORDER BY Attack DESC 
LIMIT 10;

-- 2. pokemon con miglior attacco tra quelli di tipo fuoco o acqua e con nome che inizia per 'C_a'
SELECT Name, Type1, Type2, Attack 
FROM pokemon 
WHERE (Type1 IN ('Fire', 'Water') OR Type2 IN ('Fire', 'Water')) and name like 'C_a%'
ORDER BY Attack DESC 
LIMIT 10;

-- 3. pokemon con miglior somma di attacco e attacco speciale tra quelli che hanno un solo tipo
SELECT Name, Type1, Type2, Attack, "Sp. Atk", (Attack + "Sp. Atk") AS Total_Attack
FROM pokemon
where Type2 is null
ORDER BY Total_Attack DESC
LIMIT 10;

-- 4. miglior Pokémon per ogni tipo (sia monotipo che bitipo)
WITH RankedPokemons AS (
    SELECT p.Name, p.Type1, p.Type2, p.Total, p.Speed,
           ROW_NUMBER() OVER (
               PARTITION BY p.Type1, COALESCE(p.Type2, '') 
               ORDER BY p.Total DESC, p.Speed DESC
           ) AS rank
    FROM pokemon p)
SELECT Name, Type1, Type2, Total
FROM RankedPokemons
WHERE rank = 1
ORDER BY Type1, Type2 NULLS FIRST;

-- 5. mosse con il danno effettivo maggiore considerando il moltplicatore di tipo
SELECT m.name, m.type, m.power, te.defending_type, (m.power * te.multiplier) AS effective_power
FROM moves m
JOIN type_effectiveness te ON m.type = te.attacking_type
WHERE m.power IS NOT NULL
ORDER BY effective_power DESC
LIMIT 10;

-- 6. pokemon migliori in difesa (considerando "tankscore" e n.di debolezze)
SELECT p.Name, p.Type1, p.Type2, HP, Defense, "Sp. Def", (HP + Defense + "Sp. Def") AS TankScore,
  (SELECT COUNT(*)
   FROM (
      SELECT te.attacking_type, (teA.multiplier * COALESCE(teB.multiplier, 1)) AS combined_multiplier
      FROM (SELECT DISTINCT attacking_type FROM type_effectiveness) AS te
      JOIN type_effectiveness teA  ON teA.attacking_type = te.attacking_type AND teA.defending_type = p.Type1
      LEFT JOIN type_effectiveness teB ON (p.Type2 IS NOT NULL  AND teB.attacking_type = te.attacking_type AND teB.defending_type = p.Type2)
    ) AS combined
    WHERE combined.combined_multiplier > 1
  ) AS WeaknessCounter
FROM pokemon p
ORDER BY TankScore DESC
LIMIT 10;

-- 7. classifica dei tipi in base alla somma dei moltiplicatori
WITH distinct_combos AS (
  SELECT DISTINCT
    CASE 
      WHEN Type2 IS NULL OR Type1 < Type2 THEN Type1 
      ELSE Type2 
    END AS TypeA,
    CASE 
      WHEN Type2 IS NULL OR Type1 < Type2 THEN Type2 
      ELSE Type1 
    END AS TypeB
  FROM pokemon),
attacking_types AS (SELECT DISTINCT attacking_type FROM type_effectiveness)
SELECT dc.TypeA AS Type1, dc.TypeB AS Type2, SUM(te1.multiplier * COALESCE(te2.multiplier, 1)) AS cumulative_score
FROM distinct_combos dc
CROSS JOIN attacking_types a
JOIN type_effectiveness te1 ON te1.attacking_type = a.attacking_type AND te1.defending_type = dc.TypeA
LEFT JOIN type_effectiveness te2 ON te2.attacking_type = a.attacking_type AND te2.defending_type = dc.TypeB
GROUP BY dc.TypeA, dc.TypeB
ORDER BY cumulative_score ASC;

-- 8. pokemon e mosse migliori per attaccare pokemon di tipo (drago)
SELECT p.Name, p.Type1, p.Type2, 
    CASE 
        WHEN m.category = 'Physical' THEN p.Attack 
        WHEN m.category = 'Special' THEN p."Sp. Atk" 
        ELSE 0 
    END AS Effective_Attack, 
    m.name AS Move, m.power, m.type, m.category, te.multiplier AS Type_Multiplier,
    (CASE 
        WHEN m.category = 'Physical' THEN p.Attack 
        WHEN m.category = 'Special' THEN p."Sp. Atk" 
        ELSE 0 
    END * m.power * te.multiplier) AS Offensive_Power
FROM pokemon p
JOIN moves m ON p.Type1 = m.type OR p.Type2 = m.type
JOIN type_effectiveness te ON m.type = te.attacking_type
WHERE te.defending_type = 'Dragon' AND te.multiplier > 1 AND m.power IS NOT NULL
ORDER BY Offensive_Power DESC
LIMIT 10;

-- 9. pokemon migliori per combattere pokemon di tipo (drago) 
SELECT p.Name, p.Type1, p.Type2, 
    CASE 
        WHEN m.category = 'Physical' THEN p.Attack 
        WHEN m.category = 'Special' THEN p."Sp. Atk" 
        ELSE 0 
    END AS Effective_Attack, 
    m.name AS Move, m.power, m.type, m.category, te.multiplier AS Type_Multiplier,
    (CASE 
        WHEN m.category = 'Physical' THEN p.Attack 
        WHEN m.category = 'Special' THEN p."Sp. Atk" 
        ELSE 0 
    END * m.power * te.multiplier) AS Offensive_Power
FROM pokemon p
JOIN moves m ON p.Type1 = m.type OR p.Type2 = m.type
JOIN type_effectiveness te ON m.type = te.attacking_type
WHERE te.defending_type = 'Dragon' AND te.multiplier > 1 AND m.power IS NOT NULL
  AND EXISTS (
      SELECT 1
      FROM type_effectiveness te_def
      WHERE te_def.attacking_type in ('Dragon') AND te_def.multiplier = 0 AND (te_def.defending_type = p.Type1 OR te_def.defending_type = p.Type2))
ORDER BY Offensive_Power DESC
LIMIT 10;

--10. estrai un pokemon casuale e trova miglior pokemon e mosse contro di esso
WITH opponent AS (
  SELECT *
  FROM pokemon
  ORDER BY RANDOM()
  LIMIT 1 )
SELECT p.Name, p.Type1, p.Type2,
  CASE
    WHEN m.category = 'Physical' THEN p.Attack
    WHEN m.category = 'Special' THEN p."Sp. Atk"
    ELSE 0
  END AS Effective_Attack, m.name AS Move, m.power, m.type AS MoveType, m.category, te1.multiplier AS Multiplier1, COALESCE(te2.multiplier, 1) AS Multiplier2,
  (CASE
      WHEN m.category = 'Physical' THEN p.Attack
      WHEN m.category = 'Special' THEN p."Sp. Atk"
      ELSE 0
  END * m.power * te1.multiplier * COALESCE(te2.multiplier, 1)) AS Offensive_Power, opp.Name AS Opponent_Name, opp.Type1 AS Opp_Type1, opp.Type2 AS Opp_Type2
FROM pokemon p
CROSS JOIN opponent opp
JOIN moves m ON p.Type1 = m.type OR p.Type2 = m.type
JOIN type_effectiveness te1 ON m.type = te1.attacking_type AND te1.defending_type = opp.Type1
LEFT JOIN type_effectiveness te2 ON m.type = te2.attacking_type AND te2.defending_type = opp.Type2
WHERE (te1.multiplier * COALESCE(te2.multiplier, 1)) > 1 AND m.power IS NOT NULL
  -- Condizioni difensive sul candidato in base ai tipi dell'avversario:
  AND (
    -- Caso avversario monotipo: il candidato deve essere immune al tipo opp.Type1
    (opp.Type2 IS NULL AND 
      ((SELECT te_a.multiplier 
        FROM type_effectiveness te_a 
        WHERE te_a.attacking_type = opp.Type1 AND te_a.defending_type = p.Type1)
        *
        COALESCE((SELECT te_b.multiplier 
                  FROM type_effectiveness te_b 
                  WHERE te_b.attacking_type = opp.Type1 AND te_b.defending_type = p.Type2), 1) = 0))
    OR
    -- Caso avversario bitipo: o il candidato è immune al primo tipo e poco vulnerabile (≤ 1) al secondo...
    (opp.Type2 IS NOT NULL AND 
      (
        (
          (SELECT te_a.multiplier 
           FROM type_effectiveness te_a 
           WHERE te_a.attacking_type = opp.Type1 AND te_a.defending_type = p.Type1)
          *
          COALESCE(
           (SELECT te_b.multiplier 
            FROM type_effectiveness te_b 
            WHERE te_b.attacking_type = opp.Type1 AND te_b.defending_type = p.Type2),
           1
          ) = 0
          AND
          (SELECT te_c.multiplier 
           FROM type_effectiveness te_c 
           WHERE te_c.attacking_type = opp.Type2 AND te_c.defending_type = p.Type1)
          *
          COALESCE(
           (SELECT te_d.multiplier 
            FROM type_effectiveness te_d 
            WHERE te_d.attacking_type = opp.Type2 AND te_d.defending_type = p.Type2),
           1
          ) <= 1
        )
        OR
        (
          -- ...oppure il candidato è immune al secondo tipo e poco vulnerabile (≤ 1) al primo.
          (SELECT te_c.multiplier 
           FROM type_effectiveness te_c 
           WHERE te_c.attacking_type = opp.Type2 AND te_c.defending_type = p.Type1)
          *
          COALESCE(
           (SELECT te_d.multiplier 
            FROM type_effectiveness te_d 
            WHERE te_d.attacking_type = opp.Type2 AND te_d.defending_type = p.Type2),
           1
          ) = 0
          AND
          (SELECT te_a.multiplier 
           FROM type_effectiveness te_a 
           WHERE te_a.attacking_type = opp.Type1 AND te_a.defending_type = p.Type1)
          *
          COALESCE(
           (SELECT te_b.multiplier 
            FROM type_effectiveness te_b 
            WHERE te_b.attacking_type = opp.Type1 AND te_b.defending_type = p.Type2),
           1
          ) <= 1
        )
      )
    )
  )
  AND ((opp.Defense > opp."Sp. Def" AND m.category = 'Special') OR (opp.Defense <= opp."Sp. Def" AND m.category = 'Physical')) --- la mossa deve essere più efficace contro la difesa del pokemon avversario
ORDER BY Offensive_Power DESC
LIMIT 20;