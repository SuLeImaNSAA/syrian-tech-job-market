-- Inspect these counts and rows after the transform. Investigate any exceptions.
SELECT
  (SELECT count(*) FROM raw_jobs) AS raw_rows,
  (SELECT count(*) FROM jobs) AS modeled_jobs,
  (SELECT count(*) FROM companies) AS companies,
  (SELECT count(*) FROM skills) AS skills,
  (SELECT count(*) FROM job_skills) AS job_skill_links;

SELECT raw_job_id, job_title
FROM raw_jobs r
WHERE nullif(btrim(job_title), '') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM jobs j WHERE j.raw_job_id = r.raw_job_id);

SELECT j.id, j.title, j.salary_min, j.salary_max
FROM jobs j WHERE j.salary_min > j.salary_max;

SELECT raw_job_id, salary AS unparsed_salary
FROM raw_jobs
WHERE nullif(btrim(salary), '') IS NOT NULL
  AND regexp_replace(salary, '[[:space:]]', '', 'g') !~ '^[0-9]+(-[0-9]+)?$';

SELECT job_title, company_name, posted_date, count(*) AS possible_duplicates
FROM raw_jobs
GROUP BY job_title, company_name, posted_date
HAVING count(*) > 1
ORDER BY possible_duplicates DESC;

SELECT count(*) FILTER (WHERE company_id IS NULL) AS missing_company,
       count(*) FILTER (WHERE location_id IS NULL) AS missing_location,
       count(*) FILTER (WHERE source_id IS NULL) AS missing_source,
       count(*) FILTER (WHERE experience_years_max IS NULL) AS missing_experience_max
FROM jobs;

SELECT origin_type, count(*) AS postings
FROM jobs
GROUP BY origin_type
ORDER BY postings DESC;
