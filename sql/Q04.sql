-- Q04.sql

ANALYZE
SELECT 
    p.ΕΠΩΝΥΜΟ AS 'Επώνυμο Ιατρού',
    p.ΟΝΟΜΑ AS 'Όνομα Ιατρού',
    ROUND(AVG(ai.ΦΡΟΝΤΙΔΑ), 2) AS 'Μ.Ο. Ποιότητας Φροντίδας',
    ROUND(AVG(an.ΣΥΝΟΛΙΚΗ_ΕΜΠΕΙΡΙΑ), 2) AS 'Μ.Ο. Συνολικής Εμπειρίας'
FROM 
    AKSIOLOGHSH_IATROY ai IGNORE INDEX (idx_eval_doc_amka)
JOIN 
    PROSOPIKO p ON ai.ΑΜΚΑ_ΙΑΤΡΟΥ_FK = p.ΑΜΚΑ
JOIN 
    AKSIOLOGHSH_NOSILEIAS an ON ai.ΝΟΣΗΛΕΙΑ_FK = an.ΝΟΣΗΛΕΙΑ_FK
WHERE 
    ai.ΑΜΚΑ_ΙΑΤΡΟΥ_FK = '32003791769' 
GROUP BY 
    ai.ΑΜΚΑ_ΙΑΤΡΟΥ_FK, p.ΕΠΩΝΥΜΟ, p.ΟΝΟΜΑ;

ANALYZE
SELECT 
    p.ΕΠΩΝΥΜΟ AS 'Επώνυμο Ιατρού',
    p.ΟΝΟΜΑ AS 'Όνομα Ιατρού',
    ROUND(AVG(ai.ΦΡΟΝΤΙΔΑ), 2) AS 'Μ.Ο. Ποιότητας Φροντίδας',
    ROUND(AVG(an.ΣΥΝΟΛΙΚΗ_ΕΜΠΕΙΡΙΑ), 2) AS 'Μ.Ο. Συνολικής Εμπειρίας'
FROM 
    AKSIOLOGHSH_IATROY ai FORCE INDEX (idx_eval_doc_amka)
JOIN 
    PROSOPIKO p ON ai.ΑΜΚΑ_ΙΑΤΡΟΥ_FK = p.ΑΜΚΑ
JOIN 
    AKSIOLOGHSH_NOSILEIAS an ON ai.ΝΟΣΗΛΕΙΑ_FK = an.ΝΟΣΗΛΕΙΑ_FK
WHERE 
    ai.ΑΜΚΑ_ΙΑΤΡΟΥ_FK = '32003791769' 
GROUP BY 
    ai.ΑΜΚΑ_ΙΑΤΡΟΥ_FK, p.ΕΠΩΝΥΜΟ, p.ΟΝΟΜΑ;