-- ═══════════════════════════════════════════════════════════════════════════
-- YC_PARAMETRES — conditions_generales_facture (préfixe [si_impaye])
-- ═══════════════════════════════════════════════════════════════════════════
-- ⚠️ BROUILLON POUR VALIDATION — NE PAS EXÉCUTER SANS RELECTURE.
-- Migration à exécuter manuellement dans l'éditeur SQL Supabase. Je ne
-- l'exécute pas moi-même.
--
-- CONTEXTE : construireHtmlDocument (youmma-center.html) applique désormais
-- une convention sur le texte "Conditions générales" de la facture : toute
-- ligne commençant par le préfixe littéral "[si_impaye] " n'est affichée sur
-- le document imprimé que si le reste à payer (doc.reste) est strictement
-- positif ; le préfixe est retiré à l'affichage. Une facture entièrement
-- réglée (reste = 0) masque donc ces lignes (clause de réserve de propriété,
-- paiement à réception), qui n'ont plus de sens une fois la facture soldée.
--
-- Cette migration met à jour la valeur par défaut stockée en base pour
-- refléter cette convention (les deux premières lignes reçoivent le préfixe,
-- les deux suivantes restent inchangées et s'affichent dans tous les cas).
--
-- Tant que cette migration n'est pas appliquée, le code JS continue de
-- fonctionner sans erreur : l'ancien texte (sans préfixe) s'affichera
-- simplement dans tous les cas, y compris sur une facture soldée, ce qui est
-- l'état actuel avant correction — aucun risque de casse, juste un texte pas
-- encore adapté à l'état de paiement tant que l'UPDATE n'est pas exécuté.
--
-- ⚠️ Si l'administrateur a déjà personnalisé ce texte depuis les Paramètres
-- de l'application (valeur différente du texte par défaut posé lors de
-- l'introduction de cette clé), cet UPDATE écrasera sa personnalisation.
-- Vérifier le contenu actuel avant d'exécuter si un doute existe :
--   SELECT valeur FROM yc_parametres WHERE cle = 'conditions_generales_facture';
-- ═══════════════════════════════════════════════════════════════════════════


BEGIN;

UPDATE yc_parametres
SET valeur = '[si_impaye] Facture payable à réception, sauf accord écrit contraire.
[si_impaye] Les travaux et marchandises restent la propriété de YOUMMA SARLU jusqu''au paiement intégral.
Toute réclamation doit être formulée dans les 48 heures suivant la livraison.
TVA non applicable pour cette activité.'
WHERE cle = 'conditions_generales_facture';

COMMIT;


-- ═══════════════════════════════════════════════════════════════════════════
-- RÉSUMÉ POUR RELECTURE
-- ═══════════════════════════════════════════════════════════════════════════
-- A. Un seul UPDATE, ciblé par WHERE cle = 'conditions_generales_facture'
--    (clé déjà existante en base, introduite lors d'une tâche précédente) :
--    aucune ligne créée, aucune colonne/table modifiée.
-- B. Les deux premières lignes du texte reçoivent le préfixe "[si_impaye] "
--    (avec l'espace), lu et retiré par construireHtmlDocument à l'affichage.
--    Les deux dernières lignes sont inchangées dans leur contenu et restent
--    sans préfixe (affichées dans tous les cas, facture payée ou non).
-- C. Si aucune ligne ne correspond à cle = 'conditions_generales_facture'
--    (clé pas encore créée dans cet environnement), l'UPDATE ne fait rien
--    silencieusement — pas d'erreur, mais pas d'effet non plus. Dans ce cas,
--    utiliser un INSERT (ou l'écran Paramètres de l'application) à la place.
-- D. Écrase toute personnalisation existante de ce texte — voir avertissement
--    ci-dessus avant exécution.
-- ═══════════════════════════════════════════════════════════════════════════
