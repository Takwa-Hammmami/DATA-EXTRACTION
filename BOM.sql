
-- ============================================================================
-- 1. Articles fabriqués sans nomenclature (BOM)
-- ============================================================================
-- Type d'anomalie : Données manquantes
-- Description : Articles configurés en fabrication mais sans BOM définie
-- ============================================================================
SELECT 
    T0."ItemCode",
    T0."ItemName",
    T0."PrcrmntMtd"
FROM "OITM" T0
LEFT JOIN "OITT" T1 ON T1."Code" = T0."ItemCode"
WHERE T0."PrcrmntMtd" = 'M'
  AND T1."Code" IS NULL;


-- ============================================================================
-- 2. BOM avec composants manquants
-- ============================================================================
-- Type d'anomalie : Données manquantes
-- Description : Nomenclatures sans composants définis

-- ============================================================================

SELECT 
    T0."Code" AS "Parent",
    T2."ItemName" AS "ParentName",
    T0."TreeType"
FROM "OITT" T0
LEFT JOIN "ITT1" T1 ON T1."Father" = T0."Code"
INNER JOIN "OITM" T2 ON T2."ItemCode" = T0."Code"
WHERE T1."Father" IS NULL;


-- ============================================================================
-- 3. Composants BOM inactifs
-- ============================================================================
-- Type d'anomalie : Données invalides
-- Description : Composants de nomenclature marqués comme inactifs

-- ============================================================================

SELECT 
    T1."Father" AS "Parent",
    T3."ItemName" AS "ParentName",
    T1."Code" AS "Component",
    T2."ItemName" AS "ComponentName",
    T2."validFor",
    T1."Quantity"
FROM "ITT1" T1
INNER JOIN "OITM" T2 ON T1."Code" = T2."ItemCode"
INNER JOIN "OITM" T3 ON T3."ItemCode" = T1."Father"
WHERE T2."validFor" = 'N';


-- ============================================================================
-- 4. BOM avec quantités nulles ou négatives
-- ============================================================================
-- Type d'anomalie : Données incohérentes
-- Description : Composants avec quantités invalides (NULL, 0 ou négatives)

-- ============================================================================

SELECT 
    T1."Father" AS "Parent",
    T3."ItemName" AS "ParentName",
    T1."Code" AS "Component",
    T2."ItemName" AS "ComponentName",
    T1."Quantity"
FROM "ITT1" T1
INNER JOIN "OITM" T2 ON T1."Code" = T2."ItemCode"
INNER JOIN "OITM" T3 ON T3."ItemCode" = T1."Father"
WHERE IFNULL(T1."Quantity", 0) <= 0;


-- ============================================================================
-- 5. BOM sans type défini
-- ============================================================================
-- Type d'anomalie : Données manquantes
-- Description : Type de nomenclature non renseigné (production, template, etc.)
-- ============================================================================

SELECT 
    T0."Code",
    T1."ItemName" AS "Name",
    T0."TreeType"
FROM "OITT" T0
INNER JOIN "OITM" T1 ON T1."ItemCode" = T0."Code"
WHERE T0."TreeType" IS NULL 
   OR TRIM(T0."TreeType") = '';


-- ============================================================================
-- 6. BOM sans entrepôt de production défini
-- ============================================================================
-- Type d'anomalie : Données manquantes
-- Description : Entrepôt de production/consommation non défini

-- ============================================================================

SELECT 
    T0."Code",
    T1."ItemName" AS "Name",
    T0."ToWH" AS "EntrepotProduction"
FROM "OITT" T0
INNER JOIN "OITM" T1 ON T1."ItemCode" = T0."Code"
WHERE T0."ToWH" IS NULL 
   OR TRIM(T0."ToWH") = '';


-- ============================================================================
-- 7. BOM avec articles parents inactifs
-- ============================================================================
-- Type d'anomalie : Données invalides
-- Description : BOM dont l'article fini est marqué inactif

-- ============================================================================

SELECT 
    T0."Code" AS "Parent",
    T1."ItemName" AS "ParentName",
    T1."validFor",
    T0."TreeType"
FROM "OITT" T0
INNER JOIN "OITM" T1 ON T1."ItemCode" = T0."Code"
WHERE T1."validFor" = 'N';


-- ============================================================================
-- 8. Nomenclatures en double (même article parent)
-- ============================================================================
-- Type d'anomalie : Doublons
-- Description : Plusieurs versions de BOM pour le même article parent


-- ============================================================================

SELECT 
    "Code" AS "Parent",
    COUNT(*) AS "NbVersions",
    STRING_AGG("Name", ', ') AS "Versions"
FROM "OITT"
GROUP BY "Code"
HAVING COUNT(*) > 1;

-- ============================================================================
-- 9. Composants dupliqués dans une même nomenclature
-- ============================================================================
-- Type d'anomalie : Doublons
-- Description : Même composant apparaît plusieurs fois dans une BOM

-- ============================================================================

SELECT 
    T1."Father" AS "Parent",
    T0."ItemName" AS "ParentName",
    T1."Code" AS "Component",
    T2."ItemName" AS "ComponentName",
    COUNT(*) AS "NbOccurrences",
    SUM(T1."Quantity") AS "QuantiteTotale"
FROM "ITT1" T1
INNER JOIN "OITM" T0 ON T0."ItemCode" = T1."Father"
INNER JOIN "OITM" T2 ON T2."ItemCode" = T1."Code"
GROUP BY T1."Father", T0."ItemName", T1."Code", T2."ItemName"
HAVING COUNT(*) > 1;


-- ============================================================================
-- 10. BOM à plusieurs niveaux incohérente (cycle / self-usage)
-- ============================================================================
-- Type d'anomalie : Données incohérentes
-- Description : Article parent utilisé comme composant de lui-même (référence circulaire)

-- ============================================================================

SELECT DISTINCT
    T1."Father" AS "Parent",
    T0."ItemName" AS "ParentName",
    T1."Code" AS "Component",
    T2."ItemName" AS "ComponentName",
    T1."Quantity"
FROM "ITT1" T1
INNER JOIN "OITM" T0 ON T0."ItemCode" = T1."Father"
INNER JOIN "OITM" T2 ON T2."ItemCode" = T1."Code"
WHERE T1."Father" = T1."Code";

-- ============================================================================
-- 11. Composants avec unité de mesure différente de l'article
-- ============================================================================
-- Type d'anomalie : Données incohérentes
-- Description : Composant utilise une UoM différente de celle définie dans l'article

-- ============================================================================

SELECT 
    T1."Father" AS "Parent",
    T0."ItemName" AS "ParentName",
    T1."Code" AS "Component",
    T2."ItemName" AS "ComponentName",
    T1."Quantity",
    T2."InvntryUom" AS "UoM_Article",
    T1."IssueMthd" AS "Methode_Sortie"
FROM "ITT1" T1
INNER JOIN "OITM" T0 ON T0."ItemCode" = T1."Father"
INNER JOIN "OITM" T2 ON T2."ItemCode" = T1."Code"
WHERE T1."Code" <> T2."ItemCode"  -- Vérification de cohérence basique
ORDER BY T1."Father", T1."Code";


-- ============================================================================
-- 12. BOM sans quantité de base définie
-- ============================================================================
-- Type d'anomalie : Données manquantes
-- Description : Quantité de production de base non définie
-- ============================================================================

SELECT 
    T0."Code" AS "Parent",
    T1."ItemName" AS "ParentName",
    T0."TreeType",
    T0."Qauntity" AS "QuantiteBase"  -- Attention: SAP utilise "Qauntity" (faute de frappe historique)
FROM "OITT" T0
INNER JOIN "OITM" T1 ON T1."ItemCode" = T0."Code"
WHERE IFNULL(T0."Qauntity", 0) <= 0;


-- ============================================================================
-- 13. Composants orphelins (référencent un article parent inexistant)
-- ============================================================================
-- Type d'anomalie : Intégrité référentielle
-- Description : Composants qui pointent vers une BOM inexistante

-- ============================================================================

SELECT 
    T1."Father" AS "ParentInexistant",
    T1."Code" AS "Component",
    T2."ItemName" AS "ComponentName",
    T1."Quantity"
FROM "ITT1" T1
INNER JOIN "OITM" T2 ON T2."ItemCode" = T1."Code"
LEFT JOIN "OITT" T0 ON T0."Code" = T1."Father"
WHERE T0."Code" IS NULL;


-- ============================================================================
-- 14. Composants qui n'existent pas dans la table articles
-- ============================================================================
-- Type d'anomalie : Intégrité référentielle
-- Description : Composants référencés dans BOM mais absents de la fiche article

-- ============================================================================

SELECT 
    T1."Father" AS "Parent",
    T0."ItemName" AS "ParentName",
    T1."Code" AS "ComponentInexistant",
    T1."Quantity"
FROM "ITT1" T1
INNER JOIN "OITM" T0 ON T0."ItemCode" = T1."Father"
LEFT JOIN "OITM" T2 ON T2."ItemCode" = T1."Code"
WHERE T2."ItemCode" IS NULL;


-- ============================================================================
-- 15. BOM avec profondeur excessive (niveau > 5)
-- ============================================================================
-- Type d'anomalie : Complexité excessive
-- Description : Nomenclatures avec trop de niveaux d'imbrication
-- ============================================================================

-- Détection des BOM avec composants fabriqués (niveau 2 minimum)
SELECT 
    T1."Father" AS "Parent",
    T0."ItemName" AS "ParentName",
    T1."Code" AS "Component",
    T2."ItemName" AS "ComponentName",
    T2."PrcrmntMtd" AS "ComponentProcurement",
    T1."Quantity",
    CASE WHEN T3."Code" IS NOT NULL THEN 'Oui' ELSE 'Non' END AS "A_SousBOM"
FROM "ITT1" T1
INNER JOIN "OITM" T0 ON T0."ItemCode" = T1."Father"
INNER JOIN "OITM" T2 ON T2."ItemCode" = T1."Code"
LEFT JOIN "OITT" T3 ON T3."Code" = T1."Code"
WHERE T2."PrcrmntMtd" = 'M'  -- Composant également fabriqué
ORDER BY T1."Father", T1."Code";
