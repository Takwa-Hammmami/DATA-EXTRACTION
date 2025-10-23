-- ============================================================================
-- 1. Écarts stock physique vs système
-- ============================================================================

SELECT 
    T0."ItemCode",
    T0."ItemName",
    T1."WhsCode",
    T1."OnHand",
    COALESCE(T2."InQty", 0) AS "DernierInventaire",
    (T1."OnHand" - COALESCE(T2."InQty", 0)) AS "Ecart"
FROM "OITM" T0
INNER JOIN "OITW" T1 ON T0."ItemCode" = T1."ItemCode"
LEFT JOIN (
    SELECT 
        "ItemCode",
        "Warehouse",
        "InQty",
        ROW_NUMBER() OVER (
            PARTITION BY "ItemCode", "Warehouse" 
            ORDER BY "DocDate" DESC
        ) AS "rn"
    FROM "OINM"
    WHERE "TransType" = 59  -- 59 = Inventaire
) T2 ON T0."ItemCode" = T2."ItemCode" 
    AND T1."WhsCode" = T2."Warehouse" 
    AND T2."rn" = 1
WHERE T1."OnHand" <> COALESCE(T2."InQty", 0);


-- ============================================================================
-- 2. Stocks négatifs
-- ============================================================================

SELECT 
    T0."ItemCode",
    T0."ItemName",
    T1."WhsCode",
    T1."OnHand"
FROM "OITM" T0
INNER JOIN "OITW" T1 ON T0."ItemCode" = T1."ItemCode"
WHERE COALESCE(T1."OnHand", 0) < 0;


-- ============================================================================
-- 3. Articles avec stock mais sans emplacement défini
-- ============================================================================

SELECT 
    T0."ItemCode",
    T0."ItemName",
    T1."WhsCode",
    T1."OnHand"
FROM OITM T0
INNER JOIN OITW T1 ON T0."ItemCode" = T1."ItemCode"
LEFT JOIN OIBQ T2 ON T0."ItemCode" = T2."ItemCode" 
    AND T1."WhsCode" = T2."WhsCode"
LEFT JOIN OBIN T3 ON T2."BinAbs" = T3."AbsEntry"
WHERE T0."validFor" = 'Y'
  AND T1."OnHand" > 0
  AND (T2."BinAbs" IS NULL 
       OR T3."BinCode" IS NULL 
       OR TRIM(T3."BinCode") = '')
GROUP BY T0."ItemCode", T0."ItemName", T1."WhsCode", T1."OnHand";

-- ============================================================================
-- 4. Mouvements stock anormaux (quantité nette ≤ 0)
-- ============================================================================

SELECT 
    T0."ItemCode",
    T0."ItemName",
    T1."Warehouse" AS "WhsCode",
    T1."BASE_REF" AS "DocNum",
    T1."DocDate",
    (T1."InQty" - T1."OutQty") AS "QuantiteNette",
    T1."TransType",
    CASE T1."TransType"
        WHEN 13 THEN 'Facture AR'
        WHEN 14 THEN 'Avoir AR'
        WHEN 15 THEN 'Livraison'
        WHEN 16 THEN 'Retour'
        WHEN 18 THEN 'Facture AP'
        WHEN 19 THEN 'Avoir AP'
        WHEN 20 THEN 'Réception'
        WHEN 21 THEN 'Retour AP'
        WHEN 59 THEN 'Inventaire'
        WHEN 60 THEN 'Sortie marchandise'
        WHEN 67 THEN 'Transfert stock'
        ELSE 'Autre'
    END AS "TypeDocument"
FROM OITM T0
INNER JOIN OINM T1 ON T0."ItemCode" = T1."ItemCode"
WHERE (T1."InQty" - T1."OutQty") <= 0
  AND T1."DocDate" >= ADD_DAYS(CURRENT_DATE, -90)
ORDER BY T1."DocDate" DESC;



-- ============================================================================
-- 5. Articles bloqués en stock (quantité engagée)
-- ============================================================================

SELECT 
    T0."ItemCode",
    T0."ItemName",
    T1."WhsCode",
    T1."IsCommited" AS "QteEngagee",
    T1."OnHand" AS "StockDisponible",
    ROUND((T1."IsCommited" * 100.0 / NULLIF(T1."OnHand", 0)), 2) AS "PourcentageBloque"
FROM OITM T0
INNER JOIN OITW T1 ON T0."ItemCode" = T1."ItemCode"
WHERE T0."validFor" = 'Y'
  AND T1."IsCommited" > 0
ORDER BY T1."IsCommited" DESC;


-- ============================================================================
-- 6. Stock dormant (absence de mouvements depuis 12 mois)
-- ============================================================================

SELECT 
    T0."ItemCode",
    T0."ItemName",
    T1."WhsCode",
    T1."OnHand",
    IFNULL(MAX(T2."DocDate"), '1900-01-01') AS "DernierMvt",
    DAYS_BETWEEN(IFNULL(MAX(T2."DocDate"), '1900-01-01'), CURRENT_DATE) AS "JoursSansMouvement",
    ROUND(T1."OnHand" * T0."AvgPrice", 2) AS "ValeurStock"
FROM OITM T0
INNER JOIN OITW T1 ON T0."ItemCode" = T1."ItemCode"
LEFT JOIN OINM T2 ON T0."ItemCode" = T2."ItemCode" 
    AND T1."WhsCode" = T2."Warehouse"
WHERE T1."OnHand" > 0
  AND T0."validFor" = 'Y'
GROUP BY T0."ItemCode", T0."ItemName", T1."WhsCode", T1."OnHand", T0."AvgPrice"
HAVING IFNULL(MAX(T2."DocDate"), '1900-01-01') < ADD_DAYS(CURRENT_DATE, -365)
ORDER BY "JoursSansMouvement" DESC;
