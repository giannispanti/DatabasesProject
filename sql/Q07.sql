-- Q07.sql

SELECT 
    d.ΚΩΔΙΚΟΣ_ΔΟ AS KODIKOS_OUSIAS,
    d.ΟΝΟΜΑ AS ONOMA_OUSIAS,
    COUNT(DISTINCT a.ΑΜΚΑ_ΑΣΘΕΝΗ_FK) AS ARITHMOS_ASTHENON,
    COUNT(DISTINCT df.ΚΩΔΙΚΟΣ_EMA_FK) AS ARITHMOS_FARMAKON
FROM 
    DRASTIKI_OYSIA d
LEFT JOIN 
    ALLERGIES a ON d.ΚΩΔΙΚΟΣ_ΔΟ = a.ΔΡΑΣΤΙΚΗ_ΟΥΣΙΑ_FK
LEFT JOIN 
    DRASTIKES_OYSIES_FARMAKOY df ON d.ΚΩΔΙΚΟΣ_ΔΟ = df.ΔΡΑΣΤΙΚΗ_ΟΥΣΙΑ_FK
GROUP BY 
    d.ΚΩΔΙΚΟΣ_ΔΟ, 
    d.ΟΝΟΜΑ
ORDER BY 
    ARITHMOS_ASTHENON DESC;