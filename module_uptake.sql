USE openmrs;
SET @startDate = DATE('2024-06-01');
SET @endDate = @startDate + INTERVAL 1 DAY;
SELECT
    a.siteCode,
    a.FacilityName,
    a.dateofdataextraction,
    COUNT(*) AS total_encounters,
    SUM(CASE WHEN a.TBScreeningEncDelay IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) AS TBScreening,
    SUM(CASE WHEN a.MCHConsultationEncDelay IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) AS MCHConsultation,
    SUM(CASE WHEN a.HIVConsultationEncDelay IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) AS HIVConsultationProp,
    SUM(CASE WHEN a.TPTFupEncDelay IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) AS TPTFupEncProp,
    
	SUM(CASE WHEN a.ARTRefil IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) AS ARTRefilProp,
    SUM(CASE WHEN a.LabOrder IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) AS LabOrderProp,
    SUM(CASE WHEN a.PrePInitial IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) AS PrePInitialProp,
    SUM(CASE WHEN a.OTZActivity IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) AS OTZActivityProp,
    
	SUM(CASE WHEN a.KPClinicVisit IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) AS KPClinicVisitProp,
    SUM(CASE WHEN a.CaCxscreening IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) AS CaCxscreeningProp,
    SUM(CASE WHEN a.GBVScreening IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) AS GBVScreeningProp,
    SUM(CASE WHEN a.OncologyScreening IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) AS OncologyScreeningProp,
    
    SUM(CASE WHEN a.GBVTraumaCounselling IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) AS GBVTraumaCounsellingProp,
    SUM(CASE WHEN a.CageCraftScreening IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) AS CageCraftScreeningProp,
    SUM(CASE WHEN a.EACScreening IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) AS EACScreeningProp,
    SUM(CASE WHEN a.GAD7Screening IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) AS GAD7ScreeningProp,
    
     -- Calculate the average score across encounter types
    (SUM(CASE WHEN a.TBScreeningEncDelay IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) + 
     SUM(CASE WHEN a.MCHConsultationEncDelay IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) + 
     SUM(CASE WHEN a.HIVConsultationEncDelay IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) + 
     SUM(CASE WHEN a.GAD7Screening IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) + 
     SUM(CASE WHEN a.EACScreening IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) + 
     SUM(CASE WHEN a.CageCraftScreening IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) + 
     SUM(CASE WHEN a.GBVTraumaCounselling IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) + 
     SUM(CASE WHEN a.GBVScreening IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) + 
     SUM(CASE WHEN a.CaCxscreening IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) + 
     SUM(CASE WHEN a.KPClinicVisit IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) + 
     SUM(CASE WHEN a.ARTRefil IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) + 
     SUM(CASE WHEN a.LabOrder IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) + 
     SUM(CASE WHEN a.PrePInitial IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) + 
     SUM(CASE WHEN a.OTZActivity IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) +
     SUM(CASE WHEN a.TPTFupEncDelay IN ('NO') THEN 1 ELSE 0 END) / COUNT(*)) / 15 AS average_score,

    -- Evaluate if the average score is greater than 94%
    CASE 
        WHEN (SUM(CASE WHEN a.TBScreeningEncDelay IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) + 
		     SUM(CASE WHEN a.MCHConsultationEncDelay IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) + 
		     SUM(CASE WHEN a.HIVConsultationEncDelay IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) + 
		     SUM(CASE WHEN a.GAD7Screening IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) + 
		     SUM(CASE WHEN a.EACScreening IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) + 
		     SUM(CASE WHEN a.CageCraftScreening IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) + 
		     SUM(CASE WHEN a.GBVTraumaCounselling IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) + 
		     SUM(CASE WHEN a.GBVScreening IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) + 
		     SUM(CASE WHEN a.CaCxscreening IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) + 
		     SUM(CASE WHEN a.KPClinicVisit IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) + 
		     SUM(CASE WHEN a.ARTRefil IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) + 
		     SUM(CASE WHEN a.LabOrder IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) + 
		     SUM(CASE WHEN a.PrePInitial IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) + 
		     SUM(CASE WHEN a.OTZActivity IN ('NO') THEN 1 ELSE 0 END) / COUNT(*) +
		     SUM(CASE WHEN a.TPTFupEncDelay IN ('NO') THEN 1 ELSE 0 END) / COUNT(*)) / 15  > 0.94 THEN 'Yes' 
        ELSE 'No' 
    END AS FacilityPoCStatus
    
FROM(
SELECT 
    edfi.siteCode,
    edfi.FacilityName,
    timestamp() as dateofdataextraction,
    e.patient_id, 
   CASE 
       WHEN TIMESTAMPDIFF(DAY,MAX(CASE WHEN e.encounter_type = 1 THEN e.encounter_datetime END),MAX(CASE WHEN e.encounter_type = 1 THEN e.date_created END))>0 THEN 'Yes' 
       ELSE 'No' END AS TBScreeningEncDelay,
   CASE 
       WHEN TIMESTAMPDIFF(DAY,MAX(CASE WHEN e.encounter_type =15 THEN e.encounter_datetime END),MAX(CASE WHEN e.encounter_type =15 THEN e.date_created END))>0 THEN 'Yes' 
       ELSE 'No' END AS MCHConsultationEncDelay,
   CASE 
       WHEN TIMESTAMPDIFF(DAY,MAX(CASE WHEN e.encounter_type = 8 THEN e.encounter_datetime END),MAX(CASE WHEN e.encounter_type = 8 THEN e.date_created END))>0 THEN 'Yes' 
       ELSE 'No' END AS HIVConsultationEncDelay,
   CASE 
       WHEN TIMESTAMPDIFF(DAY,MAX(CASE WHEN e.encounter_type = 26 THEN e.encounter_datetime END),MAX(CASE WHEN e.encounter_type = 26 THEN e.date_created END))>0 THEN 'Yes' 
       ELSE 'No' END AS TPTFupEncDelay,
    CASE 
       WHEN TIMESTAMPDIFF(DAY,MAX(CASE WHEN e.encounter_type = 21 THEN e.encounter_datetime END),MAX(CASE WHEN e.encounter_type = 21 THEN e.date_created END))>0 THEN 'Yes' 
       ELSE 'No' END AS ARTRefil,
   CASE 
       WHEN TIMESTAMPDIFF(DAY,MAX(CASE WHEN e.encounter_type = 30 THEN e.encounter_datetime END),MAX(CASE WHEN e.encounter_type = 30 THEN e.date_created END))>0 THEN 'Yes' 
       ELSE 'No' END AS LabOrder,
   CASE 
       WHEN TIMESTAMPDIFF(DAY,MAX(CASE WHEN e.encounter_type = 46 THEN e.encounter_datetime END),MAX(CASE WHEN e.encounter_type = 46 THEN e.date_created END))>0 THEN 'Yes' 
       ELSE 'No' END AS PrePInitial,
    CASE 
       WHEN TIMESTAMPDIFF(DAY,MAX(CASE WHEN e.encounter_type = 51 THEN e.encounter_datetime END),MAX(CASE WHEN e.encounter_type = 51 THEN e.date_created END))>0 THEN 'Yes' 
       ELSE 'No' END AS OTZActivity,
   CASE 
       WHEN TIMESTAMPDIFF(DAY,MAX(CASE WHEN e.encounter_type = 66 THEN e.encounter_datetime END),MAX(CASE WHEN e.encounter_type = 66 THEN e.date_created END))>0 THEN 'Yes' 
       ELSE 'No' END AS KPClinicVisit,
   CASE 
       WHEN TIMESTAMPDIFF(DAY,MAX(CASE WHEN e.encounter_type = 73 THEN e.encounter_datetime END),MAX(CASE WHEN e.encounter_type = 73 THEN e.date_created END))>0 THEN 'Yes' 
       ELSE 'No' END AS CaCxscreening,
    CASE 
       WHEN TIMESTAMPDIFF(DAY,MAX(CASE WHEN e.encounter_type = 89 THEN e.encounter_datetime END),MAX(CASE WHEN e.encounter_type = 89 THEN e.date_created END))>0 THEN 'Yes' 
       ELSE 'No' END AS GBVScreening,
    CASE 
       WHEN TIMESTAMPDIFF(DAY,MAX(CASE WHEN e.encounter_type = 91 THEN e.encounter_datetime END),MAX(CASE WHEN e.encounter_type = 91 THEN e.date_created END))>0 THEN 'Yes' 
       ELSE 'No' END AS OncologyScreening,
	CASE 
       WHEN TIMESTAMPDIFF(DAY,MAX(CASE WHEN e.encounter_type = 105 THEN e.encounter_datetime END),MAX(CASE WHEN e.encounter_type =105 THEN e.date_created END))>0 THEN 'Yes' 
       ELSE 'No' END AS GBVTraumaCounselling,
	CASE 
       WHEN TIMESTAMPDIFF(DAY,MAX(CASE WHEN e.encounter_type =87 THEN e.encounter_datetime END),MAX(CASE WHEN e.encounter_type =87 THEN e.date_created END))>0 THEN 'Yes' 
       ELSE 'No' END AS CageCraftScreening,
	CASE 
       WHEN TIMESTAMPDIFF(DAY,MAX(CASE WHEN e.encounter_type =88 THEN e.encounter_datetime END),MAX(CASE WHEN e.encounter_type =88 THEN e.date_created END))>0 THEN 'Yes' 
       ELSE 'No' END AS EACScreening,
    CASE 
       WHEN TIMESTAMPDIFF(DAY,MAX(CASE WHEN e.encounter_type =90 THEN e.encounter_datetime END),MAX(CASE WHEN e.encounter_type =90 THEN e.date_created END))>0 THEN 'Yes' 
       ELSE 'No' END AS GAD7Screening
FROM 
    encounter e 
CROSS JOIN kenyaemr_etl.etl_default_facility_info edfi
WHERE e.voided=0
GROUP BY e.patient_id
ORDER BY e.patient_id)a
GROUP BY a.siteCode;