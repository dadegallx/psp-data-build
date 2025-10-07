**Autore:** Head of Data
**Destinatari:** Business Stakeholders
**Data:** 7 Oct 2025

---

## **1. Obiettivo del Piano**

Definire un modello dati chiaro e scalabile per supportare le analisi del programma **Poverty Stoplight**, consentendo:

- Monitoraggio dello stato attuale delle famiglie;
- Analisi dei progressi nel tempo a livello di indicatori;
- Misura dell’efficacia delle soluzioni/interventi;
- Reporting trasparente, comparabile e conforme alla privacy.

---

## **2. I Tre Modelli Chiave**

### **2.1 Modello Snapshot (FactSnapshot)**

- **Grain**: 1 riga per ogni **snapshot di famiglia**.
- **Contiene**: baseline/follow-up, flag is_last, dati economici sintetici.
- **Domande abilitate**:
    
    - Quante famiglie attive ci sono oggi?
    - Qual è la distribuzione attuale di rossi/gialli/verdi per dimensione?
    - Come cambia lo stato da baseline all’ultimo snapshot?
    - Qual è il tasso di follow-up?
    

---

### **2.2 Modello Indicatori dello Snapshot (FactIndicatorAssessment)**

- **Grain**: 1 riga per **indicatore per snapshot**.
- **Contiene**: template globale, istanza locale, colore (1/2/3), priorità, azioni, achievement.
- **Domande abilitate**:
    
    - Quali indicatori restano più spesso rossi?
    - Quali dimensioni mostrano più progresso?
    - Quanto tempo mediamente serve per passare a verde?
    - Qual è il gap sugli indicatori marcati come priorità?

---

### **2.3 Modello Soluzioni (FactSolutionUsage)**

- **Grain**: 1 riga per **uso di una soluzione per famiglia/indicatore**.
- **Contiene**: tipo di soluzione, indicatori target, timestamp di erogazione.
- **Domande abilitate**:
    
    - Quali soluzioni hanno il maggiore impatto nel migliorare indicatori?
    - Qual è il costo per passaggio a verde (se i costi sono noti)?
    - Quali combinazioni di soluzioni funzionano meglio?
    - Quante famiglie hanno ricevuto soluzioni e con quali risultati?
    

---

## **3. Ordine di Implementazione**

1. **Fase 1 – Snapshot**
    
    - Rilascia KPI immediati: copertura, distribuzioni, baseline vs ultimo.
    
2. **Fase 2 – Indicatori**
    
    - Approfondisce il progresso a livello di dettaglio (indicatori/dimensioni).
    
3. **Fase 3 – Soluzioni**
    
    - Permette analisi di efficacia e ROI delle soluzioni.

---

## **4. Comunicazione dei Modelli**

- **Schema Cards**: 1 pagina per ogni modello (grain, chiavi, campi, esempi query).
    
- **Glossario KPI**: definizioni univoche delle metriche.
    
- **Diagramma alto livello**: Snapshot ↔ Indicatori ↔ Soluzioni ↔ Dimensioni.
    
- **View BI contrattualizzate**: mart_snapshot_current, mart_indicator_assessments, mart_solution_usage.
    
- **Dashboard executive**: 3 cruscotti sintetici (uno per modello).
    

---

## **5. Note di Progettazione**

- **Bridge Template ↔ Instance**: salvare entrambe le chiavi per comparazioni globali/locali.
- **Privacy by Design**: PII separata, flag anonymous applicato nelle viste.
- **SCD2** per template e organizzazioni in caso di cambi definizione.
- **Calcolo robusto is_last** con window function, non solo flag.
- **Stoplight Score** standard: Rosso=0, Giallo=0.5, Verde=1 → media per snapshot.
- **Qualità dati**: regole di validazione (es. unico baseline per famiglia).
    

---

## **6. Glossario KPI v1**

|**KPI**|**Definizione**|**Fonte/Formula**|
|---|---|---|
|**%Rossi / %Gialli / %Verdi**|Percentuale di indicatori in ciascun colore per famiglia/organizzazione|FactIndicatorAssessment, color_value|
|**Stoplight Score**|Media dei valori {Rosso=0, Giallo=0.5, Verde=1} sugli indicatori di uno snapshot|FactIndicatorAssessment|
|**ΔScore Totale**|Differenza di Stoplight Score tra baseline e ultimo snapshot|FactSnapshot + FactIndicatorAssessment|
|**Follow-up Coverage**|% famiglie con almeno 1 snapshot dopo il baseline|FactSnapshot|
|**Priority Gap**|% indicatori marcati come priorità che restano rossi/gialli nell’ultimo snapshot|FactIndicatorAssessment|
|**Time-to-Green**|Giorni medi/mediani tra primo snapshot con colore rosso/giallo e primo snapshot verde|FactIndicatorAssessment + DimTime|
|**Progress Rate**|% indicatori che hanno migliorato colore tra baseline e ultimo snapshot|FactIndicatorAssessment|
|**Solution Effectiveness**|% passaggi a verde entro 90 giorni dopo l’applicazione di una soluzione|FactSolutionUsage + FactIndicatorAssessment|
|**Costo per Green**|Costo totale soluzioni / n° indicatori migliorati a verde (se costo disponibile)|FactSolutionUsage + cost data|
|**Reach Soluzioni**|N° famiglie raggiunte da una soluzione specifica|FactSolutionUsage|

---

## **7. Prossimi Passi Operativi**

1. Validare il **Glossario KPI** con gli stakeholder business.
2. Implementare **FactSnapshot** + viste derivate (mart_snapshot_current, mart_snapshot_baseline).
3. Estendere con **FactIndicatorAssessment** per abilitare analisi per indicatore.
4. Integrare **FactSolutionUsage** per analisi di efficacia.
5. Rilasciare dashboard executive con 3–5 visual per modello.

---

✅ **Output di questo piano:** un approccio scalabile, trasparente e orientato a decisioni misurabili, pronto per essere condiviso con team interni e partner.
