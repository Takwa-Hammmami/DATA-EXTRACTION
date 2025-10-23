-- 1. Fournisseurs principaux manquants pour un article
-- ============================================================================
-- Type d'anomalie : Données manquantes
-- Description : Identifie les articles achetés sans fournisseur principal défini
-- ============================================================================

SELECT 
    T0."ItemCode",
    T0."ItemName",
    T0."PrcrmntMtd",
    T0."CardCode" AS "FournisseurParDefaut"
FROM "OITM" T0
WHERE T0."PrcrmntMtd" = 'B'
  AND (T0."CardCode" IS NULL OR T0."CardCode" = '');
-- ============================================================================
-- 2. Articles avec un seul fournisseur utilisé (analyse historique)
-- ============================================================================

SELECT 
    T0."ItemCode",
    T0."ItemName",
    T0."CardCode" AS "FournisseurPrincipal",
    COUNT(DISTINCT T1."CardCode") AS "NbFournisseursDifferents"
FROM "OITM" T0
LEFT JOIN "POR1" T1 ON T1."ItemCode" = T0."ItemCode"
WHERE T0."PrcrmntMtd" = 'B'
  AND T0."CardCode" IS NOT NULL
  AND T0."CardCode" <> ''
GROUP BY T0."ItemCode", T0."ItemName", T0."CardCode"
HAVING COUNT(DISTINCT T1."CardCode") <= 1;


-- ============================================================================
-- 3. Fournisseurs principaux inactifs
-- ============================================================================

SELECT 
    T0."ItemCode",
    T0."ItemName",
    T0."CardCode",
    T1."CardName",
    T1."validFor"
FROM "OITM" T0
INNER JOIN "OCRD" T1 ON T0."CardCode" = T1."CardCode"
WHERE T0."PrcrmntMtd" = 'B'
  AND T1."CardType" = 'S'
  AND T1."validFor" = 'N';


-- ============================================================================
-- 4. Fournisseurs sans adresse valide
-- ============================================================================

SELECT 
    "CardCode",
    "CardName",
    "Address",
    "MailAddres"
FROM "OCRD"
WHERE "CardType" = 'S'
  AND (COALESCE("Address", '') = '' AND COALESCE("MailAddres", '') = '');


-- ============================================================================
-- 5. Articles sans prix d'achat standard
-- ============================================================================

SELECT 
    T0."ItemCode",
    T0."ItemName",
    T0."CardCode" AS "Fournisseur",
    T1."CardName",
    T0."BuyUnitMsr",
    T0."NumInBuy"
FROM "OITM" T0
LEFT JOIN "OCRD" T1 ON T0."CardCode" = T1."CardCode"
WHERE T0."PrcrmntMtd" = 'B'
  AND T0."CardCode" IS NOT NULL
  AND T0."CardCode" <> '';


-- ============================================================================
-- 6. Articles avec délai d'approvisionnement non défini
-- ============================================================================

SELECT 
    T0."ItemCode",
    T0."ItemName",
    T0."CardCode" AS "Fournisseur",
    T1."CardName",
    T0."LeadTime",
    T0."OrdrIntrvl",
    T0."MinOrdrQty"
FROM "OITM" T0
LEFT JOIN "OCRD" T1 ON T0."CardCode" = T1."CardCode"
WHERE T0."PrcrmntMtd" = 'B'
  AND (T0."LeadTime" IS NULL OR T0."LeadTime" = 0);


-- ============================================================================
-- 7. Fournisseurs doublons - même code
-- ============================================================================

SELECT 
    "CardCode",
    COUNT(*) AS "NombreOccurrences"
FROM "OCRD"
WHERE "CardType" = 'S'
GROUP BY "CardCode"
HAVING COUNT(*) > 1;


-- ============================================================================
-- 8. Fournisseurs doublons - même nom
-- ============================================================================

SELECT 
    UPPER("CardName") AS "NomNormalise",
    STRING_AGG("CardCode", ', ') AS "Codes",
    COUNT(*) AS "NombreOccurrences"
FROM "OCRD"
WHERE "CardType" = 'S'
GROUP BY UPPER("CardName")
HAVING COUNT(*) > 1;

-- Alternative si STRING_AGG ne fonctionne pas :
SELECT 
    UPPER("CardName") AS "NomNormalise",
    COUNT(*) AS "NombreOccurrences"
FROM "OCRD"
WHERE "CardType" = 'S'
GROUP BY UPPER("CardName")
HAVING COUNT(*) > 1;


-- ============================================================================
-- 9. Fournisseurs sans conditions de paiement définies
-- ============================================================================

SELECT 
    "CardCode",
    "CardName",
    "GroupNum"
FROM "OCRD"
WHERE "CardType" = 'S'
  AND ("GroupNum" IS NULL OR "GroupNum" = -1);


-- ============================================================================
-- 10. Fournisseurs sans devise
-- ============================================================================

SELECT 
    "CardCode",
    "CardName",
    "Currency"
FROM "OCRD"
WHERE "CardType" = 'S'
  AND COALESCE("Currency", '') = '';


-- ============================================================================
-- 11. Fournisseurs sans contact principal
-- ============================================================================

SELECT 
    T0."CardCode",
    T0."CardName",
    T0."Phone1",
    T0."E_Mail"
FROM "OCRD" T0
WHERE T0."CardType" = 'S'
  AND NOT EXISTS (
    SELECT 1 FROM "OCPR" T1 
    WHERE T1."CardCode" = T0."CardCode"
  );


-- ============================================================================
-- 12. Fournisseurs avec devise invalide
-- ============================================================================

SELECT 
    T0."CardCode",
    T0."CardName",
    T0."Currency" AS "DeviseInvalide"
FROM "OCRD" T0
LEFT JOIN "OCRN" T1 ON T0."Currency" = T1."CurrCode"
WHERE T0."CardType" = 'S'
  AND T0."Currency" IS NOT NULL
  AND T0."Currency" <> ''
  AND T1."CurrCode" IS NULL;


-- ============================================================================
-- 13. Articles avec fournisseur inexistant
-- ============================================================================

SELECT 
    T0."ItemCode",
    T0."ItemName",
    T0."CardCode" AS "FournisseurInexistant"
FROM "OITM" T0
LEFT JOIN "OCRD" T1 ON T0."CardCode" = T1."CardCode"
WHERE T0."PrcrmntMtd" = 'B'
  AND T0."CardCode" IS NOT NULL
  AND T0."CardCode" <> ''
  AND T1."CardCode" IS NULL;
