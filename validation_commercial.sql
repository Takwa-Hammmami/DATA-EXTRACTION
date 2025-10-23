
-- ============================================================================
-- 1. Clients sans adresse valide
-- ============================================================================
-- Type d'anomalie : Données manquantes
-- Description : Clients actifs sans adresse renseignée
-- ============================================================================

SELECT 
    T0."CardCode",
    T0."CardName",
    T0."Address",
    T0."Phone1",
    T0."E_Mail"
FROM OCRD T0
WHERE (T0."Address" IS NULL OR TRIM(T0."Address") = '')
  AND T0."CardType" = 'C'
  AND T0."validFor" = 'Y'
ORDER BY T0."CardCode";


-- ============================================================================
-- 2. Clients sans données fiscales (Matricule Fiscale)
-- ============================================================================
-- Type d'anomalie : Données manquantes
-- Description : Clients actifs sans numéro d'identification fiscale
-- Impact : Non-conformité réglementaire, problèmes de déclaration TVA
-- ============================================================================

SELECT 
    T0."CardCode",
    T0."CardName",
    T0."LicTradNum",
    T0."Address",
    T0."Country"
FROM OCRD T0
WHERE (T0."LicTradNum" IS NULL OR TRIM(T0."LicTradNum") = '')
  AND T0."CardType" = 'C'
  AND T0."validFor" = 'Y'
ORDER BY T0."CardCode";


-- ============================================================================
-- 3. Listes de prix avec période invalide ou non définie
-- ============================================================================
-- Type d'anomalie : Données incohérentes
-- Description : Listes de prix sans dates de validité ou expirées
-- Impact : Application de prix erronés ou impossibilité de vendre
-- ============================================================================

SELECT 
    T0."ListNum",
    T0."ListName",
    T0."ValidFrom",
    T0."ValidTo",
    CASE 
        WHEN T0."ValidFrom" IS NULL THEN 'Date début manquante'
        WHEN T0."ValidTo" IS NULL THEN 'Date fin manquante'
        WHEN T0."ValidTo" < CURRENT_DATE THEN 'Liste expirée'
        ELSE 'Autre problème'
    END AS "TypeProbleme",
    DAYS_BETWEEN(T0."ValidTo", CURRENT_DATE) AS "JoursDepuisExpiration"
FROM OPLN T0
WHERE T0."ValidFrom" IS NULL
   OR T0."ValidTo" IS NULL
   OR T0."ValidTo" < CURRENT_DATE
ORDER BY T0."ValidTo" DESC;


-- ============================================================================
-- 4. Articles vendus sans liste de prix associée
-- ============================================================================
-- Type d'anomalie : Données manquantes
-- Description : Articles configurés pour la vente mais sans prix défini
-- Impact : Impossibilité de créer des commandes ou factures
-- ============================================================================

SELECT 
    T0."ItemCode",
    T0."ItemName",
    T0."ItmsGrpCod",
    T0."OnHand"
FROM OITM T0
WHERE T0."SellItem" = 'Y'
  AND T0."validFor" = 'Y'
  AND NOT EXISTS (
      SELECT 1 
      FROM ITM1 T1 
      WHERE T1."ItemCode" = T0."ItemCode"
  )
ORDER BY T0."ItemCode";


-- ============================================================================
-- 5. Clients sans conditions de paiement
-- ============================================================================
-- Type d'anomalie : Données manquantes
-- Description : Clients actifs sans conditions de paiement définies
-- Impact : Impossibilité de générer des factures avec échéances correctes
-- ============================================================================

SELECT 
    T0."CardCode",
    T0."CardName",
    T0."GroupCode",
    T0."GroupNum" AS "ConditionsPaiement",
    T0."Balance"
FROM OCRD T0
WHERE (T0."GroupNum" IS NULL 
       OR T0."GroupNum" = -1
       OR T0."GroupNum" = 0)
  AND T0."CardType" = 'C'
  AND T0."validFor" = 'Y'
ORDER BY T0."CardCode";


-- ============================================================================
-- 6. Conditions de livraison non définies (Mode Transport/Shipping)
-- ============================================================================
-- Type d'anomalie : Données manquantes
-- Description : Clients sans mode de transport ou conditions de livraison
-- Impact : Problèmes logistiques, calcul des frais de port
-- ============================================================================

SELECT 
    T0."CardCode",
    T0."CardName",
    T0."ShipType",
    T0."Address",
    T0."City"
FROM OCRD T0
WHERE (T0."ShipType" IS NULL 
       OR T0."ShipType" = -1
       OR T0."ShipType" = 0)
  AND T0."CardType" = 'C'
  AND T0."validFor" = 'Y'
ORDER BY T0."CardCode";


-- ============================================================================
-- 7. Articles vendus mais inactifs
-- ============================================================================
-- Type d'anomalie : Données incohérentes
-- Description : Articles marqués comme inactifs mais configurés pour la vente
-- Impact : Confusion, risque de vendre des produits obsolètes
-- ============================================================================

SELECT DISTINCT
    T0."ItemCode",
    T0."ItemName",
    T0."validFor",
    T0."SellItem",
    T0."OnHand"
FROM OITM T0
WHERE T0."validFor" = 'N'
  AND T0."SellItem" = 'Y'
ORDER BY T0."ItemCode";


-- ============================================================================
-- 8. Unité de vente ≠ Unité de stock (UoM incohérente)
-- ============================================================================
-- Type d'anomalie : Données incohérentes
-- Description : Unité de mesure de vente différente de l'unité de stock
-- Impact : Risque d'erreurs de conversion, problèmes de quantités
-- ============================================================================

SELECT 
    T0."ItemCode",
    T0."ItemName",
    T0."InvntryUom" AS "UniteStock",
    T0."SalUnitMsr" AS "UniteVente",
    T0."BuyUnitMsr" AS "UniteAchat"
FROM OITM T0
WHERE T0."SellItem" = 'Y'
  AND T0."validFor" = 'Y'
  AND T0."InvntryUom" <> IFNULL(T0."SalUnitMsr", T0."InvntryUom")
ORDER BY T0."ItemCode";


-- ============================================================================
-- REQUÊTES : Analyses complémentaires
-- ============================================================================

-- ============================================================================
-- 1 : Clients avec crédit dépassé
-- ============================================================================
-- Description : Clients dont le crédit utilisé dépasse la limite autorisée
-- 
-- ============================================================================

SELECT 
    T0."CardCode",
    T0."CardName",
    T0."CreditLine" AS "LimiteCredit",
    T0."Balance" AS "SoldeActuel",
    (T0."Balance" - T0."CreditLine") AS "Depassement",
    ROUND((T0."Balance" * 100.0 / NULLIF(T0."CreditLine", 0)), 2) AS "PourcentageUtilisation",
    T0."Cellular" AS "TelMobile"
FROM OCRD T0
WHERE T0."CardType" = 'C'
  AND T0."validFor" = 'Y'
  AND T0."CreditLine" > 0
  AND T0."Balance" > T0."CreditLine"
ORDER BY "Depassement" DESC;


-- ============================================================================
--  2 : Articles sans prix dans la liste principale
-- ============================================================================
-- Description : Articles avec un prix nul ou non défini dans la liste par défaut
--
-- ============================================================================

SELECT 
    T0."ItemCode",
    T0."ItemName",
    T1."PriceList" AS "ListNum",
    T1."Price",
    T1."Currency"
FROM OITM T0
INNER JOIN ITM1 T1 ON T0."ItemCode" = T1."ItemCode"
WHERE T0."SellItem" = 'Y'
  AND T0."validFor" = 'Y'
  AND T1."PriceList" = 1  -- Liste de prix par défaut
  AND (T1."Price" IS NULL OR T1."Price" = 0)
ORDER BY T0."ItemCode";


-- ============================================================================
--  3 : Clients sans groupe de clients
-- ============================================================================
-- Description : Clients non affectés à un groupe (segmentation)
-- 
-- ============================================================================

SELECT 
    T0."CardCode",
    T0."CardName",
    T0."GroupCode",
    T0."Balance",
    T0."CreateDate"
FROM OCRD T0
WHERE T0."CardType" = 'C'
  AND T0."validFor" = 'Y'
  AND (T0."GroupCode" IS NULL 
       OR T0."GroupCode" = -1
       OR T0."GroupCode" = 0)
ORDER BY T0."CreateDate" DESC;


-- ============================================================================
-- 4 : Articles sans groupe d'articles
-- ============================================================================
-- Description : Articles non catégorisés
-- Impact : Impossibilité de classer et analyser les ventes par catégorie
-- ============================================================================

SELECT 
    T0."ItemCode",
    T0."ItemName",
    T0."ItmsGrpCod",
    T0."OnHand",
    T0."SellItem"
FROM OITM T0
WHERE T0."validFor" = 'Y'
  AND (T0."ItmsGrpCod" IS NULL 
       OR T0."ItmsGrpCod" = -1
       OR T0."ItmsGrpCod" = 0)
ORDER BY T0."ItemCode";


-- ============================================================================
--  5 : Clients avec plusieurs contacts mais sans contact par défaut
-- ============================================================================
-- Description : Clients avec contacts multiples mais aucun contact principal défini

-- ============================================================================

SELECT 
    T0."CardCode",
    T0."CardName",
    COUNT(T1."CntctCode") AS "NombreContacts",
    T0."E_Mail",
    T0."Phone1"
FROM OCRD T0
LEFT JOIN OCPR T1 ON T0."CardCode" = T1."CardCode"
WHERE T0."CardType" = 'C'
  AND T0."validFor" = 'Y'
GROUP BY T0."CardCode", T0."CardName", T0."E_Mail", T0."Phone1"
HAVING COUNT(T1."CntctCode") > 1
ORDER BY "NombreContacts" DESC;


-- ============================================================================
--  6 : Prix de vente inférieurs au coût d'achat
-- ============================================================================
-- Description : Articles vendus à perte

-- ============================================================================

SELECT 
    T0."ItemCode",
    T0."ItemName",
    T0."LastPurPrc" AS "DernierPrixAchat",
    T1."Price" AS "PrixVente",
    T1."PriceList" AS "NumListe",
    (T1."Price" - T0."LastPurPrc") AS "Marge",
    CASE 
        WHEN T0."LastPurPrc" > 0 
        THEN ROUND(((T1."Price" - T0."LastPurPrc") * 100.0 / T0."LastPurPrc"), 2)
        ELSE 0 
    END AS "PourcentageMarge"
FROM OITM T0
INNER JOIN ITM1 T1 ON T0."ItemCode" = T1."ItemCode"
WHERE T0."SellItem" = 'Y'
  AND T0."validFor" = 'Y'
  AND T1."PriceList" = 1
  AND T0."LastPurPrc" > 0
  AND T1."Price" < T0."LastPurPrc"
ORDER BY "Marge" ASC;




-- ============================================================================
