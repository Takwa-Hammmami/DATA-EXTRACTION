-- ========================================
-- 1) Articles sans unité de mesure principale
-- ========================================
-- Détecte les articles dont l'unité d'inventaire n'est pas renseignée

SELECT ItemCode, ItemName, InvntryUom
FROM OITM
WHERE InvntryUom IS NULL OR TRIM(InvntryUom) = '';

-- ========================================
-- 2) Articles sans unité de conversion (UoM secondaire différente de l'UoM d'inventaire)
-- ========================================
-- Vérifie que les articles ont bien des unités de conversion définies dans leur groupe UoM

SELECT 
    T0."ItemCode",        -- Code article
    T0."ItemName",        -- Nom de l'article
    T0."InvntryUom",      -- Unité d'inventaire
    T0."UgpEntry",        -- Groupe d'unités de mesure
    L."UomEntry"          -- Entrée unité secondaire
FROM "OITM" T0
LEFT JOIN "UGP1" L
       ON L."UgpEntry" = T0."UgpEntry"
      AND L."UomEntry" <> T0."IUoMEntry"
WHERE T0."UgpEntry" IS NULL 
   OR L."UomEntry" IS NULL;


-- ========================================
-- 3) Articles sans groupe d'article
-- ========================================
-- Identifie les articles orphelins sans classification

SELECT 
    T0."ItemCode",       -- Code article
    T0."ItemName",       -- Nom de l'article
    T0."ItmsGrpCod"      -- Code du groupe d'article
FROM "OITM" T0
LEFT JOIN "OITB" T1 
       ON T0."ItmsGrpCod" = T1."ItmsGrpCod"
WHERE T0."ItmsGrpCod" IS NULL;


-- ========================================
-- 4) Articles avec code dupliqué
-- ========================================
-- Détecte les doublons sur les codes articles (ne devrait jamais arriver)

SELECT 
    "ItemCode", 
    COUNT(*) AS "NbDoublons"
FROM "OITM"
GROUP BY "ItemCode"
HAVING COUNT(*) > 1;

-- ========================================
-- 5) Articles avec nom dupliqué
-- ========================================
-- Repère les articles ayant exactement le même nom

SELECT 
    "ItemName", 
    COUNT(*) AS "NbDoublons"
FROM "OITM"
GROUP BY "ItemName"
HAVING COUNT(*) > 1;

-- ========================================
-- 6) Articles achetés sans fournisseur principal
-- ========================================
-- Liste les articles marqués comme achetables mais sans fournisseur défini

SELECT 
    "ItemCode", 
    "ItemName"
FROM "OITM"
WHERE "PrchseItem" = 'Y'
  AND ("CardCode" IS NULL OR TRIM("CardCode") = '');


-- ========================================
-- 7) Articles achetés avec mono-sourcing (moins de 2 fournisseurs)
-- ========================================
-- Identifie les articles dépendants d'un seul fournisseur

SELECT 
    T0."ItemCode", 
    T0."ItemName", 
    COUNT(DISTINCT T1."CardCode") AS "NbFournisseurs"
FROM "OITM" T0
INNER JOIN "ITM2" T1 ON T1."ItemCode" = T0."ItemCode" AND TRIM(T1."CardCode") <> ''
WHERE T0."PrchseItem" = 'Y'
GROUP BY T0."ItemCode", T0."ItemName"
HAVING COUNT(DISTINCT T1."CardCode") < 2;

-- ========================================
-- 8) Articles sans méthode d'approvisionnement (Buy/Make)
-- ========================================
-- Détecte les articles pour lesquels on ne sait pas s'ils sont achetés ou fabriqués

SELECT 
    "ItemCode", 
    "ItemName", 
    "PrcrmntMtd"
FROM "OITM"
WHERE "PrcrmntMtd" IS NULL OR TRIM("PrcrmntMtd") = '';


-- ========================================
-- 9) Articles fabriqués (Make) sans nomenclature (BOM)
-- ========================================
-- Liste les articles déclarés "à fabriquer" mais sans BOM associée

SELECT 
    T0."ItemCode", 
    T0."ItemName"
FROM "OITM" T0
LEFT JOIN "OITT" T1 ON T1."Code" = T0."ItemCode"
WHERE T0."PrcrmntMtd" = 'M'
  AND T1."Code" IS NULL;

-- ========================================
-- 10) Articles avec BOM mais marqués comme achetés (Buy)
-- ========================================
-- Incohérence : article possède une nomenclature mais est configuré en achat

SELECT 
    T0."ItemCode", 
    T0."ItemName"
FROM "OITM" T0
INNER JOIN "OITT" T1 ON T1."Code" = T0."ItemCode"
WHERE T0."PrcrmntMtd" = 'B';

-- ========================================
-- 11) Articles sans stock min/max par entrepôt
-- ========================================
-- Vérifie que chaque article/entrepôt a des seuils de stock définis

SELECT 
    T0."ItemCode", 
    T0."ItemName", 
    T1."WhsCode", 
    T1."MinLevel", 
    T1."MaxLevel"
FROM "OITM" T0
INNER JOIN "OITW" T1 ON T1."ItemCode" = T0."ItemCode"
WHERE (T1."MinLevel" IS NULL OR T1."MinLevel" = 0)
   OR (T1."MaxLevel" IS NULL OR T1."MaxLevel" = 0);

-- ========================================
-- 12) Articles avec incohérence stock min > max
-- ========================================
-- Détecte les erreurs de paramétrage : minimum supérieur au maximum

SELECT 
    T0."ItemCode", 
    T0."ItemName", 
    T1."WhsCode", 
    T1."MinLevel", 
    T1."MaxLevel"
FROM "OITM" T0
INNER JOIN "OITW" T1 ON T1."ItemCode" = T0."ItemCode"
WHERE T1."MinLevel" > T1."MaxLevel";

-- ========================================
-- 13) Articles inactifs (validFor = 'N')
-- ========================================
-- Liste les articles marqués comme inactifs dans le système

SELECT 
    "ItemCode", 
    "ItemName", 
    "ValidFor", 
    "UpdateDate"
FROM "OITM"
WHERE "ValidFor" = 'N';

-- ========================================
-- 14) Articles sans mise à jour depuis 2 ans
-- ========================================
-- Identifie les articles potentiellement obsolètes (non maintenus)

SELECT 
    "ItemCode", 
    "ItemName", 
    "UpdateDate",
    DAYS_BETWEEN("UpdateDate", CURRENT_DATE) AS "JoursInactivite"
FROM "OITM"
WHERE "UpdateDate" < ADD_MONTHS(CURRENT_DATE, -24);

-- ========================================
-- 15) Articles sans entrepôt par défaut
-- ========================================
-- Vérifie que chaque article a un entrepôt de stockage principal défini

SELECT 
    "ItemCode", 
    "ItemName", 
    "DfltWH" AS "EntrepotDefaut"
FROM "OITM"
WHERE "DfltWH" IS NULL OR TRIM("DfltWH") = '';

-- ========================================
-- 16) Articles avec nom vide ou trop court (< 3 caractères)
-- ========================================
-- Détecte les articles avec des libellés insuffisants

SELECT 
    "ItemCode", 
    "ItemName", 
    LENGTH("ItemName") AS "LongueurNom"
FROM "OITM"
WHERE "ItemName" IS NULL
   OR TRIM("ItemName") = ''
   OR LENGTH(TRIM("ItemName")) < 3;

-- ========================================
-- 17) Articles sans code-barres / GTIN
-- ========================================
-- Liste les articles sans identifiant normalisé (code-barres)

SELECT 
    "ItemCode", 
    "ItemName",
    IFNULL("CodeBars", 'NULL') AS "CodeBarres"
FROM "OITM"
WHERE "CodeBars" IS NULL OR TRIM("CodeBars") = '';

-- ========================================
-- 18) Articles sans poids ou dimensions
-- ========================================
-- Identifie les articles dont les caractéristiques physiques ne sont pas renseignées

SELECT 
    "ItemCode", 
    "ItemName", 
    "SWeight1", 
    "SHeight1", 
    "SWidth1", 
    "SLength1"
FROM "OITM"
WHERE IFNULL("SWeight1", 0) = 0
   OR IFNULL("SHeight1", 0) = 0
   OR IFNULL("SWidth1", 0)  = 0
   OR IFNULL("SLength1", 0) = 0;

-- ========================================
-- 19) Articles parents de BOM inactifs
-- ========================================
-- Détecte les nomenclatures dont l'article fini est marqué inactif

SELECT 
    T0."Code" AS "CodeParent", 
    T1."ItemName", 
    T1."ValidFor"
FROM "OITT" T0
INNER JOIN "OITM" T1 ON T1."ItemCode" = T0."Code"
WHERE T1."ValidFor" = 'N';

-- ========================================
-- 20) Articles sans mouvements depuis 12 mois
-- ========================================
-- Identifie les articles dormants (sans entrée/sortie stock depuis 1 an)

SELECT 
    T0."ItemCode", 
    T0."ItemName",
    MAX(T1."DocDate") AS "DernierMouvement"
FROM "OITM" T0
LEFT JOIN "OINM" T1 ON T1."ItemCode" = T0."ItemCode"
GROUP BY T0."ItemCode", T0."ItemName"
HAVING MAX(T1."DocDate") IS NULL
    OR MAX(T1."DocDate") < ADD_MONTHS(CURRENT_DATE, -12);


-- ========================================
-- 21) Articles multi-entrepôts avec incohérences de min/max
-- ========================================
-- Détecte les articles présents dans plusieurs entrepôts avec des paramètres min/max différents

SELECT 
    T0."ItemCode", 
    T0."ItemName",
    COUNT(DISTINCT T1."WhsCode") AS "NbEntrepots",
    COUNT(DISTINCT (TO_VARCHAR(IFNULL(T1."MinLevel",0)) || '|' || TO_VARCHAR(IFNULL(T1."MaxLevel",0)))) AS "NbParamSets"
FROM "OITM" T0
INNER JOIN "OITW" T1 ON T1."ItemCode" = T0."ItemCode"
GROUP BY T0."ItemCode", T0."ItemName"
HAVING COUNT(DISTINCT T1."WhsCode") > 1
   AND COUNT(DISTINCT (TO_VARCHAR(IFNULL(T1."MinLevel",0)) || '|' || TO_VARCHAR(IFNULL(T1."MaxLevel",0)))) > 1;
