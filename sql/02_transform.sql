-- Run after loading raw_jobs. A repeat run replaces only modeled tables.
-- No company or location is inferred from unrelated postings.
BEGIN;
TRUNCATE TABLE job_skills, jobs, skills, companies, locations, job_sources
    RESTART IDENTITY CASCADE;

INSERT INTO companies (name)
SELECT DISTINCT name
FROM (
    SELECT
        CASE
            WHEN lower(btrim(company_name)) IN ('metamas') THEN 'MetaMAS'
            WHEN lower(btrim(company_name)) IN ('metagate') THEN 'MetaGate'
            WHEN lower(btrim(company_name)) IN ('l-one', 'l-one llc', 'l-one l.l.c') THEN 'L-One L.L.C'
            WHEN lower(btrim(company_name)) IN ('unknown', 'private company', 'software company') THEN 'Unknown'
            ELSE btrim(company_name)
        END AS name
    FROM raw_jobs
    WHERE nullif(btrim(company_name), '') IS NOT NULL
) x;

INSERT INTO locations (city, country)
SELECT DISTINCT nullif(btrim(city), ''), btrim(country)
FROM raw_jobs
WHERE nullif(btrim(country), '') IS NOT NULL;

INSERT INTO job_sources (source_name)
SELECT DISTINCT btrim(source)
FROM raw_jobs
WHERE nullif(btrim(source), '') IS NOT NULL;

WITH prepared AS (
    SELECT r.*,
      CASE
        WHEN lower(btrim(r.company_name)) = 'metamas' THEN 'MetaMAS'
        WHEN lower(btrim(r.company_name)) = 'metagate' THEN 'MetaGate'
        WHEN lower(btrim(r.company_name)) IN ('l-one', 'l-one llc', 'l-one l.l.c') THEN 'L-One L.L.C'
        WHEN lower(btrim(r.company_name)) IN ('unknown', 'private company', 'software company') THEN 'Unknown'
        ELSE btrim(r.company_name)
      END AS canonical_company,
      regexp_replace(coalesce(r.salary, ''), '[[:space:]]', '', 'g') AS salary_compact
    FROM raw_jobs r
)
INSERT INTO jobs (
    raw_job_id, title, clean_title, company_id, location_id, source_id, origin_type,
    experience_level, experience_years_min, experience_years_max,
    experience_range, job_type, posted_date, description, salary_min, salary_max
)
SELECT
    p.raw_job_id,
    btrim(p.job_title),
    CASE
      WHEN p.job_title ~* 'full[ -]?stack' THEN 'Full Stack Developer'
      WHEN p.job_title ~* '(artificial intelligence|machine learning|(^|[^[:alnum:]])(ai|ml|llm)([^[:alnum:]]|$))' THEN 'AI Engineer'
      WHEN p.job_title ~* '(back[ -]?end|\.net|laravel|node[.]js|php)' THEN 'Backend Developer'
      WHEN p.job_title ~* '(front[ -]?end|react|vue|angular|next[.]js)' THEN 'Frontend Developer'
      WHEN p.job_title ~* '(mobile|flutter|android|ios|react native)' THEN 'Mobile Developer'
      WHEN p.job_title ~* '(data analyst|data analysis)' THEN 'Data Analyst'
      WHEN p.job_title ~* 'devops' THEN 'DevOps Engineer'
      WHEN p.job_title ~* '(cyber|security)' THEN 'Cybersecurity'
      ELSE btrim(p.job_title)
    END,
    c.id, l.id, s.id, nullif(btrim(p.origin_type), ''),
    nullif(btrim(p.experience_level), ''),
    p.experience_years_min, p.experience_years_max,
    CASE
      WHEN p.experience_years_max IS NULL THEN NULL
      WHEN p.experience_years_max <= 1 THEN '0-1 Years'
      WHEN p.experience_years_max <= 3 THEN '1-3 Years'
      WHEN p.experience_years_max <= 5 THEN '3-5 Years'
      WHEN p.experience_years_max <= 8 THEN '5-8 Years'
      ELSE '8+ Years'
    END,
    nullif(btrim(p.job_type), ''), p.posted_date, p.description,
    CASE WHEN p.salary_compact ~ '^[0-9]+(-[0-9]+)?$'
      THEN split_part(p.salary_compact, '-', 1)::integer END,
    CASE WHEN p.salary_compact ~ '^[0-9]+(-[0-9]+)?$'
      THEN CASE WHEN strpos(p.salary_compact, '-') > 0
        THEN split_part(p.salary_compact, '-', 2)::integer
        ELSE p.salary_compact::integer END END
FROM prepared p
LEFT JOIN companies c ON c.name = p.canonical_company
LEFT JOIN locations l ON l.city IS NOT DISTINCT FROM nullif(btrim(p.city), '')
                     AND l.country = btrim(p.country)
LEFT JOIN job_sources s ON s.source_name = btrim(p.source)
WHERE nullif(btrim(p.job_title), '') IS NOT NULL;

-- Normalize a limited set of spelling variants documented in the original work.
WITH parsed AS (
  SELECT j.id AS job_id,
    CASE lower(btrim(item.skill))
      WHEN 'react.js' THEN 'React'
      WHEN 'react' THEN 'React'
      WHEN 'express' THEN 'Express.js'
      WHEN 'express.js' THEN 'Express.js'
      WHEN 'bloc' THEN 'BLoC'
      WHEN 'scrum' THEN 'Scrum'
      WHEN 'llms' THEN 'LLM'
      WHEN 'android development' THEN 'Android'
      WHEN 'ios development' THEN 'iOS'
      WHEN 'wireframes' THEN 'Wireframing'
      WHEN 'eloquent' THEN 'Eloquent ORM'
      ELSE btrim(item.skill)
    END AS skill_name
  FROM jobs j
  JOIN raw_jobs r ON r.raw_job_id = j.raw_job_id
  CROSS JOIN LATERAL unnest(string_to_array(r.skills, ',')) AS item(skill)
  WHERE nullif(btrim(item.skill), '') IS NOT NULL
), unique_skills AS (
  INSERT INTO skills(skill_name)
  SELECT DISTINCT skill_name FROM parsed
  RETURNING id, skill_name
)
INSERT INTO job_skills(job_id, skill_id)
SELECT DISTINCT p.job_id, s.id
FROM parsed p JOIN unique_skills s USING (skill_name)
ON CONFLICT DO NOTHING;

COMMIT;
