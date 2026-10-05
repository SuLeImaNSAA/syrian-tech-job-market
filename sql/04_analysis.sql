-- All denominators refer to the loaded sample, not the national job market.
SELECT count(*) AS jobs_analyzed,
       count(DISTINCT company_id) AS companies_analyzed
FROM jobs;

SELECT s.skill_name, count(DISTINCT js.job_id) AS postings_mentioning_skill
FROM skills s JOIN job_skills js ON js.skill_id = s.id
GROUP BY s.id, s.skill_name
ORDER BY postings_mentioning_skill DESC, s.skill_name
LIMIT 10;

SELECT count(*) AS total_postings,
       count(*) FILTER (WHERE salary_min IS NOT NULL) AS disclosed_salary,
       round(100.0 * count(*) FILTER (WHERE salary_min IS NOT NULL)
             / nullif(count(*), 0), 1) AS disclosure_percent
FROM jobs;

SELECT experience_years_min AS stated_min_years,
       count(*) AS junior_postings,
       count(*) FILTER (WHERE experience_years_max IS NULL) AS missing_max_years
FROM jobs
WHERE experience_level = 'Junior'
GROUP BY experience_years_min
ORDER BY experience_years_min;

SELECT j.clean_title,
       count(*) AS total_jobs,
       count(*) FILTER (WHERE EXISTS (
          SELECT 1 FROM job_skills js JOIN skills s ON s.id = js.skill_id
          WHERE js.job_id = j.id
            AND s.skill_name IN ('Docker','CI/CD','AWS','Azure','Kubernetes','Terraform')
       )) AS jobs_mentioning_selected_devops_skills,
       round(100.0 * count(*) FILTER (WHERE EXISTS (
          SELECT 1 FROM job_skills js JOIN skills s ON s.id = js.skill_id
          WHERE js.job_id = j.id
            AND s.skill_name IN ('Docker','CI/CD','AWS','Azure','Kubernetes','Terraform')
       )) / nullif(count(*), 0), 1) AS share_percent
FROM jobs j
WHERE j.clean_title IN ('Backend Developer','Frontend Developer',
                        'Full Stack Developer','Mobile Developer')
GROUP BY j.clean_title
ORDER BY share_percent DESC;
