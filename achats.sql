
-- ============================================================================
-- 1. Articles sans prix d'achat standard
-- ============================================================================
-- Type d'anomalie : Données manquantes
-- Description : Articles achetés sans prix défini chez le fournisseur principal
-- ============================================================================

SELECT 
    T0."ItemCode",
    T0."ItemName",
    T0."CardCode" AS "FournisseurPrincipal",
    T1."CardName"
FROM OITM T0
LEFT JOIN OCRD T1 ON T0."CardCode" = T1."CardCode"
WHERE T0."CardCode" IS NOT NULL
  AND T0."PrcrmntMtd" = 'P'  -- P = Acheté
  AND T0."validFor" = 'Y';


-- ============================================================================
-- 2. Articles avec prix d'achat anormalement élevé
-- ============================================================================
-- Type d'anomalie : Données incohérentes
-- Description : Prix fournisseur supérieur de 20% à la moyenne du marché
-- ============================================================================

SELECT 
    T0."ItemCode",
    T0."ItemName",
    T0."AvgPrice" AS "PrixMoyenActuel",
    T0."LastPurPrc" AS "DernierPrixAchat"
FROM OITM T0
WHERE T0."LastPurPrc" > (T0."AvgPrice" * 1.2)
  AND T0."AvgPrice" > 0
  AND T0."PrcrmntMtd" = 'P'
  AND T0."validFor" = 'Y';
-- ============================================================================
-- 3. Fournisseurs sans conditions de paiement
-- ============================================================================
-- Type d'anomalie : Données manquantes
-- Description : Fournisseurs actifs sans conditions de paiement définies
-- Impact : Impossibilité de générer des factures avec échéances correctes
-- ============================================================================

SELECT 
    T0."CardCode",
    T0."CardName",
    T0."GroupCode",
    T0."GroupNum"
FROM OCRD T0
WHERE (T0."GroupNum" IS NULL 
   OR T0."GroupNum" = -1)
  AND T0."CardType" = 'S'  -- S = Supplier
  AND T0."validFor" = 'Y';


-- ============================================================================
-- 4. Articles sans code fiscal (TVA)
-- ============================================================================
-- Type d'anomalie : Données manquantes
-- Description : Articles achetés ou fabriqués sans code TVA défini
-- Impact : Erreurs de calcul TVA, non-conformité fiscale
-- ============================================================================

SELECT 
    T0."ItemCode",
    T0."ItemName",
    T0."TaxCodeAP" AS "TaxCode",
    T0."PrcrmntMtd"
FROM OITM T0
WHERE (T0."TaxCodeAP" IS NULL OR TRIM(T0."TaxCodeAP") = '')
  AND T0."PrcrmntMtd" IN ('P', 'M')  -- P = Acheté, M = Fabriqué
  AND T0."validFor" = 'Y';


-- ============================================================================
-- 5. Délais d'approvisionnement non définis
-- ============================================================================
-- Type d'anomalie : Données manquantes
-- Description : Articles achetés sans délai d'approvisionnement défini
-- Impact : Erreurs de planification, ruptures de stock
-- ============================================================================

SELECT 
    T0."ItemCode",
    T0."ItemName",
    T0."LeadTime" AS "DelaisArticle",
    T0."CardCode" AS "FournisseurPrincipal",
    T1."CardName"
FROM OITM T0
LEFT JOIN OCRD T1 ON T0."CardCode" = T1."CardCode"
WHERE IFNULL(T0."LeadTime", 0) = 0
  AND T0."PrcrmntMtd" = 'P'
  AND T0."validFor" = 'Y';


-- ============================================================================
-- 6. Fournisseurs sans devise configurée
-- ============================================================================
-- Type d'anomalie : Données manquantes
-- Description : Fournisseurs sans devise de transaction définie
-
-- ============================================================================

SELECT 
    T0."CardCode",
    T0."CardName",
    T0."Currency",
    T0."GroupCode"
FROM OCRD T0
WHERE (T0."Currency" IS NULL OR TRIM(T0."Currency") = '')
  AND T0."CardType" = 'S'
  AND T0."validFor" = 'Y';


-- ============================================================================
-- 7. Articles sans fournisseur principal défini
-- ============================================================================
-- Type d'anomalie : Données manquantes
-- Description : Articles achetés sans fournisseur principal configuré
-- Impact : Impossibilité de créer des commandes d'achat automatiques
-- ============================================================================

SELECT 
    T0."ItemCode",
    T0."ItemName",
    T0."CardCode" AS "FournisseurPrincipal",
    T0."PrcrmntMtd"
FROM OITM T0
WHERE (T0."CardCode" IS NULL OR TRIM(T0."CardCode") = '')
  AND T0."PrcrmntMtd" = 'P'
  AND T0."validFor" = 'Y';


-- ============================================================================
-- 8. Articles avec stock négatif
-- ============================================================================
-- Type d'anomalie : Données incohérentes
-- Description : Articles en stock négatif (disponible < 0)

-- ============================================================================

SELECT 
    T0."ItemCode",
    T0."ItemName",
    T0."OnHand" AS "StockPhysique",
    T0."IsCommited" AS "Engage",
    (T0."OnHand" - T0."IsCommited") AS "StockDisponible",
    T0."CardCode" AS "FournisseurPrincipal",
    T1."CardName"
FROM OITM T0
LEFT JOIN OCRD T1 ON T0."CardCode" = T1."CardCode"
WHERE (T0."OnHand" - T0."IsCommited") < 0
  AND T0."PrcrmntMtd" = 'P'
  AND T0."validFor" = 'Y';


-- ============================================================================
-- 9. Fournisseurs avec adresse incomplète
-- ============================================================================
-- Type d'anomalie : Données manquantes
-- Description : Fournisseurs actifs sans adresse complète (pays, ville)

-- ============================================================================

SELECT 
    T0."CardCode",
    T0."CardName",
    T0."Address",
    T0."City",
    T0."Country"
FROM OCRD T0
WHERE (T0."Country" IS NULL OR TRIM(T0."Country") = '' 
   OR T0."City" IS NULL OR TRIM(T0."City") = '')
  AND T0."CardType" = 'S'
  AND T0."validFor" = 'Y';


-- ============================================================================
-- 10. Articles avec prix d'achat moyen à zéro
-- ============================================================================
-- Type d'anomalie : Données incohérentes
-- Description : Articles achetés avec un prix moyen égal à zéro
-- ============================================================================

SELECT 
    T0."ItemCode",
    T0."ItemName",
    T0."AvgPrice",
    T0."LastPurPrc" AS "DernierPrixAchat",
    T0."CardCode" AS "FournisseurPrincipal"
FROM OITM T0
WHERE IFNULL(T0."AvgPrice", 0) = 0
  AND T0."PrcrmntMtd" = 'P'
  AND T0."validFor" = 'Y';

